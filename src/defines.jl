import Base: convert, show

# Opus error codes
const OPUS_OK               =  0
const OPUS_BAD_ARG          = -1
const OPUS_BUFFER_TOO_SMALL = -2
const OPUS_INTERNAL_ERROR   = -3
const OPUS_INVALID_PACKET   = -4
const OPUS_UNIMPLEMENTED    = -5
const OPUS_INVALID_STATE    = -6
const OPUS_ALLOC_FAIL       = -7

const OPUS_ERROR_MESSAGE_STRS = Dict(
    0  => "No Error",
    -1 => "Bad Argument",
    -2 => "Buffer Too Small",
    -3 => "Internal Error",
    -4 => "Invalid Packet",
    -5 => "Unimplemented",
    -6 => "Invalid State",
    -7 => "Allocation Failure"
)

const OPUS_APPLICATION_VOIP                = 2048
const OPUS_APPLICATION_AUDIO               = 2049
const OPUS_APPLICATION_RESTRICTED_LOWDELAY = 2051

immutable OpusHead
    # Magic bytes "OpusHead" (0x646165487375704f)
    opus_head::UInt64
    # Should always be equal to one
    version::UInt8
    # Number of channels, must be greater than zero
    channels::UInt8
    # This is the number of samples (at 48 kHz) to discard from the decoder
    # output when starting playback, and also the number to subtract from a
    # page's granule position to calculate its PCM sample position.
    # NOTE: This is currently completely ignored in Opus.jl
    preskip::UInt16
    # Samplerate of input stream (Let's face it, it's always 48 KHz)
    samplerate::UInt32
    # Output gain that should be applied
    output_gain::UInt16
    # Channel mapping family, we always assume this is zero
    channel_map_family::UInt8
end

OpusHead() = OpusHead(0x646165487375704f, 1, 1, 120, 48000, 0, 0)
OpusHead(samplerate, channels) = OpusHead(0x646165487375704f, 1, channels, 120, samplerate, 0, 0)
function OpusHead(data::Vector{UInt8})
    if length(data) < 19
        error("Input data too short: OpusHead structures are at least 19 bytes long!")
    end

    magic = reinterpret(UInt64, data[1:8])[1]
    if magic != 0x646165487375704f
        error("Input packet is not an OpusHead!, magic is $(magic)")
    end
    version = data[9]
    channels = data[10]
    preskip = reinterpret(UInt16, data[11:12])[1]
    samplerate = reinterpret(UInt32, data[13:16])[1]
    output_gain = reinterpret(UInt16, data[17:18])[1]
    channel_map_family = data[19]
    return OpusHead( magic, version, channels, preskip, samplerate, output_gain, channel_map_family)
end

function convert(::Type{Vector{UInt8}}, x::OpusHead)
    data = Vector{UInt8}(19)
    data[1:8] = reinterpret(UInt8, [x.opus_head])
    data[9] = x.version
    data[10] = x.channels
    data[11:12] = reinterpret(UInt8, [x.preskip])
    data[13:16] = reinterpret(UInt8, [x.samplerate])
    data[17:18] = reinterpret(UInt8, [x.output_gain])
    data[19] = x.channel_map_family
    return data
end

function show(io::IO, x::OpusHead)
    write(io, "OpusHead packet ($(x.samplerate)Hz, $(x.channels) channels)")
end


type OpusTags
    # Magic signature "OpusTags" (0x736761547375704f)
    opus_tags::UInt64

    vendor_string::AbstractString
    tags::Vector{AbstractString}
end
OpusTags() = OpusTags(0x736761547375704f, "Opus.jl", Vector{AbstractString}())

function read_opus_tag(data::Vector{UInt8}, offset = 1)
    # First, read in a length
    len = reinterpret(UInt32, data[offset:offset + 3])[1]
    # Next, read the string
    str = bytestring(data[offset + 4:offset+3+len])

    # offset is how many bytes we need to shift data over for our next tag
    offset += 4 + len
    return str, offset
end

function OpusTags(data::Vector{UInt8})
    magic = reinterpret(UInt64, data[1:8])[1]
    if magic != 0x736761547375704f
        error("Input packet is not an OpusTags!, magic is $(magic)")
    end
    # First, read the vendor string
    vendor_string, offset = read_opus_tag(data, 9)

    # Next, read how many tags we've got
    num_tags = reinterpret(UInt32, data[offset:offset + 3])[1]
    offset += 4

    tags = Vector{AbstractString}(num_tags)
    for idx in 1:num_tags
        tag, offset = read_opus_tag(data, offset)
        tags[idx] = tag
    end

    return OpusTags(magic, vendor_string, tags)
end

function convert(::Type{Vector{UInt8}}, x::OpusTags)
    total_len = 8 + 4 + length(x.vendor_string) +
                4 + 4*length(x.tags) + sum(Int64[length(z) for z in x.tags])
    data = Vector{UInt8}(total_len)
    data[1:8] = reinterpret(UInt8, [x.opus_tags])
    data[9:12] = reinterpret(UInt8, [UInt32(length(x.vendor_string))])
    data[13:12+length(x.vendor_string)] = x.vendor_string.data

    offset = 13 + length(x.vendor_string)
    data[offset:offset+3] = reinterpret(UInt8, [UInt32(length(x.tags))])
    offset += 4
    for tagidx = 1:length(x.tags)
        taglen = UInt32(len(x.tags[tagidx]))
        data[offset:offset+3] = reinterpret(UInt8, [taglen])
        data[offset+4:offset+3 + taglen] = x.tags[tagidx].data
        offset += 4 + taglen
    end
    return data
end

function show(io::IO, x::OpusTags)
    write(io, "OpusTags packet\n")
    write(io, "  Vendor: $(x.vendor_string)\n")
    write(io, "  Tags:")
    for tag in x.tags
        write(io, "\n")
        write(io, "    $tag")
    end
end
