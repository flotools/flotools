#!/bin/bash
# Builds "build/Flo Tools.app" as a universal binary and signs it.
# Accessibility and Automation permissions are tied to the signature, so sign with the same identity every time.
# Override the identity with FLO_SIGN_IDENTITY, for example "Developer ID Application: ...". FLO_SIGN_IDENTITY=- signs ad hoc, which resets the permissions on every build, so it must be asked for.
# --release is for a build to publish: it raises the build number (CFBundleVersion) by one and commits it before building. Sparkle compares only that number, and each published build needs a new one; test builds keep it.
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
    "") RELEASE=false ;;
    --release) RELEASE=true ;;
    *) echo "Usage: $0 [--release]" >&2; exit 2 ;;
esac

IDENTITY="${FLO_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')}"
if [ -z "$IDENTITY" ]; then
    echo "No \"Apple Development\" signing identity found. Set FLO_SIGN_IDENTITY, or FLO_SIGN_IDENTITY=- to sign ad hoc." >&2
    exit 1
fi

if $RELEASE; then
    case "$IDENTITY" in
        "Developer ID Application"*) ;;
        *) echo "--release needs FLO_SIGN_IDENTITY set to a Developer ID Application identity, not \"$IDENTITY\"." >&2; exit 1 ;;
    esac
    # A published build must match a commit, so its build number commit holds only the number.
    if ! git diff --quiet HEAD --; then
        echo "--release needs no uncommitted changes to tracked files." >&2
        exit 1
    fi
    PLIST=Resources/Info.plist
    BUILD=$(( $(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST") + 1 ))
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"
    git commit -q -m "Raise the build number to $BUILD" -- "$PLIST"
    echo "Build number $BUILD committed ($(git rev-parse --short HEAD))"
fi

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

# Inside out, as Sparkle's documentation says: its helpers, then the framework, then the app. The Downloader keeps its own entitlements.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
# Notarization needs a secure timestamp; development builds skip the round trip to Apple's server.
case "$IDENTITY" in
    "Developer ID Application"*) TIMESTAMP=--timestamp ;;
    *) TIMESTAMP=--timestamp=none ;;
esac
sign() { codesign --force --options runtime "$TIMESTAMP" --sign "$IDENTITY" "$@"; }
sign "$SPARKLE/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
sign "$SPARKLE/Autoupdate"
sign "$SPARKLE/Updater.app"
sign "$APP/Contents/Frameworks/Sparkle.framework"
sign --entitlements Resources/FloTools.entitlements "$APP"
codesign --verify --strict "$APP"
echo "Built $APP (signed by $IDENTITY)"
