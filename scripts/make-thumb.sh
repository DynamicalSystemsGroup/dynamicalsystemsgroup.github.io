#!/usr/bin/env bash
#
# make-thumb.sh — turn a screen recording into a looping WebM thumbnail for the
# demo showcase: speeds the clip to a fixed duration, crops to 16:10, and writes
# a matching poster still.
#
# Usage:
#   scripts/make-thumb.sh [options] <input.mov>
#
# Options:
#   -d <seconds>  target duration, clip is sped up/down to hit it (default 6)
#   -x <S:E>      cut out the span from S to E seconds before speeding up
#   -w <pixels>   output width; height derived for 16:10        (default 1280)
#   -o <path>     output .webm path        (default assets/screenshots/<name>.webm)
#   -r <fps>      frame rate                                     (default 15)
#   -q <crf>      VP9 quality, lower = sharper/bigger            (default 34)
#   -C            do not crop to 16:10 (scale width only)
#   -P            do not write a poster image
#   -h            show this help
#
# Examples:
#   scripts/make-thumb.sh ~/Desktop/adcs.mov
#   scripts/make-thumb.sh -d 5 -q 32 -o assets/screenshots/geospatial-demo.webm rec.mov
#   scripts/make-thumb.sh -d 7.5 -x 24:26 raw/rebrand.mov   # drop an accidental popup
#
# Requires: ffmpeg, ffprobe  (brew install ffmpeg)

set -euo pipefail

usage() { sed -n '2,/^$/{/^#/!d; s/^# \{0,1\}//; s/^#//; p;}' "$0"; }
die()   { printf 'make-thumb: %s\n' "$1" >&2; exit 1; }

command -v ffmpeg  >/dev/null 2>&1 || die "ffmpeg not found (brew install ffmpeg)"
command -v ffprobe >/dev/null 2>&1 || die "ffprobe not found (brew install ffmpeg)"

# ── defaults ────────────────────────────────────────────────────────────────
DURATION=6
WIDTH=1280
FPS=15
CRF=34
CROP=1
POSTER=1
OUT=""
CUT=""

while getopts ":d:x:w:o:r:q:CPh" opt; do
  case "$opt" in
    d) DURATION=$OPTARG ;;
    x) CUT=$OPTARG ;;
    w) WIDTH=$OPTARG ;;
    o) OUT=$OPTARG ;;
    r) FPS=$OPTARG ;;
    q) CRF=$OPTARG ;;
    C) CROP=0 ;;
    P) POSTER=0 ;;
    h) usage; exit 0 ;;
    \?) die "unknown option -$OPTARG (try -h)" ;;
    :)  die "option -$OPTARG needs a value" ;;
  esac
done
shift $((OPTIND - 1))

[ $# -ge 1 ] || die "no input file given (try -h)"
INPUT=$1
[ -f "$INPUT" ] || die "input not found: $INPUT"

# ── resolve output path ───────────────────────────────────────────────────────
if [ -z "$OUT" ]; then
  base=$(basename "$INPUT"); name=${base%.*}
  OUT="assets/screenshots/${name}.webm"
fi
mkdir -p "$(dirname "$OUT")"

SRC_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$INPUT")
[ -n "$SRC_DUR" ] || die "could not read duration of $INPUT"

# ── optional middle cut (-x S:E removes that span) ────────────────────────────
PREFIX=""        # filtergraph that produces [src]
SRC_LABEL="[0:v]"
CUT_DUR=0
if [ -n "$CUT" ]; then
  CS=${CUT%%:*}; CE=${CUT##*:}
  { [ "$CS" != "$CUT" ] && [ -n "$CS" ] && [ -n "$CE" ]; } || die "bad -x '$CUT' (use START:END in seconds)"
  CUT_DUR=$(echo "$CE - $CS" | bc -l)
  PREFIX="[0:v]trim=0:${CS},setpts=PTS-STARTPTS[a];[0:v]trim=start=${CE},setpts=PTS-STARTPTS[b];[a][b]concat=n=2:v=1[src];"
  SRC_LABEL="[src]"
fi

# ── speed factor: post-cut content lands exactly on $DURATION ─────────────────
EFF_DUR=$(echo "$SRC_DUR - $CUT_DUR" | bc -l)
N=$(echo "scale=6; $EFF_DUR / $DURATION" | bc -l)

# ── 16:10 height for the chosen width (even number) ───────────────────────────
HEIGHT=$(printf '%.0f' "$(echo "scale=4; $WIDTH * 10 / 16" | bc -l)")
HEIGHT=$(( HEIGHT - HEIGHT % 2 ))

# ── filter graph ──────────────────────────────────────────────────────────────
# setpts=PTS/N -> speed change  |  cover-scale then crop from top-left to 16:10
if [ "$CROP" -eq 1 ]; then
  POST="setpts=PTS/${N},fps=${FPS},scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=increase,crop=${WIDTH}:${HEIGHT}:0:0"
else
  POST="setpts=PTS/${N},fps=${FPS},scale=${WIDTH}:-2"
fi
FILTER="${PREFIX}${SRC_LABEL}${POST}[out]"

printf 'source : %s  (%.2fs)\n' "$INPUT" "$SRC_DUR"
[ -n "$CUT" ] && printf 'cut    : removed %s–%ss (%.2fs)\n' "$CS" "$CE" "$CUT_DUR"
printf 'target : %s  (%ss @ %sx%s, %sfps, crf %s, speed %.2fx)\n' \
  "$OUT" "$DURATION" "$WIDTH" "$HEIGHT" "$FPS" "$CRF" "$N"

ffmpeg -y -hide_banner -loglevel error -stats -i "$INPUT" \
  -filter_complex "$FILTER" -map "[out]" \
  -an -c:v libvpx-vp9 -crf "$CRF" -b:v 0 -row-mt 1 -pix_fmt yuv420p \
  "$OUT"

# ── poster: a representative still from the middle of the loop ─────────────────
if [ "$POSTER" -eq 1 ]; then
  POSTER_OUT="${OUT%.webm}.poster.jpg"
  HALF=$(echo "scale=3; $DURATION / 2" | bc -l)
  ffmpeg -y -hide_banner -loglevel error -ss "$HALF" -i "$OUT" \
    -frames:v 1 -q:v 3 "$POSTER_OUT"
  printf 'poster : %s\n' "$POSTER_OUT"
fi

OUT_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")
printf 'done   : %s  (%s, %.2fs)\n' "$OUT" "$(du -h "$OUT" | cut -f1)" "$OUT_DUR"
