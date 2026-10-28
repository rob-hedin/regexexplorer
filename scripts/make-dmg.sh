#!/bin/sh
# Copyright © 2026 Robert Hedin
#
# Builds a signed, notarized "drag to Applications" disk image from an exported,
# notarized RegexExplorer.app.
#
# Usage: scripts/make-dmg.sh <path to RegexExplorer.app> <notarytool keychain profile>
#
# Set SIGNING_IDENTITY to choose a certificate; by default codesign uses your
# only "Developer ID Application" certificate.
set -eu

if [ $# -ne 2 ]; then
    echo "Usage: $0 <path to RegexExplorer.app> <notarytool keychain profile>" >&2
    exit 64
fi

app=$1
profile=$2
identity=${SIGNING_IDENTITY:-Developer ID Application}
build=build
staging=$build/dmg
dmg=$build/RegexExplorer.dmg

if [ ! -d "$app" ]; then
    echo "No app at $app" >&2
    exit 66
fi

rm -rf "$staging" "$dmg"
mkdir -p "$staging"
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"

diskutil image create from --volumeName "RegEx Explorer" --format ULFO "$staging" "$dmg"
rm -rf "$staging"

codesign --sign "$identity" --timestamp "$dmg"
xcrun notarytool submit "$dmg" --keychain-profile "$profile" --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"

echo "Created $dmg"
