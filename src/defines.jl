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

OpusHead() = OpusHead(0x646165487375704f, 1, 1, 312, 48000, 0, 0)
OpusHead(samplerate, channels) = OpusHead(0x646165487375704f, 1, channels, 312, samplerate, 0, 0)

function OpusHead(io::IO)
    magic = read(io, UInt64)
    if magic != 0x646165487375704f
        error("Input packet is not an OpusHead!, magic is $(magic)")
    end
    version = read(io, UInt8)
    channels = read(io, UInt8)
    preskip = read(io, UInt16)
    samplerate = read(io, UInt32)
    output_gain = read(io, UInt16)
    channel_map_family = read(io, UInt8)
    return OpusHead( magic, version, channels, preskip, samplerate, output_gain, channel_map_family)
end
OpusHead(data::Vector{UInt8}) = OpusHead(IOBuffer(data))

function write(io::IO, x::OpusHead)
    write(io, x.opus_head)
    write(io, x.version)
    write(io, x.channels)
    write(io, x.preskip)
    write(io, x.samplerate)
    write(io, x.output_gain)
    write(io, x.channel_map_family)
end

function convert(::Type{Vector{UInt8}}, x::OpusHead)
    io = IOBuffer()
    write(io, x)
    seekstart(io)
    return readbytes(io)
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
OpusTags() = OpusTags(0x736761547375704f, "Opus.jl", AbstractString["encoder=Opus.jl"])

function read_opus_tag(io::IO)
    # First, read in a length
    len = read(io, UInt32)

    # Next, read the string
    return bytestring(readbytes(io, len))
end

function write_opus_tag(io::IO, tag::AbstractString)
    # First, write out the length
    write(io, UInt32(length(tag)))

    # Next, write out the tag itself
    write(io, tag)
end

function OpusTags(io::IO)
    magic = read(io, UInt64)
    if magic != 0x736761547375704f
        error("Input packet is not an OpusTags!, magic is $(magic)")
    end
    # First, read the vendor string
    vendor_string = read_opus_tag(io)

    # Next, read how many tags we've got
    num_tags = read(io, UInt32)

    # Read all the tags in, one after another
    tags = [read_opus_tag(io) for idx in 1:num_tags]

    return OpusTags(magic, vendor_string, tags)
end
OpusTags(data::Vector{UInt8}) = OpusTags(IOBuffer(data))

function write(io::IO, x::OpusTags)
    write(io, x.opus_tags)
    write_opus_tag(io, x.vendor_string)

    write(io, UInt32(length(x.tags)))
    for tagidx = 1:length(x.tags)
        write_opus_tag(io, x.tags[tagidx])
    end
end

function convert(::Type{Vector{UInt8}}, x::OpusTags)
    io = IOBuffer()
    write(io, x)
    seekstart(io)
    return readbytes(io)
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


function is_header_packet(packet::Vector{UInt8})
    # Check if it's an OpusHead or OpusTags packet
    if length(packet) > 8
        magic = bytestring(packet[1:8])
        if magic == "OpusHead" || magic == "OpusTags"
            return true
        end
    end

    return false
end
