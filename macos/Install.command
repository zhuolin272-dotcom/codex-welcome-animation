#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
trap 'STATUS=$?; if [[ $STATUS -ne 0 ]]; then echo "安装未完成，请查看上方错误。"; read -r -p "按回车关闭…" _; fi' EXIT
if [[ "$(uname -s)" != Darwin ]]; then echo 'This installer is for macOS.' >&2; exit 1; fi
SOURCE="$HERE"
if [[ ! -d "$SOURCE/Codex (5.1s).app" ]]; then
    if [[ -f "$HERE/build.sh" ]]; then /bin/bash "$HERE/build.sh"; SOURCE="$HERE/dist/Codex-Welcome-macOS"; else echo '找不到应用。请解压完整的 macOS 安装包。' >&2; exit 1; fi
fi
DESTINATION="$HOME/Applications"
mkdir -p "$DESTINATION"
for APP in 'Codex (5.1s).app' 'Codex Settings.app'; do
    TARGET="$DESTINATION/$APP"
    if [[ -e "$TARGET" ]]; then
        MANAGED="$(/usr/libexec/PlistBuddy -c 'Print :CWManaged' "$TARGET/Contents/Info.plist" 2>/dev/null || true)"
        [[ "$MANAGED" == true ]] || { echo "不会覆盖其他应用：$TARGET" >&2; exit 1; }
    fi
    /usr/bin/ditto "$SOURCE/$APP" "$TARGET"
    /usr/bin/codesign --verify --strict "$TARGET"
    LINK="$HOME/Desktop/$APP"
    if [[ -L "$LINK" && "$(readlink "$LINK")" == "$TARGET" ]]; then
        :
    elif [[ ! -e "$LINK" && ! -L "$LINK" ]]; then
        if ! ln -s "$TARGET" "$LINK"; then echo "桌面入口未创建；仍可从 $TARGET 启动。"; fi
    else
        echo "保留现有桌面同名项目：$LINK"
    fi
done
# Retire only our own old app/link in this installer's explicit destination.
LEGACY="$DESTINATION/Codex (8.1s).app"
LEGACY_LINK="$HOME/Desktop/Codex (8.1s).app"
if [[ -d "$LEGACY" && ! -L "$LEGACY" ]]; then
    MANAGED="$(/usr/libexec/PlistBuddy -c 'Print :CWManaged' "$LEGACY/Contents/Info.plist" 2>/dev/null || true)"
    if [[ "$MANAGED" == true && "$LEGACY" == "$HOME/Applications/Codex (8.1s).app" ]]; then
        if [[ -L "$LEGACY_LINK" && "$(readlink "$LEGACY_LINK")" == "$LEGACY" ]]; then rm -- "$LEGACY_LINK"; fi
        rm -rf -- "$LEGACY"
    fi
fi
echo '已安装 Codex (5.1s) 及 Codex Settings.app。先打开 Codex Settings 修改欢迎名字。'
echo '请双击 5.1s 版启动。首次自动最大化需要在系统设置中允许辅助功能。'
read -r -p '按回车关闭…' _
