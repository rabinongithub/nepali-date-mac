
#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Nepali Date.app"
DMG="$ROOT/Nepali-Date.dmg"
ICON="$ROOT/Resources/Nepali-Date-AppIcon.png"
ICONSET="$BUILD/AppIcon.iconset"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD"

# Build the app executable
swiftc -O -parse-as-library "$ROOT/Sources/NepaliMenuBar.swift" \
  -framework SwiftUI \
  -framework AppKit \
  -framework ServiceManagement \
  -o "$APP/Contents/MacOS/NepaliMenuBar"

# Include the Nepali calendar data
cp "$ROOT/Resources/calendar.csv" \
  "$APP/Contents/Resources/calendar.csv"

# Create the macOS app icon
if [[ ! -f "$ICON" ]]; then
  echo "ERROR: App icon not found: $ICON"
  exit 1
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sips -z 16 16 "$ICON" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET" -o "$BUILD/AppIcon.icns"

cp "$BUILD/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Configure the app bundle
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
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
PLIST

chmod +x "$APP/Contents/MacOS/NepaliMenuBar"

# Create the DMG installer
rm -f "$DMG"
hdiutil create \
  -volname "Nepali Date" \
  -srcfolder "$APP" \
  -ov \
  -format UDZO \
  "$DMG"

echo "Built app: $APP"
echo "Built installer: $DMG"
