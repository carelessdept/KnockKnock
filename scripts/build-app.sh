#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Reson"
BIN_NAME="KnockKnock"
BUNDLE_ID="com.carelessdept.Reson"
DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Building ${APP_NAME} (Release, macOS 27 Liquid Glass SDK)..."
cd "${ROOT_DIR}"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${BIN_NAME}"

rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

if [ -f "${ROOT_DIR}/assets/AppIcon.icns" ]; then
    cp "${ROOT_DIR}/assets/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi
if [ -f "${ROOT_DIR}/Sources/KnockKnock/Resources/ResonMark.png" ]; then
    cp "${ROOT_DIR}/Sources/KnockKnock/Resources/ResonMark.png" "${RESOURCES_DIR}/ResonMark.png"
fi
if [ -f "${ROOT_DIR}/Sources/KnockKnock/Resources/ResonLockup.png" ]; then
    cp "${ROOT_DIR}/Sources/KnockKnock/Resources/ResonLockup.png" "${RESOURCES_DIR}/ResonLockup.png"
fi

cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>2702</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Reson processes live acoustic transients locally in memory alongside the 200 Hz BMI286 motion sensor to detect physical knocks and finger snaps without recording or storing audio.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Reson uses AppleEvents to execute user-configured media and workflow automations.</string>
</dict>
</plist>
EOF

codesign --force --deep --sign - "${APP_BUNDLE}" >/dev/null 2>&1 || true

echo "==> Packaged native macOS 27 app bundle at: ${APP_BUNDLE}"
