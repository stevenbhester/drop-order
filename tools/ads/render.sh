#!/bin/zsh
# Renders the two demo ads (just for showing friends: not real ads) to ads/*.mp4.
#   tools/ads/render.sh [fun|bait ...]       (default: both)
# Needs Godot at $GODOT or the default path, and Xcode's swiftc. Frames go to a temp folder.
# Each video is kept under MAX_MB megabytes (default 26), so it can be sent as an attachment.
# With OGV=1, renders the copies the game plays as pretend ads instead (assets/ads/video/fun.ogv and
# clickbait.ogv, 540x960 Ogg Theora, straight from Godot's movie writer).
G=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
cd "$(dirname $0)/../.."
tmp=$(mktemp -d)
swiftc -O tools/ads/encode_mp4.swift -o $tmp/encode_mp4 || exit 1
mkdir -p ads
cuts=("$@"); [ ${#cuts} -eq 0 ] && cuts=(fun bait)
for cut in $cuts; do
  case $cut in
    fun) args=(--level=4 --save=done:22); name=last_mile_ad_fun ;;
    bait) args=(--level=17 --save=momentum:0); name=last_mile_ad_clickbait ;;
  esac
  if [ -n "$OGV" ]; then
    mkdir -p assets/ads/video
    # Smaller files for the app: lower video quality, just for this render (override.cfg is removed after).
    printf "[editor]\nmovie_writer/video_quality=${OGV_QUALITY:-0.3}\nmovie_writer/ogv/audio_quality=0.3\nmovie_writer/ogv/keyframe_interval=150\n" > override.cfg
    short=${name#last_mile_ad_}
    $G --path . res://tools/ads/ad.tscn --resolution 540x960 --fixed-fps 30 --write-movie assets/ads/video/$short.ogv -- --ad=$cut --no-intro $args \
      2>&1 | grep -E "SCRIPT ERROR|ERROR: " | grep -v "resources still in use" | head
    rm -f override.cfg
    continue
  fi
  mkdir -p $tmp/$cut/movie $tmp/$cut/frames
  $G --path . res://tools/ads/ad.tscn --fixed-fps 30 --write-movie $tmp/$cut/movie/m.png -- --ad=$cut --no-intro --out=$tmp/$cut/frames $args \
    2>&1 | grep -E "SCRIPT ERROR|ERROR: " | grep -v "resources still in use" | head
  $tmp/encode_mp4 $tmp/$cut/frames $tmp/$cut/movie/m.wav ads/$name.mp4 30 ${MAX_MB:-26}
done
[ -n "$KEEP" ] && echo "frames kept in $tmp" || rm -rf $tmp
