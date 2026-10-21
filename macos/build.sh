#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
if [[ "$(uname -s)" != Darwin ]]; then echo 'Build this target on macOS with Apple Command Line Tools or Xcode.' >&2; exit 1; fi
if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then echo 'Install Apple Command Line Tools first: xcode-select --install' >&2; exit 1; fi
BUILD="$HERE/.build"
PACKAGE="$HERE/dist/Codex-Welcome-macOS"
mkdir -p "$BUILD" "$PACKAGE"
SDK="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
ARCHS="${CW_ARCHS:-arm64 x86_64}"
BINARIES=()
for ARCH in $ARCHS; do
    case "$ARCH" in arm64|x86_64) ;; *) echo "Unsupported architecture: $ARCH" >&2; exit 1;; esac
    BINARY="$BUILD/CodexWelcome-$ARCH"
    /usr/bin/xcrun swiftc -swift-version 5 -O -sdk "$SDK" -target "$ARCH-apple-macosx14.0" \
        -framework AppKit -framework WebKit -framework ApplicationServices -framework QuartzCore \
        "$HERE/Sources/Geometry.swift" "$HERE/Sources/Preferences.swift" "$HERE/Sources/main.swift" -o "$BINARY"
    BINARIES+=("$BINARY")
done
/usr/bin/lipo -create "${BINARIES[@]}" -output "$BUILD/CodexWelcome"

ICONSET="$BUILD/OpenAI.iconset"
mkdir -p "$ICONSET"
ICON="$ROOT/assets/openai-transparent-1024.png"
[[ -f "$ICON" ]] || ICON="$ROOT/assets/openai-transparent.png"
for SIZE in 16 32 128 256 512; do
    /usr/bin/sips -z "$SIZE" "$SIZE" "$ICON" --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE*2))
    /usr/bin/sips -z "$DOUBLE" "$DOUBLE" "$ICON" --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$ICONSET" -o "$BUILD/OpenAI.icns"

for MODE in fast full settings; do
    case "$MODE" in fast) NAME='Codex (5.1s)';; full) NAME='Codex (8.1s)';; settings) NAME='Codex Settings';; esac
    APP="$PACKAGE/$NAME.app"
    if [[ -e "$APP" ]]; then
        MANAGED="$(/usr/libexec/PlistBuddy -c 'Print :CWManaged' "$APP/Contents/Info.plist" 2>/dev/null || true)"
        [[ "$MANAGED" == true ]] || { echo "Refusing to overwrite an unrelated app: $APP" >&2; exit 1; }
    fi
    mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/docs/vendor"
    cp "$BUILD/CodexWelcome" "$APP/Contents/MacOS/CodexWelcome"
    chmod 755 "$APP/Contents/MacOS/CodexWelcome"
    cp "$BUILD/OpenAI.icns" "$APP/Contents/Resources/OpenAI.icns"
    if [[ "$MODE" != settings ]]; then
    cp "$ROOT/docs"/tunnel-*-??.png "$APP/Contents/Resources/docs/"
    cp "$ROOT/assets/orb-motion.png" "$APP/Contents/Resources/orb-motion.png"
    cp "$ROOT/docs/animation.html" "$ROOT/docs/orb-cloud.png" "$ROOT/docs/glyphs.js" "$ROOT/docs/personalize.js" "$APP/Contents/Resources/docs/"
    cp "$ROOT/docs/vendor/gsap.min.js" "$APP/Contents/Resources/docs/vendor/gsap.min.js"
    fi
    cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CodexWelcome</string>
<key>CFBundleIdentifier</key><string>io.github.zhuolin272-dotcom.codex-welcome.$MODE</string>
<key>CFBundleName</key><string>$NAME</string>
<key>CFBundleDisplayName</key><string>$NAME</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.6.0</string>
<key>CFBundleVersion</key><string>160</string>
<key>CFBundleIconFile</key><string>OpenAI</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>CWManaged</key><true/>
<key>CWVariant</key><string>$MODE</string>
</dict></plist>
PLIST
    /usr/bin/plutil -lint "$APP/Contents/Info.plist"
    /usr/bin/codesign --force --sign - --timestamp=none "$APP"
    /usr/bin/codesign --verify --strict --verbose=2 "$APP"
done
cp "$HERE/Install.command" "$HERE/Uninstall.command" "$HERE/README.md" "$PACKAGE/"
cp "$ROOT/LICENSE" "$ROOT/NOTICE.md" "$PACKAGE/"
cp "$ROOT/assets/fonts/OFL.txt" "$PACKAGE/Sacramento-OFL.txt"
chmod 755 "$PACKAGE/Install.command" "$PACKAGE/Uninstall.command"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$PACKAGE" "$HERE/dist/Codex-Welcome-macOS.zip"
/usr/bin/sw_vers
/usr/bin/lipo -archs "$BUILD/CodexWelcome"
echo "Built: $HERE/dist/Codex-Welcome-macOS.zip"
