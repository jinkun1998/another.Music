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

ICONSET="$DIR/build/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for sz in 16 32 128 256; do
    sips -z $sz $sz Resources/icon.png --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
    sips -z $((sz*2)) $((sz*2)) Resources/icon.png --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null
done
sips -z 512 512 Resources/icon.png --out "$ICONSET/icon_512x512.png" >/dev/null
cp Resources/icon.png "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

cat << 'PLIST' > "$APP/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>anotherMusic</string>
    <key>CFBundleIdentifier</key>
    <string>com.jinkun1998.anothermusic</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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

if [ "$1" == "install" ]; then
    pkill -x anotherMusic || true
    rm -rf /Applications/anotherMusic.app
    cp -R "$APP" /Applications/
    echo "==> Installed /Applications/anotherMusic.app"
    open /Applications/anotherMusic.app
fi

if [ "$1" == "dmg" ]; then
    STAGE="$DIR/build/dmg"
    rm -rf "$STAGE" "$DIR/build/anotherMusic.dmg"; mkdir -p "$STAGE"
    cp -R "$APP" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname anotherMusic -srcfolder "$STAGE" -ov -format UDZO "$DIR/build/anotherMusic.dmg" >/dev/null
    rm -rf "$STAGE"
    echo "==> DMG: $DIR/build/anotherMusic.dmg"
fi

if [ "$1" == "run" ]; then
    echo "==> Launching anotherMusic.app..."
    open "$APP"
fi
