#!/usr/bin/env bash
# Generate the AlwaysRain audio: a seamless rain bed and a thunder one-shot.
# Everything is synthesised locally with ffmpeg - no downloads, nothing to license.
#
# Usage: make_rain_audio.sh <out_dir>
set -euo pipefail
OUT="${1:?usage: make_rain_audio.sh <out_dir>}"
DUR=24          # rain loop length in seconds; AlwaysRain.lua must match
FADE=0.35       # end fades; the Lua ticker overlaps clips by this much

# Rain bed: three noise layers stacked.
#   low   - the distant roar of heavy rain on ground
#   mid   - the body of the downpour
#   high  - patter and spatter detail, panned wide for a stereo field
ffmpeg -y -hide_banner -loglevel error \
  -f lavfi -i "anoisesrc=color=brown:sample_rate=44100:duration=${DUR}:amplitude=0.9:seed=11" \
  -f lavfi -i "anoisesrc=color=white:sample_rate=44100:duration=${DUR}:amplitude=0.9:seed=23" \
  -f lavfi -i "anoisesrc=color=white:sample_rate=44100:duration=${DUR}:amplitude=0.9:seed=37" \
  -filter_complex "
    [0]lowpass=f=520,volume=1.35[low];
    [1]highpass=f=700,lowpass=f=5200,tremolo=f=0.23:d=0.16,volume=0.62[mid];
    [2]highpass=f=3600,lowpass=f=11000,tremolo=f=0.41:d=0.22,volume=0.30[hi];
    [low][mid][hi]amix=inputs=3:normalize=0[mono];
    [mono]asplit=2[ml][mr];
    [ml]adelay=0|0,volume=1.0[l];
    [mr]adelay=11|11,volume=0.96[r];
    [l][r]amerge=inputs=2,
      alimiter=limit=0.92,
      volume=0.85,
      afade=t=in:st=0:d=${FADE},
      afade=t=out:st=$(echo "$DUR - $FADE" | bc):d=${FADE}
  " -ac 2 -c:a libvorbis -q:a 4 "${OUT}/rain.ogg"

# Thunder: a sub-bass rumble with a cracking transient on top, decaying over ~6s.
ffmpeg -y -hide_banner -loglevel error \
  -f lavfi -i "anoisesrc=color=brown:sample_rate=44100:duration=6:amplitude=0.95:seed=5" \
  -f lavfi -i "anoisesrc=color=white:sample_rate=44100:duration=6:amplitude=0.95:seed=17" \
  -filter_complex "
    [0]lowpass=f=160,volume='0.15+1.5*exp(-t*0.55)':eval=frame[rumble];
    [1]highpass=f=400,lowpass=f=4200,volume='1.1*exp(-t*6.5)+0.12*exp(-t*1.4)':eval=frame[crack];
    [rumble][crack]amix=inputs=2:normalize=0[mono];
    [mono]asplit=2[tl][tr];
    [tl]volume=1.0[l];[tr]adelay=7|7,volume=0.97[r];
    [l][r]amerge=inputs=2,alimiter=limit=0.9,volume=0.8,afade=t=out:st=5.5:d=0.5
  " -ac 2 -c:a libvorbis -q:a 4 "${OUT}/thunder.ogg"

for f in rain thunder; do
  printf '%s: %s s, %s\n' "$f" \
    "$(ffprobe -v error -show_entries format=duration -of csv=p=0 "${OUT}/${f}.ogg")" \
    "$(du -h "${OUT}/${f}.ogg" | cut -f1)"
done
