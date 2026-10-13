#!/usr/bin/env bash
# Produces an unsigned .xcarchive so every push proves the Release configuration compiles.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcodebuild archive \
  -project RecoveryiOS.xcodeproj \
  -scheme RecoveryiOS \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/RecoveryiOS.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  | xcpretty
(cd build && zip -qry RecoveryiOS-unsigned.xcarchive.zip RecoveryiOS.xcarchive)
