#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
/usr/bin/xcrun swiftc -framework AppKit "$HERE/Tests/SnapshotCheck.swift" -o "$HERE/.build/SnapshotCheck"
for THEME in light dark; do
for LABEL in 5.1s 8.1s; do
    SUFFIX="$LABEL"; FLAGS=(--light)
    if [[ "$THEME" == dark ]]; then SUFFIX="$LABEL-dark"; FLAGS=(--dark); fi
    APP="$HERE/dist/Codex-Welcome-macOS/Codex ($LABEL).app"
    /usr/bin/codesign --verify --strict "$APP"
    "$APP/Contents/MacOS/CodexWelcome" --diagnose
    if [[ "$LABEL" == 5.1s ]]; then TEST_NAME="Alex+Sun"; else TEST_NAME="小明"; fi
    # These runs verify custom names, never launch Codex or ask for Accessibility permission.
    /usr/bin/perl -e 'alarm 40; exec @ARGV or die $!;' "$APP/Contents/MacOS/CodexWelcome" --self-test "--theme=$THEME" "--welcome-name=$TEST_NAME" "--startup-snapshot=$HERE/.build/startup-$SUFFIX.png" "--native-startup-snapshot=$HERE/.build/startup-native-$SUFFIX.png"
    "$HERE/.build/SnapshotCheck" "$HERE/.build/startup-$SUFFIX.png" --handoff "${FLAGS[@]}"
    "$HERE/.build/SnapshotCheck" "$HERE/.build/startup-native-$SUFFIX.png" "${FLAGS[@]}"
done
done
