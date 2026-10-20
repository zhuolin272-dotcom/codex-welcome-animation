#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
for LABEL in 5.1s 8.1s; do
    APP="$HERE/dist/Codex-Welcome-macOS/Codex ($LABEL).app"
    /usr/bin/codesign --verify --strict "$APP"
    "$APP/Contents/MacOS/CodexWelcome" --diagnose
    # These runs never launch Codex or ask for Accessibility permission.
    /usr/bin/perl -e 'alarm 40; exec @ARGV or die $!;' "$APP/Contents/MacOS/CodexWelcome" --self-test
done
