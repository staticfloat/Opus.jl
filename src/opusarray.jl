type OpusArray
    encoded_stream::IO
    function OpusArray(raw_audio, fs=48000)
        buf = IOBuffer()
        Opus.save(buf, Float32[Float32(x) for x in raw_audio], fs)
        return new(buf)
    end
end

function writemime(io::IO, ::MIME"text/html", x::OpusArray)
    data = base64encode(bytestring(x.encoded_stream))
    markup = """<audio controls="controls" {autoplay}>
                <source src="data:audio/ogg;base64,$data" type="audio/ogg" />
                Your browser does not support the audio element.
                </audio>"""
    print(io, markup)
end
