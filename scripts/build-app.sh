#!/bin/bash
# Builds "build/Flo Tools.app" as a universal binary and signs it.
# Accessibility and Automation permissions are tied to the signature, so sign with the same identity every time.
# Override the identity with FLO_SIGN_IDENTITY, for example "Developer ID Application: ...". FLO_SIGN_IDENTITY=- signs ad hoc, which resets the permissions on every build, so it must be asked for.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --arch x86_64 --product FloTools
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
BIN="$BIN_DIR/FloTools"

APP="build/Flo Tools.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN" "$APP/Contents/MacOS/FloTools"
# SwiftPM links Sparkle by its build folder only; the app loads it from Contents/Frameworks.
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/FloTools"
ditto "$BIN_DIR/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Sounds/*.aiff "$APP/Contents/Resources/"
# The app copies these into ~/Library/Application Support/Flo Tools/Plug-In Views on first launch.
cp -R "reference/Plug-In Views" "$APP/Contents/Resources/"

IDENTITY="${FLO_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')}"
if [ -z "$IDENTITY" ]; then
    echo "No \"Apple Development\" signing identity found. Set FLO_SIGN_IDENTITY, or FLO_SIGN_IDENTITY=- to sign ad hoc." >&2
    exit 1
fi
# Inside out, as Sparkle's documentation says: its helpers, then the framework, then the app. The Downloader keeps its own entitlements.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
sign() { codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$@"; }
sign "$SPARKLE/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
sign "$SPARKLE/Autoupdate"
sign "$SPARKLE/Updater.app"
sign "$APP/Contents/Frameworks/Sparkle.framework"
sign --entitlements Resources/FloTools.entitlements "$APP"
codesign --verify --strict "$APP"
echo "Built $APP (signed by $IDENTITY)"
