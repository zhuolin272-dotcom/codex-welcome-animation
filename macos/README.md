# Codex Welcome · macOS

原生 Mac 启动器，包含 **5.1 秒**和 **8.1 秒**两版开场。欢迎词收拢消失后，以约 **1.1 秒**的果冻展开显露真实 Codex 窗口。使用 AppKit、WKWebView 和 Core Graphics，不依赖 Edge、Chrome、Node.js、Python 或本地预览服务器。

## 系统与兼容性

- 部署目标为 **macOS 14 及之后版本**，使用公开系统 API；最新 macOS 27 是兼容目标。
- Universal 构建包含 Apple Silicon `arm64` 和 Intel `x86_64`；你的机器还必须能运行已安装的 Codex 桌面版。macOS 27 本身仅支持 Apple Silicon，参见 [Apple 兼容机型说明](https://support.apple.com/en-us/127255)。
- 构建工作流记录实际 macOS、Xcode 和 Swift 版本，并测试原生 WebKit 中的两种速度。`macos-latest` 或 Xcode 标签不自动等于最新 macOS 实机测试，具体以 Actions 日志为准。

## 安装和使用

1. 从仓库 [Releases](https://github.com/zhuolin272-dotcom/codex-welcome-animation/releases) 下载 **macOS 安装包**，解压。
2. 可以直接将 `Codex (5.1s).app`、`Codex (8.1s).app` 和 `Codex Settings.app` 拖到你的“应用程序”文件夹；也可双击 `Install.command` 安装到 `~/Applications` 并创建桌面入口。
3. 先打开 **Codex Settings.app** 设置欢迎名字，保存后两种速度同时生效。支持 1–20 个字符；英文字母连笔书写，中文使用系统字体平滑显字。
4. 以后双击 **Codex (5.1s)** 即可，不需要打开终端。动画中按 **Esc** 可跳过。
5. 默认查找 `/Applications/Codex.app` 和 `~/Applications/Codex.app`；找不到时会让你选择 Codex 桌面应用，并保存路径。

图标沿用透明背景、白色 OpenAI Logo，适配 Retina 分辨率。

启动时会先在后台准备蓝色云雾首帧，首帧完成后才显示窗口，并等待 WebKit 提交画面后从时间线零点播放。启动器关闭了系统默认的窗口出现动画，以避免加载黑底和窗口缩放闪烁。此预备帧仅来自启动器自身动画，不读取桌面或 Codex 窗口，也不需要屏幕录制权限。

## 首次打开：Apple 无法验证此应用

安装包使用 **ad-hoc 本地签名，尚未完成 Apple Developer ID 签名和公证**。从网络下载后首次打开，可能遇到：

- **“Codex (5.1s)” Not Opened**。
- **Apple could not verify…**，或“Apple 无法验证此 App 是否包含恶意软件”。
- 对话框只有 **Move to Trash（移到废纸篓）** 和 **Done（完成）**。

此提示发生在应用启动之前。原生编译、签名结构校验、动画播放测试通过，不能替代 Apple 公证，也不代表已通过首次下载时的安全检查。

如果你确认安装包来自本仓库的 [Releases](https://github.com/zhuolin272-dotcom/codex-welcome-animation/releases) 且未遭篡改，可参照 [Apple 官方打开流程](https://support.apple.com/zh-cn/102445)：

1. 点击 **Done（完成）**，关闭当前提示。
2. 打开 **系统设置 → 隐私与安全性**，向下滚动至 **安全性**。
3. 找到刚被阻止的应用，点击 **仍要打开（Open Anyway）**。
4. 完成系统要求的身份验证，在再次出现的提示中点击 **打开**。

系统会保存该应用的打开许可。**5.1s、8.1s 和 Codex Settings 是三个独立应用，首次使用时可能需要分别确认。** 此操作不需要关闭整个系统的安全检查；由组织管理的 Mac 可能限制这些设置。

打开许可和“辅助功能”授权是两个独立步骤：后者只在需要自动最大化 Codex 时使用，详见「最大化与权限」。也可以在自己的 Mac 上按本文说明从源码构建。重新签名或更新后，辅助功能权限可能需要重新确认。

## 自定义名字与更新

随时打开 **Codex Settings.app** 修改名字。设置保存在 `~/Library/Application Support/CodexWelcome/config.json` 的 `WelcomeName` 字段，两种速度共用，重装/更新会保留。修改名字不触碰签名后的 `.app`，不需要开发工具。保存时会保留已选择的 `CodexPath`。

名字自动居中，长名字会等比缩小；拉丁字母、数字和字体包含的标点使用离线打包的真实笔画。中文或其他未包含的字符使用系统字体逐字平滑显现，欢迎词和转场的整体时长保持一致。

网页预览底部的「名字」只保存网页预览设置，桌面版本请用本节原生设置入口。

## 最大化与权限

要把另一个应用的窗口自动最大化，macOS 需要 **辅助功能**权限：

**系统设置 → 隐私与安全性 → 辅助功能 → 启用相应的 Codex 欢迎启动器。**

只用于还原、调整 Codex 窗口，保留菜单栏、Dock 和窗口按钮；不会进入单独的全屏桌面。两版是独立应用，第一次使用另一版时可能也需要授权。不需要屏幕录制权限，交接过程不截取、保存或上传屏幕截图。

如果暂时不授权，可在提示中选择“保留窗口大小继续”；动画和打开 Codex 仍可使用，窗口保持原来的大小。

## 从源码构建

在 Mac 上安装 Apple Command Line Tools 或 Xcode。缺少工具时可手动执行 `xcode-select --install`。在仓库根目录运行：

```sh
bash macos/test.sh
bash macos/build.sh
bash macos/smoke.sh
```

生成文件位于 `macos/dist/Codex-Welcome-macOS/`，可分发 ZIP 位于 `macos/dist/Codex-Welcome-macOS.zip`。`macos/smoke.sh` 会完整播放两个版本，检查原生 OpenAI 星尘通道先播放、WebKit 在屏幕外准备，中心光点长成蓝球后接入 Logo，并对原生/网页首帧图像分别检查原生中央小球、网页不可见交接点和两种外观的四角及透明度；不启动 Codex，也不请求辅助功能权限。

默认构建 Universal；只需 Apple Silicon 时：

```sh
CW_ARCHS=arm64 bash macos/build.sh
```

原生诊断：

```sh
"$HOME/Applications/Codex (5.1s).app/Contents/MacOS/CodexWelcome" --diagnose
```

Windows 环境只能检查共享网页与源码结构，不能编译 AppKit/WebKit，也不能据此宣称通过 Mac 实机测试。

## 日志、卸载和故障

- 日志：`~/Library/Logs/CodexWelcome/fast.log`、`full.log`。
- 配置：`~/Library/Application Support/CodexWelcome/config.json`，其中 `CodexPath` 可指定桌面 `.app` 路径。
- 若自动最大化停住，确认辅助功能权限、Codex 是否有阻塞对话框，以及是否正在切换系统全屏空间。
- `Uninstall.command` 只移除本项目创建的桌面链接。随后可用 Finder 将 `~/Applications` 内的两版欢迎应用与 `Codex Settings.app` 移到废纸篓；不会删除真正的 Codex。

## 设计与分发

动画资源随 `.app` 离线打包。WKWebView 使用临时数据存储，并只允许导航到包内动画文件；原生消息桥只接受主文档的 READY、收拢和完成消息。不会读取个人 Safari/Chrome 配置。

本项目原始代码使用 MIT 许可，Logo、GSAP 与字体的第三方说明见包内 `NOTICE.md` 与 `Sacramento-OFL.txt`。本项目并非 OpenAI 官方启动器。

推荐入口后续节奏为 2×，完整版为 1.15×，沿用 5.1s / 8.1s 入口名。v1.6.0 使用约 1.6 秒的 OpenAI 粒子通道，接约 0.42 秒的中心光点长大。Codex Settings.app 中可选择“跟随系统 / 浅色 / 深色”，默认跟随系统；设置保存在应用外部 `config.json` 的 `Theme` 字段。深浅色覆盖通道、Logo、欢迎词和最后的果冻展开。

`macos/smoke.sh` 分别播放两种速度和深浅两种主题，检查原生蓝球与网页交接点的背景一致。共享粒子帧为本项目生成的 OpenAI 星尘图形，不包含用户提供的参考视频。
