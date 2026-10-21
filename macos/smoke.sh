#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
/usr/bin/xcrun swiftc -framework AppKit "$HERE/Tests/SnapshotCheck.swift" -o "$HERE/.build/SnapshotCheck"
for LABEL in 5.1s 8.1s; do
    APP="$HERE/dist/Codex-Welcome-macOS/Codex ($LABEL).app"
    /usr/bin/codesign --verify --strict "$APP"
    "$APP/Contents/MacOS/CodexWelcome" --diagnose
    if [[ "$LABEL" == 5.1s ]]; then TEST_NAME="Alex+Sun"; else TEST_NAME="小明"; fi
    # These runs verify custom names, never launch Codex or ask for Accessibility permission.
    /usr/bin/perl -e 'alarm 40; exec @ARGV or die $!;' "$APP/Contents/MacOS/CodexWelcome" --self-test "--welcome-name=$TEST_NAME" "--startup-snapshot=$HERE/.build/startup-$LABEL.png" "--native-startup-snapshot=$HERE/.build/startup-native-$LABEL.png"
    "$HERE/.build/SnapshotCheck" "$HERE/.build/startup-$LABEL.png" --handoff
    "$HERE/.build/SnapshotCheck" "$HERE/.build/startup-native-$LABEL.png"
done
