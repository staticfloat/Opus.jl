module Opus
using Ogg, Opus_jll
using FileIO
import Base: convert, show, write

export OpusDecoder, OpusEncoder, OpusArray, load, save

include("defines.jl")
include("decoder.jl")
include("encoder.jl")
include("opusarray.jl")

end # module
