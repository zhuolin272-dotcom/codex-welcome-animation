# Codex Welcome Animation

为 Windows 和 macOS Codex 准备的 **5.1s 最终版**个人欢迎动画：星尘组成 OpenAI 标志，镜头穿过粒子通道，中心光点长成流动蓝球，衔接旋转 Logo、弹射与连笔 **welcome 你的名字**，最后以果冻形变显露真实的 Codex 界面。

![蓝色云雾小球预览](assets/orb.png)

支持自定义名字、自动跟随系统深浅色、透明 OpenAI 快捷图标。动画、字体和图像均离线打包，日常使用无需 Node.js、Python 或预览服务器。

## 下载

- [Windows 安装包](https://github.com/zhuolin272-dotcom/codex-welcome-animation/releases/download/v1.8.0/Codex-Welcome-Windows.zip)
- [macOS Apple Silicon 安装包](https://github.com/zhuolin272-dotcom/codex-welcome-animation/releases/download/v1.8.0/Codex-Welcome-macOS-AppleSilicon.zip)：M 系列 Mac。
- [macOS Universal 安装包](https://github.com/zhuolin272-dotcom/codex-welcome-animation/releases/download/v1.8.0/Codex-Welcome-macOS-universal.zip)：包含 Apple Silicon 与 Intel 架构。
- [发布记录、校验值与 Mac 构建环境](https://github.com/zhuolin272-dotcom/codex-welcome-animation/releases/tag/v1.8.0)

## Windows 安装与使用

需要已安装 **Microsoft Edge** 和 **Codex 桌面版**。

1. 下载并解压 Windows 安装包，双击 **Install.cmd**。
2. 桌面和开始菜单生成 **Codex (5.1s)** 与 **Codex Settings**。
3. 打开 **Codex Settings** 设置名字与外观；以后双击 **Codex (5.1s)** 启动。

安装到当前用户“文档”下的 `CodexWelcome`，通常为 `%USERPROFILE%\Documents\CodexWelcome`。安装完成后可移动或删除下载目录。更新保留本机名字、外观和 Codex 路径，并移除属于本项目的旧版入口。

动画结束后，Codex 使用**最大化窗口**，保留标题栏、最小化按钮与任务栏。动画中按 **Esc** 可跳过。快捷方式直接运行无控制台的 `CodexWelcome.exe`，不依赖 VBScript。安装器用系统 .NET Framework 编译入口，无需管理员权限。

启动器优先使用注册的 `OpenAI.Codex` 桌面应用，兼容可执行文件显示为 `ChatGPT.exe` 的 Store 安装，不把 Codex CLI 当成桌面版。已有 Codex 窗口时直接复用，未运行时正常启动。

若无法自动检测，可在解压目录运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -CodexPath "C:\path\to\Codex.exe"
```

`ExecutionPolicy Bypass` 仅作用于该脚本进程。支持 `-InstallRoot` 指定安装位置。不安装时，也可直接双击解压目录中的 **Launch-5.1s.cmd**，此时需保留该目录。

## macOS 安装与验证范围

Mac 使用原生 AppKit / WKWebView 启动器，包内只有 **Codex (5.1s).app** 和 **Codex Settings.app**。不依赖 Edge 或 Chrome。部署目标为 **macOS 14+**，最新 macOS 27 为兼容目标；实际构建系统、Xcode 与 Swift 版本见发布页附带的环境报告。

1. M 系列 Mac 下载 Apple Silicon 包；Intel Mac 下载 Universal 包。
2. 解压后双击 **Install.command**，安装到 `~/Applications` 并创建桌面入口；也可手动将两个应用拖入“应用程序”。
3. 打开 **Codex Settings.app** 设置名字和外观。
4. 双击 **Codex (5.1s).app**。找不到 Codex 时，按提示选择真正的 Codex 桌面 `.app`。

Mac 的原生编译、签名结构检查、WebKit 动画播放及深浅色首帧检查由 GitHub Actions 自动执行。**这些检查不启动真实 Codex，也不替代用户 Mac 上的冷启动、辅助功能权限、最小化恢复与窗口交接验证。** Windows 可用不能直接证明 Mac 实机稳定。

### 首次打开与权限

Mac 包使用 **ad-hoc 本地签名，尚未完成 Apple Developer ID 签名与公证**。首次从网络下载，可能出现“Apple 无法验证此 App”或“Not Opened”。确认来源为本仓库 Releases 后，按照 [Apple 官方说明](https://support.apple.com/zh-cn/102445)，前往 **系统设置 → 隐私与安全性 → 安全性 → 仍要打开**，完成系统确认。设置应用首次打开也可能需要确认，不需要关闭系统安全检查。

自动最大化 Codex 另需 **辅助功能**权限：**系统设置 → 隐私与安全性 → 辅助功能**，允许欢迎启动器。不需要屏幕录制权限；也可选择保留窗口大小继续。更新应用后可能需要重新确认权限。

详细安装、源码构建和日志说明见 [macOS 使用说明](macos/README.md)。

## 自定义名字与外观

在 **Codex Settings** 中设置：

- **名字**：1–20 个字符，自动居中并按宽度缩放。字体包含的拉丁字母、数字和标点使用连笔书写；中文等其他字符使用系统字体平滑显现。
- **外观**：跟随系统 / 浅色 / 深色，默认跟随系统；每次启动重新识别。Windows 读取应用主题，Mac 读取有效 AppKit 外观。

Windows 配置保存在安装目录 `config.json`；Mac 保存在 `~/Library/Application Support/CodexWelcome/config.json`。字段为 `WelcomeName`、`Theme` 和可选 `CodexPath`，更新保留。设置名字不修改已签名的 Mac 应用。

网页预览的“名字”按钮只修改浏览器本地设置，与桌面启动器各自独立。

## 浏览器预览与部署

双击 `docs/index.html` 即可离线预览，也可以使用 Node.js：

```sh
node tools/serve.mjs
```

页面提供重播、主题、名字和全屏控制。网页播放同一段最终版动画，不会启动桌面 Codex；真实界面展开由本机原生启动器完成。

部署到 GitHub Pages：打开仓库 **Settings → Pages**，选择 **Deploy from a branch → main → /docs**，保存后使用 Pages 页面给出的地址。也可把 `docs/` 全部文件上传到其他静态托管服务，保留相对路径。

## 动画与窗口交接

Windows 原生入口先显示粒子通道与蓝球，专用浏览器在屏幕外准备 Logo 与书写画面，完成首帧握手后才显示。Mac 使用 AVPlayerLayer / Core Animation 与 WKWebView 完成同一流程。动画居中并适配分辨率与显示缩放，后续节奏沿用已确认的 5.1s 最终版；Codex 冷启动或系统负载可能延长交接等待。

粒子源为 **1280×800 / 120 fps**，蓝球为 **512×512 / 120 fps**。Windows 使用分段图集；Mac 使用相同帧编码的本地 H.264 帧流，不在启动时解码或轮换巨型图集。实际显示帧率取决于屏幕刷新率和负载。深色底色 `#050609`，浅色 `#f7f6f2`。

Windows 只使用独立、未登录的 Edge 配置，关闭该配置的翻译提示，并采用独占应用模式处理退出全屏引导。不会读取或修改个人浏览器配置。仅在随机 `127.0.0.1` 端口短暂提供本机文件，结束后关闭，不对局域网开放。

欢迎画面向中心收拢，原生遮罩承接底色，再向外展开真实 Codex 窗口。交接不截取、保存或上传用户桌面画面。启动器不发送滚动或编辑快捷键。

## 开发与验证

修改动画使用 `source/animation.template.html`，然后生成网页：

```sh
python tools/build.py
```

`--name` 可设置默认拉丁名字，`--greeting` 可设置默认问候；日常修改名字使用原生设置即可。素材生成脚本位于 `tools/`。

Windows 检查：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\ExistingDesktop.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Appearance.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Personalization.ps1
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\tests\WindowStartup.ps1
```

真实动画窗口检查不启动 Codex；不能据此宣称已验证对话滚动位置或所有应用交接情形。

Mac 构建和播放检查：

```sh
bash macos/test.sh
bash macos/build.sh
bash macos/smoke.sh
```

Windows 上不能编译 AppKit / WebKit。Mac 自动检查记录实际系统环境，并验证 5.1s 动画的深浅色、拉丁名字与中文名字。

## macOS 卡顿修正（v1.8.0）

- 粒子与蓝球使用本地 H.264 / AVPlayerLayer 播放，保留源分辨率与 120 fps，避免巨型 PNG 解码和纹理轮换。
- Codex 辅助功能窗口查询与调整在独立队列执行，每个 AX 对象使用有限超时；不会占用动画主线程。已运行的 Codex 直接复用。
- 最终果冻展开使用 CAGradientLayer 的系统合成动画，避免逐帧重画整屏位图；正常启动不再执行完整 WebKit 截图读回。
- 书写阶段移除没有模糊量时的 SVG 滤镜，原生蓝球交接后不再重复更新隐藏的网页蓝球。
- 自动测试增加慢窗口响应模拟、媒体帧检查、展开透明度检查，以及原生、WebKit、展开各阶段的帧间隔报告。报告提供实际测量值，不把 120 fps 素材等同于所有 Mac 实机的显示帧率。

Mac 更新采用完整应用分阶段替换，避免旧资源留在新包内影响签名校验。用户录屏不包含在源码或发布包中。

## 排错与已知限制

Windows 日志位于安装目录 `logs/launch.log` 和 `logs/bootstrap.log`。Mac 日志位于 `~/Library/Logs/CodexWelcome/fast.log`。等待超时会提示错误。

如果旧快捷方式提示找不到 `Start.vbs`，重新运行安装器以生成当前 EXE 入口。若 Codex 更新后换了路径，先正常打开 Codex，再重新安装或设置桌面应用路径。

部分 Windows Codex 版本在**最小化后恢复**时会丢失对话位置；不播放本项目动画也可触发。[同版本公开记录](https://github.com/openai/codex/issues/55612)。此问题尚无本项目已验证的修复，窗口复用不等于修复滚动位置；未生效的自动滚动补偿已撤回。

## 卸载与许可

Windows 运行安装目录 `Uninstall.ps1`，Mac 运行包内 `Uninstall.command`，移除本项目创建的入口。随后可手动删除欢迎启动器与安装文件，不会卸载真正的 Codex；本机设置默认保留。

自写代码使用 MIT 许可证；第三方素材见 [NOTICE.md](NOTICE.md)。OpenAI 商标属于 OpenAI，本项目没有官方隶属或背书关系。
