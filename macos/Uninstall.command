#!/bin/bash
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then echo 'This script is for macOS.' >&2; exit 1; fi
for APP in 'Codex (5.1s).app' 'Codex (8.1s).app' 'Codex Settings.app'; do
    TARGET="$HOME/Applications/$APP"
    LINK="$HOME/Desktop/$APP"
    if [[ -L "$LINK" && "$(readlink "$LINK")" == "$TARGET" ]]; then rm -- "$LINK"; fi
done
echo '已移除本项目创建的桌面入口。应用和配置已保留。'
echo '可在 Finder 中将 ~/Applications 内的 Codex 欢迎应用和 Codex Settings移到废纸篓。'
echo '不会卸载 Codex。'
read -r -p '按回车关闭…' _
