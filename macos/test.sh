#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HERE/.build"
/usr/bin/xcrun swiftc "$HERE/Sources/Geometry.swift" "$HERE/Sources/Preferences.swift" "$HERE/Tests/main.swift" -o "$HERE/.build/GeometryTests"
"$HERE/.build/GeometryTests"
/usr/bin/xcrun swiftc -swift-version 5 -framework AppKit -framework AVFoundation -framework ApplicationServices \
    "$HERE/Sources/Geometry.swift" "$HERE/Sources/RevealView.swift" "$HERE/Sources/DesktopPreparation.swift" \
    "$HERE/Tests/RendererCheck.swift" -o "$HERE/.build/RendererCheck"
"$HERE/.build/RendererCheck" "$HERE/Resources"
/bin/bash -n "$HERE/build.sh" "$HERE/Install.command" "$HERE/Uninstall.command" "$HERE/smoke.sh"
