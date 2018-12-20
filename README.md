# Opus

[![Build Status](https://travis-ci.org/staticfloat/Opus.jl.svg?branch=master)](https://travis-ci.org/staticfloat/Opus.jl)

Basic bindings to `libopus` to encode/decode [Opus](https://www.opus-codec.org/) streams.  Opus is a low-latency yet high-quality audio codec with an impressive set of features and very simple API. Note that a common surprise with Opus is that it supports a very limited set of samplerates.  Do yourself a favor and just resample any audio (with, for example, a [polyphase resampler from `DSP.jl`](http://dspjl.readthedocs.io/en/latest/filters.html#resample)) you have to 48 KHz before encoding.

Basic usage is to use `load()` and `save()` to read/write Opus streams to/from file paths, IO streams, etc., but the real fun to be had is in an [IJulia](https://github.com/JuliaLang/IJulia.jl) notebook with `OpusArrays`. These thin wrapper objects contain a `show()` implementation allowing you to output raw audio as Opus to a reasonably modern browser.  To try it out, put the following in an IJulia notebook:

```julia
using Opus

# Create a seconds worth of 440Hz
t = linspace(0,1,48000)
audio = sin(2*π*440*t)

z = OpusArray(audio)
```
