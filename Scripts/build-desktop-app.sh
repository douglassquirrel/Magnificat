#!/bin/sh
# Builds Magnificat Desktop and assembles it as a real .app bundle.
#
# SwiftPM produces a raw executable, not an app bundle. DESKTOP-SPEC.md §1
# requires "a proper .app bundle with a distinct name, so it resolves cleanly
# in the permission list" — a bare Mach-O binary shows up in System Settings'
# permission lists (Accessibility, Automation) as an unhelpful raw path, and
# won't get its own Dock icon or identity. This script closes that gap.
#
# Usage: Scripts/build-desktop-app.sh
# Produces: .build/MagnificatDesktop.app

set -eu

cd "$(dirname "$0")/.."

APP_NAME="Magnificat Desktop"
BUNDLE_ID="org.magnificat.desktop"
EXECUTABLE_NAME="MagnificatDesktop"
APP_DIR=".build/${APP_NAME}.app"

echo "Building ${EXECUTABLE_NAME} (release)…"
swift build -c release --product "${EXECUTABLE_NAME}"

BIN_PATH="$(swift build -c release --show-bin-path)/${EXECUTABLE_NAME}"
if [ ! -x "${BIN_PATH}" ]; then
    echo "error: expected binary not found at ${BIN_PATH}" >&2
    exit 1
fi

echo "Assembling ${APP_DIR}…"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}"
chmod +x "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

# Ad-hoc self-sign only — for launch hygiene and a stable code identity across
# rebuilds (so a once-granted Accessibility/Automation permission survives a
# rebuild). This is NOT the real signing/notarization pipeline, which
# DESKTOP-SPEC.md §9 explicitly puts out of scope for this iteration.
if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "${APP_DIR}" 2>&1 | grep -v '^$' || true
fi

echo "Built: ${APP_DIR}"
echo "Run with: open \"${APP_DIR}\""
