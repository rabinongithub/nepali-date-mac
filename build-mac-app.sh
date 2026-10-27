
#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Nepali Date.app"
DMG="$ROOT/Nepali-Date.dmg"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -parse-as-library "$ROOT/Sources/NepaliMenuBar.swift" \
  -framework SwiftUI \
  -framework AppKit \
  -framework ServiceManagement \
  -o "$APP/Contents/MacOS/NepaliMenuBar"

cp "$ROOT/Resources/calendar.csv" "$APP/Contents/Resources/calendar.csv"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>NepaliMenuBar</string>
  <key>CFBundleIdentifier</key><string>np.asn.nepalidate</string>
  <key>CFBundleName</key><string>Nepali Date</string>
  <key>CFBundleDisplayName</key><string>Nepali Date</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
PLIST

chmod +x "$APP/Contents/MacOS/NepaliMenuBar"

hdiutil create \
  -volname "Nepali Date" \
  -srcfolder "$APP" \
  -ov \
  -format UDZO \
  "$DMG"

echo "Built app: $APP"
echo "Built installer: $DMG"
