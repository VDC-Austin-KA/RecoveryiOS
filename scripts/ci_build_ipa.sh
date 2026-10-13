#!/usr/bin/env bash
# Unsigned Release device build packaged as build/RecoveryiOS-unsigned.ipa (sideload with Sideloadly/AltStore).
set -euo pipefail
cd "$(dirname "$0")/.."
FORMAT=cat; command -v xcbeautify >/dev/null && FORMAT=xcbeautify
mkdir -p build
xcodebuild archive \
  -project RecoveryiOS.xcodeproj \
  -scheme RecoveryiOS \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/RecoveryiOS.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  | $FORMAT
cd build
rm -rf Payload RecoveryiOS-unsigned.ipa
mkdir Payload
cp -R RecoveryiOS.xcarchive/Products/Applications/RecoveryiOS.app Payload/
zip -qry RecoveryiOS-unsigned.ipa Payload
rm -rf Payload
echo "Built $(pwd)/RecoveryiOS-unsigned.ipa"
