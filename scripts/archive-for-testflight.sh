#!/usr/bin/env bash
# Archive ApolloX and upload to App Store Connect (TestFlight).
# Run on a Mac with Xcode 16+ signed into the Apple Developer account.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="ApolloX"
PROJECT="$ROOT/ApolloX.xcodeproj"
ARCHIVE_PATH="$ROOT/build/ApolloX.xcarchive"
EXPORT_PATH="$ROOT/build/export"
EXPORT_OPTIONS="$ROOT/ExportOptions.plist"

cd "$ROOT"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Run this script on macOS with Xcode installed." >&2
  exit 1
fi

echo "==> Clean archive (Release)"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
mkdir -p "$ROOT/build"

xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=2YJ478267N

echo "==> Export and upload to App Store Connect"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

echo "Done. Check App Store Connect → TestFlight for processing status."
echo "Bump CURRENT_PROJECT_VERSION in Xcode before the next upload."
