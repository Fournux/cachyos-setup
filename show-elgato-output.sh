#!/usr/bin/env bash
set -euo pipefail

elgato_video_device="/dev/v4l/by-id/usb-Elgato_Elgato_HD60_X_A00XB45121L72D-video-index0"
elgato_sound_device="plughw:X,0"
volume=100

usage() {
  cat <<'USAGE'
Usage: ./show-elgato-output.sh [options]

Options:
  --video-device PATH   V4L2 capture device
  --sound-device NAME   ALSA capture device
  --volume PERCENT      Integer volume from 0 to 200 (default: 100)
  -h, --help            Show this help
USAGE
}

require_value() {
  if [[ $# -lt 2 || -z $2 ]]; then
    printf 'Missing value for %s
' "$1" >&2
    usage >&2
    exit 2
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --video-device|--elgato-video-device|--elgato_video_device)
      require_value "$@"
      elgato_video_device=$2
      shift 2
      ;;
    --sound-device|--elgato-sound-device|--elgato_sound_device)
      require_value "$@"
      elgato_sound_device=$2
      shift 2
      ;;
    --volume)
      require_value "$@"
      volume=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s
' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! $volume =~ ^[0-9]+$ ]]; then
  printf 'Volume must be an integer from 0 to 200.
' >&2
  exit 2
fi
volume=$((10#$volume))
if (( volume > 200 )); then
  printf 'Volume must be an integer from 0 to 200.
' >&2
  exit 2
fi

if [[ ! -e $elgato_video_device ]]; then
  printf 'Video device not found: %s
' "$elgato_video_device" >&2
  exit 1
fi

command -v gst-launch-1.0 >/dev/null || {
  printf 'gst-launch-1.0 is required.
' >&2
  exit 1
}

command -v awk >/dev/null || {
  printf 'awk is required.
' >&2
  exit 1
}

gst_volume=$(awk -v volume="$volume" 'BEGIN {printf "%.2f", volume / 100}')

gst-launch-1.0 -v \
  v4l2src "device=$elgato_video_device" io-mode=dmabuf do-timestamp=false ! \
  video/x-raw,format=NV12,width=1920,height=1080,framerate=60/1 ! \
  queue max-size-buffers=1 max-size-bytes=0 max-size-time=0 leaky=downstream ! \
  waylandsink sync=false fullscreen=true \
  alsasrc "device=$elgato_sound_device" buffer-time=10000 latency-time=5000 ! \
  queue max-size-buffers=1 max-size-bytes=0 max-size-time=0 leaky=downstream ! \
  volume "volume=$gst_volume" ! \
  pulsesink sync=false
