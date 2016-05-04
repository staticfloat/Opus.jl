using Base.Test
using Opus
using Ogg

# First, try roundtripping some signals and ensuring they're reasonably close
function avg_roundtrip_error(audio; preskip=312)
    fio = IOBuffer()
    Opus.save(fio, audio, 48000)
    seekstart(fio)
    audio_dec = Opus.load(fio)[1]

    N = length(audio) - preskip
    avg_error = sum(abs(audio_dec[preskip+1:min(end,length(audio))] - audio[1:end-preskip]))/N
    return avg_error
end

# We'll construct "one second" of signal
t = linspace(0,1,48000)
sin_signal = sin(2*π*440*t)
harmonic_signal = sum([.1*k^-1.5*sin(2*π*440*k*t) for k in 1:.1:4])
filtered_noise = filt([0.018, 0.054, 0.054, 0.018], [1.0, -1.760, 1.182, -0.278], randn(1000))

# Each signal is harder for Opus to model, so increase the error bounds for each one
@test avg_roundtrip_error(sin_signal) < .01
@test avg_roundtrip_error(harmonic_signal) < .02
@test avg_roundtrip_error(filtered_noise) < .08


# Now perform some tests to ensure that we can decode some Ogg Opus files
packets = Ogg.load(Pkg.dir("Opus", "test", "4410Hz.opus"))

serial = 1035355421

# Ensure there's only a single stream decoded
@test length(packets) == 1
# Ensure that stream has the serial number we're expecting
@test first(keys(packets)) == serial

# Ensure that stream has the number of packets that we're expecting
@test length(packets[serial]) == 3

# Build a decoder for it
opus_dec = OpusDecoder(48000,1)
audio = Opus.decode_all_packets(opus_dec, packets[serial])

# Make sure we get as many samples as we expected (note that there is some padding
# done by libopus during encoding due to the extremely short input length)
@test length(audio) == 960

# Make sure the frequency we recover is within 10 Hz of what we expect
audio_freq = (indmax(abs(fft(audio)[1:div(end,2)])) - 1)*48000/length(audio)
@test abs(audio_freq - 4410) <= 10
