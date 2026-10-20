#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HERE/.build"
/usr/bin/xcrun swiftc "$HERE/Sources/Geometry.swift" "$HERE/Sources/Preferences.swift" "$HERE/Tests/main.swift" -o "$HERE/.build/GeometryTests"
"$HERE/.build/GeometryTests"
/bin/bash -n "$HERE/build.sh" "$HERE/Install.command" "$HERE/Uninstall.command" "$HERE/smoke.sh"
