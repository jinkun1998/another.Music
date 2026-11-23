#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

GRADLE_FILE="$DIR/../app/build.gradle.kts"
ANDROID_VERSION=$(grep -oE 'versionName = "[^"]+' "$GRADLE_FILE" | cut -d'"' -f2 | awk '{print $1}')
ANDROID_BASE_VERSION=$(echo "$ANDROID_VERSION" | sed -E 's/-.*//')
ANDROID_BUILD=$(grep -oE 'versionCode = [0-9]+' "$GRADLE_FILE" | awk '{print $3}')
RELEASE_CHANNEL="${RELEASE_CHANNEL-}"
if [ -n "$RELEASE_CHANNEL" ]; then
    APP_VERSION="${APP_VERSION:-${ANDROID_BASE_VERSION}-${RELEASE_CHANNEL}}"
else
    APP_VERSION="${APP_VERSION:-${ANDROID_BASE_VERSION}}"
fi
APP_BUILD="${APP_BUILD:-${ANDROID_BUILD:-1}}"
echo "==> Target Version: ${APP_VERSION} (build ${APP_BUILD})"

CONFIG="release"
CONFIG_ARG="-c release"
CONFIG_DIR="Release"
if [ "$1" == "debug" ] || [ "$2" == "debug" ]; then
    CONFIG="debug"
    CONFIG_ARG=""
    CONFIG_DIR="Debug"
fi

echo "==> Building native macOS binary (${CONFIG})..."
swift build $CONFIG_ARG

BIN="$DIR/.build/out/Products/${CONFIG_DIR}/anotherMusic"
APP="$DIR/build/anotherMusic.app"

echo "==> Creating macOS application bundle: $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp Resources/*.wav "$APP/Contents/Resources/" 2>/dev/null || true
cp Resources/*.png "$APP/Contents/Resources/" 2>/dev/null || true

cp "$BIN" "$APP/Contents/MacOS/anotherMusic"
chmod +x "$APP/Contents/MacOS/anotherMusic"

# Embed Sparkle.framework
mkdir -p "$APP/Contents/Frameworks"
SPARKLE_FW="$DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [ ! -d "$SPARKLE_FW" ]; then
    SPARKLE_FW=$(find "$DIR/.build" -name "Sparkle.framework" | head -n 1)
fi
if [ -d "$SPARKLE_FW" ]; then
    echo "==> Embedding Sparkle.framework"
    cp -R "$SPARKLE_FW" "$APP/Contents/Frameworks/"
fi
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/anotherMusic" 2>/dev/null || true

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

cat << PLIST > "$APP/Contents/Info.plist"
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
    <string>anotherMusic</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_BUILD}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.jinkun1998.anothermusic</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>anothermusic</string>
            </array>
        </dict>
    </array>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/jinkun1998/another.Music/macos-native/updater/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>FqZ1FB+qUIACSl4kcOPplkb3Pr4Ri7WEOGZX2L127Js=</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
</dict>
</plist>
PLIST

if [ -d "$APP/Contents/Frameworks/Sparkle.framework" ]; then
    codesign --force --options runtime --sign - "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" 2>/dev/null || true
    codesign --force --options runtime --sign - "$APP/Contents/Frameworks/Sparkle.framework" 2>/dev/null || true
fi
codesign --force --deep --sign - "$APP" 2>/dev/null || true

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
    DMG_OUT="$DIR/build/anotherMusic.dmg"
    VERSIONED_DMG="$DIR/build/anotherMusic-${APP_VERSION}-macos.dmg"
    rm -rf "$STAGE" "$DMG_OUT" "$VERSIONED_DMG"; mkdir -p "$STAGE"
    cp -R "$APP" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname "anotherMusic" -srcfolder "$STAGE" -ov -format UDZO "$DMG_OUT" >/dev/null
    cp "$DMG_OUT" "$VERSIONED_DMG"
    rm -rf "$STAGE"
    echo "==> DMG: $DMG_OUT"
    echo "==> Versioned DMG: $VERSIONED_DMG"
fi

if [ "$1" == "run" ] || [ "$2" == "run" ]; then
    echo "==> Launching anotherMusic.app..."
    open "$APP"
fi
