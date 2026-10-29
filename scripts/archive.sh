#!/usr/bin/env bash
# Archives Ravan and exports an .ipa.
#   scripts/archive.sh                 → App Store Connect / TestFlight upload build
#   scripts/archive.sh release-testing → ad-hoc build for registered devices
set -euo pipefail
cd "$(dirname "$0")/.."

# xcode-select may point at the Command Line Tools; use the full Xcode app instead (no sudo needed).
if [ -z "${DEVELOPER_DIR:-}" ] && xcode-select -p 2>/dev/null | grep -q CommandLineTools; then
  XCODE_APP="$(ls -d /Applications/Xcode*.app 2>/dev/null | head -1)"
  [ -n "$XCODE_APP" ] && export DEVELOPER_DIR="$XCODE_APP/Contents/Developer"
fi
METHOD="${1:-app-store-connect}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
OUT=build

echo "▸ Unit tests (simulator)"
xcodebuild test -project Ravan.xcodeproj -scheme Ravan \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet

echo "▸ Archive (build $BUILD_NUMBER)"
xcodebuild archive -project Ravan.xcodeproj -scheme Ravan -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/Ravan.xcarchive" \
  -allowProvisioningUpdates CURRENT_PROJECT_VERSION="$BUILD_NUMBER" -quiet

echo "▸ Export ($METHOD)"
xcodebuild -exportArchive -archivePath "$OUT/Ravan.xcarchive" \
  -exportOptionsPlist "scripts/ExportOptions-$METHOD.plist" \
  -exportPath "$OUT/ipa" -allowProvisioningUpdates -quiet

echo "IPA: $OUT/ipa/Ravan.ipa"
