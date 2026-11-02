#!/bin/bash
# Builds "build/Flo Tools.app" as a universal binary and signs it.
# Accessibility and Automation permissions are tied to the signature, so sign with the same identity every time.
# Override the identity with FLO_SIGN_IDENTITY, for example "Developer ID Application: ...".
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --arch x86_64 --product FloTools
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/FloTools"

APP="build/Flo Tools.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/FloTools"
cp Resources/Info.plist "$APP/Contents/Info.plist"

IDENTITY="${FLO_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')}"
if [ -z "$IDENTITY" ]; then
    echo "No signing identity found; signing ad hoc. Permissions will reset on every build." >&2
    IDENTITY="-"
fi
codesign --force --options runtime --timestamp=none --entitlements Resources/FloTools.entitlements --sign "$IDENTITY" "$APP"
codesign --verify --strict "$APP"
echo "Built $APP (signed by $IDENTITY)"
