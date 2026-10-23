# Codex Welcome 5.1s · macOS

原生 Mac 欢迎启动器，包含 **Codex (5.1s).app** 与 **Codex Settings.app**。OpenAI 星尘通道、中心蓝球、旋转 Logo、个性化书写和果冻展开均离线播放。使用 AppKit、AVFoundation、Core Animation 和 WKWebView，不依赖个人浏览器或预览服务器。

## 兼容与验证范围

部署目标为 macOS 14+。Apple Silicon 包适用于 M 系列 Mac，Universal 包另含 Intel 架构；真正的 Codex 桌面应用也必须支持你的系统。最新 macOS 27 为兼容目标，具体测试系统、Xcode 与 Swift 版本见发布页环境报告。

GitHub Actions 执行原生编译、ad-hoc 签名校验、WebKit 播放、深浅色首帧与图像检查，并覆盖拉丁和中文名字。**自动测试不启动真实 Codex，不验证用户机器的首次授权、冷启动、最小化恢复或窗口交接。** 通过构建和动画测试不等于已完成所有 Mac 实机稳定性测试。

## 安装与使用

1. 从 [Releases](https://github.com/zhuolin272-dotcom/codex-welcome-animation/releases/tag/v1.8.0) 下载适合架构的 Mac 包并解压。
2. 双击 **Install.command** 安装到 `~/Applications` 并创建桌面入口；也可把两个 `.app` 拖入“应用程序”。安装器更新本项目已标记的应用，保留本机设置，清理本项目已退役入口。
3. 打开 **Codex Settings.app** 设置名字和外观。
4. 双击 **Codex (5.1s).app**；动画中按 Esc 可跳过。

默认查找 `/Applications/Codex.app` 与 `~/Applications/Codex.app`。找不到时，按提示选择真正的 Codex 桌面 `.app`，路径会保存在本机。

## 首次打开与权限

应用只有 **ad-hoc 本地签名，未完成 Developer ID 签名和 Apple 公证**。首次下载可能出现“Not Opened”或“Apple 无法验证此 App”。确认来自本仓库后，参照 [Apple 官方流程](https://support.apple.com/zh-cn/102445)：关闭提示，前往 **系统设置 → 隐私与安全性 → 安全性 → 仍要打开**，完成系统确认。欢迎应用和设置应用可能需要分别确认，不需要关闭系统安全检查。

自动恢复、最大化 Codex 需要另行授予 **辅助功能**权限：**系统设置 → 隐私与安全性 → 辅助功能**，启用欢迎启动器。更新应用后可能需重新确认。不需要屏幕录制权限，交接不截取或保存桌面截图。

暂时不授权可选择“保留窗口大小继续”。正常交接保留菜单栏、Dock 和窗口按钮，不创建独立全屏桌面。

## 名字与外观

**Codex Settings.app** 支持 1–20 个字符，名字自动居中缩放。拉丁字母、数字及支持的标点连笔书写；中文等字符使用系统字体平滑显现。外观选择跟随系统 / 浅色 / 深色，默认跟随系统。

配置保存在 `~/Library/Application Support/CodexWelcome/config.json`：`WelcomeName`、`Theme`、可选 `CodexPath`。更新保留，设置不修改已签名的 `.app`。网页名字设置与桌面配置相互独立。

## 从源码构建

在 Mac 上安装 Apple Command Line Tools 或 Xcode，在仓库根目录运行：

```sh
bash macos/test.sh
bash macos/build.sh
bash macos/smoke.sh
```

默认构建 Universal；只构建 Apple Silicon 使用：

```sh
CW_ARCHS=arm64 bash macos/build.sh
```

输出目录为 `macos/dist/Codex-Welcome-macOS/`，ZIP 为 `macos/dist/Codex-Welcome-macOS.zip`。播放检查覆盖最终版的浅色与深色、拉丁和中文名字，不请求辅助功能权限或启动 Codex。

查看原生诊断：

```sh
"$HOME/Applications/Codex (5.1s).app/Contents/MacOS/CodexWelcome" --diagnose
```

## 性能实现与复测

窗口辅助功能请求在后台串行队列处理，且每个 AX 对象有短超时；已运行的 Codex 不再重复发送打开请求。果冻展开使用 GPU 渐变图层动画；正常启动不执行 WebKit 全屏截图读回。更新安装时替换完整已校验应用，避免混入旧版资源。

日志中的 `MOTION native-video-delivery` 记录独立队列收到的新视频帧；`MOTION appkit-startup` 单独记录 WebKit 冷初始化期间的主线程回调。`MOTION appkit-writing`、`MOTION web-writing` 和 `MOTION reveal` 记录后续阶段的回调频率与最大间隔。这些指标用于定位卡顿，并不证明每一帧都由屏幕实际呈现。测试额外模拟慢窗口接口响应，检查不会堵塞动画主线程。`macos/.build/motion-light.json` 与 `motion-dark.json` 是自动测试的无用户内容报告。

开发者需要重新生成 Mac 影片时可运行 `python tools/build_macos_media.py --ffmpeg /path/to/ffmpeg`。它只使用仓库内的 OpenAI 粒子与蓝球帧，不使用用户视频；日常安装不需要 ffmpeg。

## 日志与卸载

日志为 `~/Library/Logs/CodexWelcome/fast.log`。若自动最大化停住，检查辅助功能权限、Codex 阻塞对话框及是否正在切换系统全屏空间。

`Uninstall.command` 仅移除本项目的桌面链接。可再用 Finder 删除 `~/Applications` 中的欢迎应用与设置应用；不会删除真正的 Codex，本机配置保留。

## 素材与分发

粒子源为 1280×800 / 120 fps，蓝球为 512×512 / 120 fps。Mac 使用由本项目帧生成的 H.264 视频和 AVPlayerLayer，不加载 Windows 的巨型图集。影片先预解码，开场仅显示一次，蓝球可流畅循环等待网页就绪。实际帧率受屏幕和负载影响。资源随应用打包；WebKit 使用临时数据存储，只导航到包内文件，不读取个人 Safari / Chrome 配置。

代码使用 MIT 许可证；Logo、字体和 GSAP 的说明见包内 NOTICE.md 与 Sacramento-OFL.txt。本项目不是 OpenAI 官方启动器。
