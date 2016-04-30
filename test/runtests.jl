using Base.Test
using Opus
using Ogg

ogg_dec = Ogg.OggDecoder()
Ogg.decode_all(ogg_dec, Pkg.dir("Opus", "test", "4410Hz.opus"))

serial = 1035355421

# There's only a single stream decoded
@test length(ogg_dec.packets) == 1
# That stream has the serial number we're expecting
@test first(keys(ogg_dec.packets)) == serial

# That stream has the number of packets that we're expecting
@test length(ogg_dec.packets[serial]) == 3

# Build a decoder for it
opus_dec = Opus.OpusDecoder(48000,1)
audio = Opus.decode_packets(opus_dec, ogg_dec.packets[serial])

# Make sure we get as many samples as we expected (note that there is some padding
# done by libopus during encoding due to the extremely short input length)
@test length(audio) == 960

# Make sure the frequency we recover is within 10 Hz to what we expect
audio_freq = (indmax(abs(fft(audio)[1:div(end,2)])) - 1)*48000/length(audio)
@test abs(audio_freq - 4410) <= 10
