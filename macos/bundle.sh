#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "==> Building native macOS binary (release)..."
swift build -c release

BIN="$DIR/.build/out/Products/Release/anotherMusic"
APP="$DIR/build/anotherMusic.app"

echo "==> Creating macOS application bundle: $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/anotherMusic"
chmod +x "$APP/Contents/MacOS/anotherMusic"

cat << 'PLIST' > "$APP/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>anotherMusic</string>
    <key>CFBundleIdentifier</key>
    <string>com.jinkun1998.anothermusic</string>
    <key>CFBundleName</key>
    <string>anotherMusic</string>
    <key>CFBundleDisplayName</key>
    <string>another.Music</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST

echo "==> Bundle ready at: $APP"

if [ "$1" == "run" ]; then
    echo "==> Launching anotherMusic.app..."
    open "$APP"
fi
