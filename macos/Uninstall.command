#!/bin/bash
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then echo 'This script is for macOS.' >&2; exit 1; fi
for LABEL in 5.1s 8.1s; do
    TARGET="$HOME/Applications/Codex ($LABEL).app"
    LINK="$HOME/Desktop/Codex ($LABEL).app"
    if [[ -L "$LINK" && "$(readlink "$LINK")" == "$TARGET" ]]; then rm -- "$LINK"; fi
done
echo '已移除本项目创建的桌面入口。应用和配置已保留。'
echo '可在 Finder 中将 ~/Applications 内的两个 Codex 欢迎应用移到废纸篓。'
echo '不会卸载 Codex。'
read -r -p '按回车关闭…' _
