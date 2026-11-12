#!/bin/zsh
# Builds the daily-reminder iOS plugin: ios/plugins/src/LastMileNotify.mm -> ios/plugins/LastMileNotify.xcframework
# (device arm64 + simulator arm64/x86_64). Skips the build if the framework is newer than the source.
#   tools/build_notify_plugin.sh [--force]
set -e
cd "${0:A:h}/.."
SRC=ios/plugins/src/LastMileNotify.mm
OUT=ios/plugins/LastMileNotify.xcframework
if [[ $1 != --force && -d $OUT && $OUT -nt $SRC ]]; then
	exit 0
fi
TMP=build/notify_plugin
rm -rf $TMP $OUT
mkdir -p $TMP/device $TMP/sim
FLAGS=(-std=c++17 -fobjc-arc -O2 -fvisibility=default -c $SRC)
xcrun -sdk iphoneos clang++ -target arm64-apple-ios15.0 $FLAGS -o $TMP/device.o
xcrun -sdk iphonesimulator clang++ -target arm64-apple-ios15.0-simulator $FLAGS -o $TMP/sim_arm64.o
xcrun -sdk iphonesimulator clang++ -target x86_64-apple-ios15.0-simulator $FLAGS -o $TMP/sim_x86.o
xcrun libtool -static -o $TMP/device/libLastMileNotify.a $TMP/device.o
xcrun libtool -static -o $TMP/sim/libLastMileNotify.a $TMP/sim_arm64.o $TMP/sim_x86.o
xcodebuild -create-xcframework -library $TMP/device/libLastMileNotify.a -library $TMP/sim/libLastMileNotify.a -output $OUT > /dev/null
echo "Built $OUT"
