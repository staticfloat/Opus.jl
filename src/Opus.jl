__precompile__()
module Opus
using Compat
using Ogg
using FileIO
import Base: writemime, convert, show, write

export OpusDecoder, OpusEncoder, OpusArray, load, save

const depfile = joinpath(dirname(@__FILE__), "..", "deps", "deps.jl")
if isfile(depfile)
    include(depfile)
else
    error("libopus not properly installed. Please run Pkg.build(\"Opus\")")
end


include("defines.jl")
include("decoder.jl")
include("encoder.jl")
include("opusarray.jl")

end # module
