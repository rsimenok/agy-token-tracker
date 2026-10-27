#!/bin/bash
set -e

# Script to build standalone AGYTokenTracker.app for macOS

APP_NAME="AGYTokenTracker"
BUNDLE_DIR="build/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🔨 Building release binary with Swift PM..."
swift build -c release

echo "📦 Creating macOS App Bundle at ${BUNDLE_DIR}..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Copy binary
cp ".build/release/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

# Create Info.plist
cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.antigravity.AGYTokenTracker</string>
    <key>CFBundleName</key>
    <string>AGY Token Tracker</string>
    <key>CFBundleDisplayName</key>
    <string>AGY Token Tracker</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.1</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Create PkgInfo
echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

echo "✅ App bundle created successfully at ${BUNDLE_DIR}!"

echo "📀 Creating DMG installer at build/${APP_NAME}.dmg..."
DMG_TEMP_DIR="build/dmg_temp"
rm -rf "${DMG_TEMP_DIR}" "build/${APP_NAME}.dmg"
mkdir -p "${DMG_TEMP_DIR}"
cp -r "${BUNDLE_DIR}" "${DMG_TEMP_DIR}/"
ln -s /Applications "${DMG_TEMP_DIR}/Applications"
hdiutil create -volname "AGY Token Tracker" -srcfolder "${DMG_TEMP_DIR}" -ov -format UDZO "build/${APP_NAME}.dmg"
rm -rf "${DMG_TEMP_DIR}"

echo "🗜️ Creating ZIP archives..."
(cd build && rm -f "${APP_NAME}.zip" "${APP_NAME}-v1.0.1.zip" "${APP_NAME}.app.zip" && zip -rq "${APP_NAME}.zip" "${APP_NAME}.app" && cp "${APP_NAME}.zip" "${APP_NAME}-v1.0.1.zip" && cp "${APP_NAME}.zip" "${APP_NAME}.app.zip")

echo "🎉 All release artifacts created in build/:"
ls -lh build/*.dmg build/*.zip
echo "👉 You can run it now with: open ${BUNDLE_DIR}"
echo "👉 Or copy to Applications: cp -r ${BUNDLE_DIR} /Applications/"
