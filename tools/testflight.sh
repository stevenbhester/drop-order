#!/bin/zsh
# Builds Last Mile for TestFlight and uploads it to App Store Connect.
#   tools/testflight.sh              # archive, upload (internal testers only), then bump the build number
#   tools/testflight.sh --external   # same, but the build may also go to external testers (Beta App Review)
#   tools/testflight.sh --no-upload  # archive only: checks everything builds, sends nothing
#
# Before the first upload: create the app in App Store Connect (Apps > + > New App) with bundle ID
# com.stevenhester.lastmile. Xcode must be signed in to team 7FR35W6Q64.
#
# The build number is application/version in the iOS preset of export_presets.cfg. Apple refuses a number it
# has seen before, so after a successful upload this script raises it by one, ready for next time.
set -e
cd "${0:A:h}/.."
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
TEAM=7FR35W6Q64
OUT=build/ios
ARCHIVE=$OUT/LastMile.xcarchive

UPLOAD=1
INTERNAL=true
for a in "$@"; do
	case $a in
		--no-upload) UPLOAD=0 ;;
		--external) INTERNAL=false ;;
		*) echo "Unknown option: $a" >&2; exit 2 ;;
	esac
done

# The iOS preset's own lines (the macOS preset has a version of its own).
ios_setting() {
	awk -v key="$1" '/^\[preset\.[0-9]+\]/ { ios = 0 } /^platform="iOS"/ { ios = 1 } /^\[preset\.[0-9]+\.options\]/ { opts = ios }
		opts && index($0, key "=") == 1 { gsub(/^[^"]*"|"$/, ""); print; exit }' export_presets.cfg
}
BUILD=$(ios_setting application/version)
VERSION=$(ios_setting application/short_version)
if [[ ! $BUILD =~ '^[0-9]+$' ]]; then
	echo "Couldn't read the build number from export_presets.cfg (got '$BUILD')." >&2
	exit 1
fi
echo "==> Last Mile $VERSION, build $BUILD"
# The game names its build in bug reports (Version.BUILD): keep it in step with this archive.
sed -i '' "s/^const BUILD := .*/const BUILD := $BUILD/" scripts/version.gd

echo "==> Building the daily-reminder plugin"
tools/build_notify_plugin.sh

echo "==> Exporting the Xcode project"
mkdir -p $OUT
$GODOT --headless --path . --export-release "iOS" $OUT/LastMile.xcodeproj > $OUT/export.log 2>&1 || { tail -20 $OUT/export.log; exit 1; }

echo "==> Archiving (log: $OUT/archive.log)"
rm -rf $ARCHIVE
xcodebuild -project $OUT/LastMile.xcodeproj -scheme LastMile -configuration Release \
	-destination 'generic/platform=iOS' -archivePath $ARCHIVE -allowProvisioningUpdates archive \
	> $OUT/archive.log 2>&1 || { grep -E 'error:' $OUT/archive.log | head -20; exit 1; }
echo "    $ARCHIVE"

# Tell players' games this build is coming (release/latest.json, read from GitHub once it's pushed).
$GODOT --headless --path . --script res://tools/release_note.gd -- --build=$BUILD | grep '^release/'

if [[ $UPLOAD == 0 ]]; then
	echo "==> Archive built. Nothing uploaded (--no-upload)."
	exit 0
fi

cat > $OUT/ExportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>app-store-connect</string>
	<key>destination</key><string>upload</string>
	<key>testFlightInternalTestingOnly</key><$INTERNAL/>
	<key>teamID</key><string>$TEAM</string>
	<key>signingStyle</key><string>automatic</string>
</dict>
</plist>
EOF

echo "==> Uploading to App Store Connect ($([[ $INTERNAL == true ]] && echo "internal testers only" || echo "internal and external testers")) (log: $OUT/upload.log)"
xcodebuild -exportArchive -archivePath $ARCHIVE -exportOptionsPlist $OUT/ExportOptions.plist \
	-exportPath $OUT/export -allowProvisioningUpdates > $OUT/upload.log 2>&1 || {
		grep -iE 'error|failed|invalid|not found' $OUT/upload.log | head -20
		echo "Upload failed. If it says the app wasn't found, create it in App Store Connect first (see the top of this script)." >&2
		exit 1
	}

# Ready for next time: Apple won't take this number again.
NEXT=$((BUILD + 1))
awk -v next_build="$NEXT" '/^\[preset\.[0-9]+\]/ { ios = 0 } /^platform="iOS"/ { ios = 1 } /^\[preset\.[0-9]+\.options\]/ { opts = ios }
	opts && index($0, "application/version=") == 1 { print "application/version=\"" next_build "\""; next } { print }' \
	export_presets.cfg > $OUT/export_presets.tmp && mv $OUT/export_presets.tmp export_presets.cfg

echo "==> Uploaded build $BUILD. It appears under TestFlight in App Store Connect after 5-15 minutes of processing."
echo "    export_presets.cfg now says build $NEXT, for the next upload."
