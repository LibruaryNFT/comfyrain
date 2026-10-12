#!/usr/bin/env python3
"""Generate the AlwaysRain audio: a seamless rain bed and a thunder one-shot.

The loop is seamless *by construction*: the noise is shaped in the frequency
domain over exactly one loop length, so the signal is periodic and the join is
sample-exact. That removes the end fades the first version needed, which were
what made two clips audibly swell over each other at the seam.

Five gain variants are written so /rain volume can switch level in game -
PlaySoundFile takes no volume argument, so level has to live in the file.

Usage: make_rain_audio.py <out_dir>
"""
import subprocess
import sys

import numpy as np

SR = 44100
DUR = 24.0                      # must match RAIN_LEN in AlwaysRain.lua
N = int(SR * DUR)

# dB below the reference bed, index 1..5. Default in the addon is 2.
VOLUME_STEPS_DB = {1: -30.0, 2: -24.0, 3: -18.0, 4: -12.0, 5: -6.0}


def periodic_noise(rng):
    """White noise made periodic over N samples, shaped like falling rain."""
    x = rng.standard_normal(N)
    X = np.fft.rfft(x)
    f = np.maximum(np.fft.rfftfreq(N, 1.0 / SR), 20.0)

    env = (f / 1000.0) ** -0.35                       # pink-ish tilt
    env *= 1.0 + 1.8 / (1.0 + (f / 180.0) ** 2)       # low roar of rain on ground
    env *= 1.0 + 0.9 * np.exp(-(np.log(f / 2500.0) ** 2) / 0.5)   # patter band
    env *= 1.0 / (1.0 + (f / 9000.0) ** 2)            # roll off the fizz
    env[0] = 0.0                                      # no DC

    return np.fft.irfft(X * env, n=N)


def periodic_lfo(rng, cycles, depth):
    """Gentle gusting. Integer cycle counts keep the loop periodic."""
    t = np.arange(N) / SR
    lfo = np.ones(N)
    for k, d in zip(cycles, depth):
        lfo += d * np.sin(2 * np.pi * k * t / DUR + rng.uniform(0, 2 * np.pi))
    return lfo


def droplets(rng, count):
    """Sparse bright transients. Indices wrap, so these stay periodic too."""
    out = np.zeros(N)
    for _ in range(count):
        tau = rng.uniform(0.002, 0.009)
        length = int(tau * 6 * SR)
        env = np.exp(-np.arange(length) / (tau * SR))
        burst = rng.standard_normal(length) * env * rng.uniform(0.25, 1.0)
        start = rng.integers(0, N)
        idx = (start + np.arange(length)) % N
        np.add.at(out, idx, burst)
    # keep droplets in the upper band so they read as spatter, not clicks
    D = np.fft.rfft(out)
    f = np.maximum(np.fft.rfftfreq(N, 1.0 / SR), 20.0)
    D *= (f / 3000.0) ** 0.6 / (1.0 + (f / 11000.0) ** 2)
    return np.fft.irfft(D, n=N)


def build_rain():
    chans = []
    for seed in (101, 202):                      # independent L/R -> wide field
        rng = np.random.default_rng(seed)
        bed = periodic_noise(rng)
        bed /= np.max(np.abs(bed))
        bed *= periodic_lfo(rng, (3, 7, 13), (0.07, 0.04, 0.03))
        spatter = droplets(rng, 1400)
        spatter /= max(np.max(np.abs(spatter)), 1e-9)
        chans.append(bed + 0.22 * spatter)
    stereo = np.stack(chans, axis=-1)
    return stereo / np.max(np.abs(stereo))       # peak-normalised reference


def build_thunder():
    dur, n = 6.0, int(6.0 * SR)
    t = np.arange(n) / SR
    chans = []
    for seed in (7, 9):
        rng = np.random.default_rng(seed)
        f = np.maximum(np.fft.rfftfreq(n, 1.0 / SR), 10.0)

        rumble = np.fft.irfft(
            np.fft.rfft(rng.standard_normal(n)) / (1.0 + (f / 140.0) ** 2) ** 1.5, n=n)
        rumble /= np.max(np.abs(rumble))
        rumble *= 0.15 + 1.5 * np.exp(-t * 0.55)

        crack = np.fft.irfft(
            np.fft.rfft(rng.standard_normal(n))
            * ((f / 400.0) ** 0.8 / (1.0 + (f / 4200.0) ** 2)), n=n)
        crack /= np.max(np.abs(crack))
        crack *= 1.1 * np.exp(-t * 6.5) + 0.12 * np.exp(-t * 1.4)

        chans.append(rumble + 0.55 * crack)
    stereo = np.stack(chans, axis=-1)
    stereo /= np.max(np.abs(stereo))
    stereo *= np.minimum(1.0, np.exp(-(t - 5.5) * 6.0))[:, None]   # tail to silence
    return stereo


def encode(samples, path, gain_db=0.0):
    data = (samples * (10.0 ** (gain_db / 20.0))).astype(np.float32)
    peak = float(np.max(np.abs(data)))
    rms = float(np.sqrt(np.mean(data.astype(np.float64) ** 2)))
    subprocess.run(
        ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
         "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
         "-c:a", "libvorbis", "-q:a", "4", path],
        input=data.tobytes(), check=True)
    return peak, rms


def db(x):
    return 20 * np.log10(max(x, 1e-9))


def main():
    out = sys.argv[1].rstrip("/")

    rain = build_rain()
    for step, gain in sorted(VOLUME_STEPS_DB.items()):
        peak, rms = encode(rain, f"{out}/rain-v{step}.ogg", gain)
        print(f"rain-v{step}.ogg  gain {gain:+.0f} dB  peak {db(peak):6.1f} dBFS  rms {db(rms):6.1f} dBFS")

    # rain.ogg is the fallback the addon uses if a variant file is not yet
    # visible to the client (newly added files need a client restart).
    default = min(VOLUME_STEPS_DB, key=lambda k: abs(k - 2))
    encode(rain, f"{out}/rain.ogg", VOLUME_STEPS_DB[default])
    print(f"rain.ogg      = rain-v{default}.ogg (fallback copy)")

    peak, rms = encode(build_thunder(), f"{out}/thunder.ogg", -12.0)
    print(f"thunder.ogg   gain -12 dB  peak {db(peak):6.1f} dBFS  rms {db(rms):6.1f} dBFS")


if __name__ == "__main__":
    main()
