"""
Opaque Decoder struct
"""
mutable struct OpusDecoder  # mutable so that finalizer can be applied
    v::Ptr{Cvoid}
    fs::Int32
    channels::Cint

    """
    Create new OpusDecoder object with given samplerate and channels
    """
    function OpusDecoder(samplerate, channels)
        errorptr = Ref{Cint}(0);
        # Create new decoder object with the given samplerate and channel
        decptr = ccall((:opus_decoder_create,libopus), Ptr{Cvoid}, (Int32, Cint, Ref{Cint}), samplerate, channels, errorptr)
        err = errorptr[]
        dec = new(decptr, samplerate, channels)
        if err != OPUS_OK
            error("opus_decoder_create() failed: $(OPUS_ERROR_MESSAGE_STRS[err])")
        end

        # Register finalizer to cleanup this decoder
        finalizer(dec) do x
            ccall((:opus_decoder_destroy,libopus),Cvoid,(Ptr{Cvoid},),x.v)
        end
        return dec
    end
end

function get_nb_samples(data, fs)
    num_samples = ccall((:opus_packet_get_nb_samples, libopus), Cint, (Ptr{UInt8}, Int32, Int32), data, length(data), fs)
    if num_samples < 0
        error("opus_packet_get_nb_samples() failed: $(OPUS_ERROR_MESSAGE_STRS[num_samples])")
    end
    return num_samples
end

function decode_packet(dec::OpusDecoder, packet::Vector{UInt8}; fec::Bool=false)
    packet_samples = get_nb_samples(packet, dec.fs)
    output = Vector{Float32}(undef, packet_samples*dec.channels)

    num_samples = ccall((:opus_decode_float,libopus), Cint, (Ptr{Cvoid}, Ptr{UInt8}, Int32, Ptr{Float32}, Cint, Cint),
                        dec.v, packet, length(packet), output, packet_samples*dec.channels, Cint(fec))
    if num_samples < 0
        error("opus_decode_float() failed: $(OPUS_ERROR_MESSAGE_STRS[num_samples])")
    end
    return output
end

"""
Packets go in, floating-point audio stream comes out
"""
function decode_all_packets(dec::OpusDecoder, packets::Vector{Vector{UInt8}})
    # Skip past header packets
    start_idx = 1
    while is_header_packet(packets[start_idx])
        start_idx += 1
    end

    # Figure out the length of each packet
    packet_lens = map(packet -> get_nb_samples(packet, dec.fs)*dec.channels, packets[start_idx:end])
    packet_lens = vcat(zeros(Int32, start_idx - 1), packet_lens)

    # Allocate output now that we know the length of all our audio
    output = Vector{Float32}(undef, sum(packet_lens))

    # Decode each packet into its corresponding chunk of output
    out_idx = 1
    for idx in start_idx:length(packets)
        output[out_idx:out_idx + packet_lens[idx] - 1] = decode_packet(dec, packets[idx])
        out_idx += packet_lens[idx]
    end

    # Return our hard-earned goodness, reshaping if we're stereo!
    if dec.channels > 1
        return reshape(output, (Int64(dec.channels), div(length(output), dec.channels)))'
    end
    return output''
end

"""
Returns (audio, fs) unless the ogg file has no opus streams
"""
function load(fio::IO)
    audio = nothing
    packets = Ogg.load(fio)
    for serial in keys(packets)
        opus_head = OpusHead()
        opus_tags = OpusTags()
        try
            # Find the first stream that is Opus and decode it
            opus_head = OpusHead(packets[serial][1])
            opus_tags = OpusTags(packets[serial][2])
        # TODO: throw a more specific exception. Catching all exceptions here
        # makes things hard to debug if there's a problem (or Julia syntax changes) 
        catch
            continue
        end
        dec = Opus.OpusDecoder(48000, opus_head.channels)
        audio = decode_all_packets(dec, packets[serial])
        break
    end

    if audio == nothing
        error("Could not find any Opus streams!")
    end
    return audio, 48000
end

function load(file_path::Union{File{format"OPUS"},AbstractString})
    open(file_path) do fio
        return load(fio)
    end
end
