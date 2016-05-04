__precompile__()
module Opus
using Compat
using Ogg
using FileIO

export OpusDecoder, OpusEncoder, load, save

const depfile = joinpath(dirname(@__FILE__), "..", "deps", "deps.jl")
if isfile(depfile)
    include(depfile)
else
    error("libopus not properly installed. Please run Pkg.build(\"Opus\")")
end

include("defines.jl")
include("decoder.jl")
include("encoder.jl")

end # module
