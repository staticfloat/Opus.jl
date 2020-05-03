"""
Opaque Encoder struct
"""
mutable struct OpusEncoder  # mutable so that finalizer can be applied
    v::Ptr{Cvoid}
    fs::Int32
    channels::Cint

    """
    Create new OpusEncoder object with given samplerate and channels
    """
    function OpusEncoder(samplerate, channels; application = OPUS_APPLICATION_AUDIO, packetloss_pct = 0)
        errorptr = Ref{Cint}(0);
        # Create new encoder object with the given samplerate and channel
        encptr = ccall((:opus_encoder_create,libopus), Ptr{Cvoid}, (Int32, Cint, Cint, Ref{Cint}), samplerate, channels, application, errorptr)
        err = errorptr[]
        enc = new(encptr, samplerate, channels)
        if err != OPUS_OK
            error("opus_encoder_create() failed: $(OPUS_ERROR_MESSAGE_STRS[err])")
        end

		if packetloss_pct > 0
			opus_encoder_ctl(enc, OPUS_SET_PACKET_LOSS_PERC, Cint(packetloss_pct))
			opus_encoder_ctl(enc, OPUS_SET_INBAND_FEC, Cint(1))
		end

        # Register finalizer to cleanup this encoder
        finalizer(enc) do x
            ccall((:opus_encoder_destroy,libopus),Cvoid,(Ptr{Cvoid},),x.v)
        end
        return enc
    end
end

function opus_encoder_ctl(enc::OpusEncoder, request::Cint, arg::Cint)
    ret = ccall((:opus_encoder_ctl,libopus), Cint, (Ptr{Cvoid}, Cint, Cint...),
                                                    enc.v, request, arg)
    if ret != OPUS_OK
        error("opus_encoder_ctl() failed: $(OPUS_ERROR_MESSAGE_STRS[ret])")
    end
end


# Compat shim
function encode_frame(args...; kwargs...)
    @warn("encode_frame() is deprecated, use encode_packet() instead!")
    encode_packet(args...; kwargs...)
end

function encode_packet(enc::OpusEncoder, data::Vector{Float32})
    frame_len = div(length(data),enc.channels)
    if !(frame_len in [120, 240, 480, 960, 1920, 2880])
        error("Invalid packet length of $(length(data)/enc.channels) samples")
    end
    packet = Vector{UInt8}(undef, length(data)*4*enc.channels)

    num_bytes = ccall((:opus_encode_float,libopus), Cint, (Ptr{Cvoid}, Ptr{Float32}, Cint, Ptr{UInt8}, Int32),
                        enc.v, data, frame_len, packet, length(packet))
    if num_bytes < 0
        error("opus_encode_float() failed: $(OPUS_ERROR_MESSAGE_STRS[num_bytes])")
    end
    return copy(packet[1:num_bytes])
end

"""
    encode(enc::OpusEncoder, audio::Array{Float32}; chunksize=960)

Given an array of Float32 PCM samples, consumes the audio in chunks of
size `chunksize`, generating a list of Opus packets returned as a
`Vector{Vector{UInt8}}`.
"""
function encode(enc::OpusEncoder, audio::Array{Float32}; chunksize=960)
    if size(audio, 2) != enc.channels
        error("Audio data must have the same number of channels as encoder!")
    end

    # Do we have multiple channels?  If so, flatten audio
    if size(audio, 2) > 1
        audio = reshape(audio', (prod(size(audio)),))
    end

    packets = Vector{Vector{UInt8}}()
    # Split audio up into chunks of size chunksize
    for chunk_idx in 1:div(length(audio),enc.channels*chunksize)
        chunk = audio[(chunk_idx-1)*chunksize*enc.channels + 1:chunk_idx*chunksize*enc.channels]
        encoded_chunk = encode_packet(enc, chunk)
        push!(packets, encoded_chunk)
    end

    # Encode last chunk, zero-padding if we need to
    leftover_samples = div(length(audio),enc.channels) % chunksize
    if leftover_samples != 0
        chunk = audio[length(audio) - leftover_samples*enc.channels + 1:length(audio)]
        chunk = vcat(chunk, zeros(Float32, chunksize - leftover_samples))
        encoded_chunk = encode_packet(enc, chunk)
        push!(packets, encoded_chunk)
    end
    return packets
end

function save(output::Union{File{format"OPUS"},AbstractString,IO}, audio::Array{Float32}, fs; chunksize=960)
    # Encode the audio into packets
    enc = OpusEncoder(fs, size(audio, 2))
    packets = encode(enc, audio; chunksize=chunksize)

    # Calculate granule positions for each packet.  We mark the first two packets as
    # "header packets" by setting their granulepos to zero, which forces them into
    # their own ogg pages
    granulepos = vcat(0, 0, collect(1:length(packets))*div(chunksize,enc.channels))

    # Save it out into an Ogg file with an OpusHead and OpusTags
    opus_head = OpusHead(fs, size(audio, 2))
    insert!(packets, 1, opus_head)
    opus_tags = OpusTags()
    insert!(packets, 2, opus_tags)
    Ogg.save(output, Dict(Clong(1) => packets), Dict(Clong(1) => Int64.(granulepos)))
end

function save(output::Union{File{format"OPUS"},AbstractString,IO}, audio::Array, fs; chunksize=960)
    return save(output, map(Float32, audio), fs, chunksize=chunksize)
end