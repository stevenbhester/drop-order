#!/bin/zsh
# Renders the GTA VI trash-talk ad (a joke for friends, not a real ad) to ads/last_mile_ad_gta.mp4.
#   SONG=/path/to/song.mp3 tools/ads/render_gta.sh
# The song is your own file; its first ~21 s are used. Needs Godot at $GODOT or the default path, and swiftc.
#   OGV=1 tools/ads/render_gta.sh
# instead renders the copy the game plays as a pretend ad (assets/ads/video/gta.ogv, 540x960): no song in it
# (a commercial track can't ship in the app), so the ad's own synthesized beat plays.
G=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
SONG=${SONG:-"$HOME/Downloads/BIA - WE ON GO (Lyrics).mp3"}
cd "$(dirname $0)/../.."
if [ -n "$OGV" ]; then
  mkdir -p assets/ads/video
  # Smaller files for the app: lower video quality, just for this render (override.cfg is removed after).
  printf "[editor]\nmovie_writer/video_quality=${OGV_QUALITY:-0.3}\nmovie_writer/ogv/audio_quality=0.3\nmovie_writer/ogv/keyframe_interval=150\n" > override.cfg
  $G --path . res://tools/ads/gta.tscn --resolution 540x960 --fixed-fps 30 --write-movie assets/ads/video/gta.ogv -- --no-intro \
    --level=95 --save=momentum:3,done:94 2>&1 | grep -E "SCRIPT ERROR|ERROR: " | grep -v "resources still in use" | head
  rm -f override.cfg
  exit 0
fi
tmp=$(mktemp -d)
swiftc -O tools/ads/encode_mp4.swift -o $tmp/encode_mp4 2>/dev/null || exit 1
mkdir -p ads $tmp/movie $tmp/frames
$G --path . res://tools/ads/gta.tscn --fixed-fps 30 --write-movie $tmp/movie/m.png -- --no-intro --level=95 \
  --save=momentum:3,done:94 --song="$SONG" --out=$tmp/frames 2>&1 | grep -E "SCRIPT ERROR|ERROR: " | grep -v "resources still in use" | head
$tmp/encode_mp4 $tmp/frames $tmp/movie/m.wav ads/last_mile_ad_gta.mp4 30
[ -n "$KEEP" ] && echo "frames kept in $tmp" || rm -rf $tmp
