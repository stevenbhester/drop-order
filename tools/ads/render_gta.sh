#!/bin/zsh
# Renders the GTA VI trash-talk ad (a joke for friends, not a real ad) to ads/last_mile_ad_gta.mp4.
#   SONG=/path/to/song.mp3 tools/ads/render_gta.sh
# The song is your own file; its first ~21 s are used. Needs Godot at $GODOT or the default path, and swiftc.
G=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
SONG=${SONG:-"$HOME/Downloads/BIA - WE ON GO (Lyrics).mp3"}
cd "$(dirname $0)/../.."
tmp=$(mktemp -d)
swiftc -O tools/ads/encode_mp4.swift -o $tmp/encode_mp4 2>/dev/null || exit 1
mkdir -p ads $tmp/movie $tmp/frames
$G --path . res://tools/ads/gta.tscn --fixed-fps 30 --write-movie $tmp/movie/m.png -- --no-intro --level=45 \
  --save=momentum:3,done:44 --song="$SONG" --out=$tmp/frames 2>&1 | grep -E "SCRIPT ERROR|ERROR: " | grep -v "resources still in use" | head
$tmp/encode_mp4 $tmp/frames $tmp/movie/m.wav ads/last_mile_ad_gta.mp4 30
[ -n "$KEEP" ] && echo "frames kept in $tmp" || rm -rf $tmp
