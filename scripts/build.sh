#!/bin/bash
set -euo pipefail

APP_NAME="ClipboardManager"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "🔨 Building ${APP_NAME}..."
swift build -c release

echo "📦 Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}"
mkdir -p "${RESOURCES}"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS}/"

# Copy Info.plist
cp "Resources/Info.plist" "${CONTENTS}/"

# Copy app icon
cp "Resources/AppIcon.icns" "${RESOURCES}/"

# Copy entitlements and sign
echo "🔏 Signing..."
codesign --force --deep --sign - \
    --entitlements "${APP_NAME}.entitlements" \
    "${APP_BUNDLE}"

echo ""
echo "✅ Built successfully: ${APP_BUNDLE}"
echo ""
echo "To install, run:"
echo "  cp -r ${APP_BUNDLE} /Applications/"
echo ""
echo "To run directly:"
echo "  open ${APP_BUNDLE}"
