#!/bin/zsh
# Builds Last Mile and installs it on an iPhone plugged in by cable, then launches it.
#   tools/install_ios.sh            # the first connected iPhone
#   tools/install_ios.sh <UDID>     # a particular device (xcrun devicectl list devices)
# Needs: Xcode signed in to team 7FR35W6Q64, the phone in Developer Mode and trusting this Mac,
# and Godot's iOS export templates. Signing uses the "iOS" preset in export_presets.cfg.
set -e
cd "${0:A:h}/.."
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
BUNDLE=com.stevenhester.lastmile

DEVICE=$1
if [[ -z $DEVICE ]]; then
	DEVICE=$(xcrun devicectl list devices 2>/dev/null | awk '/connected/ && /iPhone/ { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) { print $i; exit } }')
fi
if [[ -z $DEVICE ]]; then
	echo "No connected iPhone found. Plug it in, unlock it, and tap Trust if asked." >&2
	exit 1
fi
echo "==> Device $DEVICE"

echo "==> Exporting the Xcode project"
mkdir -p build/ios
$GODOT --headless --path . --export-release "iOS" build/ios/LastMile.xcodeproj > build/ios/export.log 2>&1 || { tail -20 build/ios/export.log; exit 1; }

echo "==> Building and signing (log: build/ios/xcodebuild.log)"
xcodebuild -project build/ios/LastMile.xcodeproj -scheme LastMile -configuration Release \
	-destination "id=$DEVICE" -allowProvisioningUpdates -derivedDataPath build/ios/dd build \
	> build/ios/xcodebuild.log 2>&1 || { grep -E 'error:' build/ios/xcodebuild.log | head -20; exit 1; }

APP=build/ios/dd/Build/Products/Release-iphoneos/LastMile.app
echo "==> Installing"
xcrun devicectl device install app --device "$DEVICE" "$APP"
echo "==> Launching"
xcrun devicectl device process launch --device "$DEVICE" --terminate-existing $BUNDLE || \
	echo "Installed. If it didn't open, the phone may be locked: open Last Mile from the home screen."
