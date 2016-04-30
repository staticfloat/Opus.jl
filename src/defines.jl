
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
