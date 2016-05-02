"""
Opaque Encoder struct
"""
type OpusEncoder  # type not immutable so that finalizer can be applied
    v::Ptr{Void}
    fs::Int32
    channels::Cint

    """
    Create new OpusEncoder object with given samplerate and channels
    """
    function OpusEncoder(samplerate, channels; application = OPUS_APPLICATION_AUDIO)
        errorptr = Ref{Cint}(0);
        # Create new encoder object with the given samplerate and channel
        encptr = ccall((:opus_encoder_create,libopus), Ptr{Void}, (Int32, Cint, Cint, Ref{Cint}), samplerate, channels, application, errorptr)
        err = errorptr[]
        enc = new(encptr, samplerate, channels)
        if err != OPUS_OK
            error("opus_encoder_create() failed: $(OPUS_ERROR_MESSAGE_STRS[err])")
        end

        # Register finalizer to cleanup this encoder
        finalizer(enc,x -> ccall((:opus_encoder_destroy,libopus),Void,(Ptr{Void},),x.v))
        return enc
    end
end

function encode_frame(enc::OpusEncoder, data::Vector{Float32})
    frame_len = div(length(data),enc.channels)
    if !(frame_len in [120, 240, 480, 960, 1920, 2880])
        error("Invalid frame length of $(length(data)/enc.channels) samples")
    end
    packet = Vector{UInt8}(length(data)*4)

    #print("opus_encode_float: ")
    num_bytes = ccall((:opus_encode_float,libopus), Cint, (Ptr{Void}, Ptr{Float32}, Cint, Ptr{UInt8}, Int32),
                        enc.v, data, frame_len, packet, length(packet))
    if num_bytes < 0
        error("opus_encode_float() failed: $(OPUS_ERROR_MESSAGE_STRS[num_bytes])")
    end
    return copy(packet[1:num_bytes])
end

"""
Array goes in, packets of bytes come out
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
        encoded_chunk = encode_frame(enc, chunk)
        #println("Mapping chunk $(chunk_idx) (std dev: $(std(chunk))) to $(length(encoded_chunk)) bytes")
        push!(packets, encoded_chunk)
    end

    # Encode last chunk, zero-padding if we need to
    leftover_samples = div(length(audio),enc.channels) % chunksize
    if leftover_samples != 0
        chunk = audio[length(audio) - leftover_samples*enc.channels + 1:length(audio)]
        chunk = vcat(chunk, zeros(Float32, chunksize - leftover_samples))
        encoded_chunk = encode_frame(enc, chunk)
        push!(packets, encoded_chunk)
    end
    return packets
end

function save(output::Union{File{format"OPUS"},AbstractString,IO}, audio::Array{Float32}, fs; chunksize=960)
    # Encode the audio into packets
    enc = OpusEncoder(fs, size(audio, 2))
    packets = encode(enc, audio; chunksize=chunksize)

    # Calculate granule positions for each packet
    granulepos = vcat(0, 0, collect(1:length(packets))*div(chunksize,2))

    # Save it out into an Ogg file with an OpusHead and OpusTags
    opus_head = OpusHead(fs, size(audio, 2))
    insert!(packets, 1, opus_head)
    opus_tags = OpusTags()
    insert!(packets, 2, opus_tags)
    Ogg.save(output, packets, granulepos)
end

function save(output::Union{File{format"OPUS"},AbstractString,IO}, audio::Array, fs; chunksize=960)
    return save(output, map(Float32, audio), fs, chunksize=chunksize)
end
