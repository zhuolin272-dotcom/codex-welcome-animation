# Codex Welcome Animation

为 Windows 和 macOS Codex 准备的个人欢迎动画：星尘构成 OpenAI 标志，镜头加速穿过粒子通道；中心光点用约 0.42 秒长成流动蓝球，随后衔接旋转 Logo、弹射与连笔 **welcome 你的名字**，最后以果冻形变展开真实的 Codex。支持系统深浅色自动识别，也可以手动固定外观。

![蓝色云雾小球预览](assets/orb.png)

## 两个版本

| 版本 | 速度 | 动画时长 | 欢迎词书写 | 启动入口 |
| --- | --- | --- | --- | --- |
| **5.1 秒 · 推荐（沿用入口名）** | 桌面 / 首页 2× | 桌面 Logo 后约 3.19 秒 | 桌面 1.75 秒 | Windows：`Launch-5.1s.cmd`；Mac：`Codex (5.1s).app` |
| **8.1 秒 · 完整（沿用入口名）** | 桌面 / 首页 1.15× | 桌面 Logo 后约 5.55 秒 | 桌面约 3.04 秒 | Windows：`Launch-8.1s.cmd`；Mac：`Codex (8.1s).app` |

v1.6.0 的粒子通道约 1.6 秒、光点长成球约 0.42 秒，随后快速进入 Logo。推荐版从粒子启动到显露 Codex 约 6.3 秒，完整版约 8.8 秒；后台冷启动可能延长流动蓝球阶段。入口名 5.1s / 8.1s 为兼容保留，不代表从双击开始的精确总耗时。网页首页也包含新的粒子开场。

动画按实际窗口尺寸等比缩放并居中，支持不同分辨率、宽高比例和 Windows 显示缩放。蓝球与旋转 Logo 从中心出现，之后 Logo 按设计向上弹射，为欢迎词留出空间。

## Windows 安装

需要已安装 **Microsoft Edge** 和 **Codex 桌面版**。日常使用不需要 Node.js、Python、npm、管理员权限或运行预览服务器。安装器使用 Windows 自带的 .NET Framework 编译一个无控制台的 `CodexWelcome.exe`；桌面快捷方式直接打开它，再由它运行系统 PowerShell 启动动画，不依赖 VBScript 或 Windows Script Host。

1. 下载 [Windows v1.6.2](https://github.com/zhuolin272-dotcom/codex-welcome-animation/releases/download/v1.6.2/Codex-Welcome-Windows.zip)，或在本仓库点击 **Code → Download ZIP**，解压到普通文件夹。
2. 双击 **`Install.cmd`**。
3. 桌面和开始菜单会出现 **`Codex (5.1s)`**、**`Codex (8.1s)`** 和 **`Codex Settings`** 三个快捷方式。日常使用第一个即可。

两个快捷方式和启动程序使用白色 OpenAI Logo、透明背景的图标，内含 16 至 256 像素的 10 档尺寸。矢量源文件为 `assets/openai-transparent.svg`，可运行 `python tools/build_icon.py` 重新生成 PNG 和 ICO。

安装文件会复制到当前用户的“文档”文件夹下的 `CodexWelcome`，通常为 `%USERPROFILE%\Documents\CodexWelcome`。使用文档目录是为了避免从 MSIX 打包应用运行安装器时，AppData 写入被 Windows 重定向，导致桌面图标找不到同一份文件。之后移动或删除下载目录不会影响快捷方式。更新安装会将有本项目标记的旧快捷方式迁移到新目录；旧安装文件保留。

启动器优先按 Windows 注册的 `OpenAI.Codex` 应用标识启动桌面版，兼容显示名称或可执行文件仍叫 `ChatGPT` 的安装。它不会把 `%LOCALAPPDATA%\OpenAI\Codex\bin` 下的命令行后台程序当成桌面版。

如果自动检测不到 Codex，可在 PowerShell 中进入解压目录，明确指定桌面应用程序位置：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -CodexPath "C:\path\to\Codex.exe"
```

`ExecutionPolicy Bypass` 只用于当前脚本进程，不修改系统执行策略。安装器也支持 `-InstallRoot` 指定其他安装文件夹。

## macOS 安装

Mac 版使用原生 `.app`，两种速度、透明 Logo、果冻收拢与真实界面展开均保留。部署目标为 macOS 14+，兼容目标包括最新 macOS 27；Universal 包含 Apple Silicon 和 Intel 架构。具体构建/测试系统以 GitHub Actions 的实际环境记录为准。

Mac 安装包均包含 5.1 秒和 8.1 秒两个应用：

- **M 系列 Mac / 最新 macOS：**[Apple Silicon 下载](https://github.com/zhuolin272-dotcom/codex-welcome-animation/releases/download/v1.6.0/Codex-Welcome-macOS-AppleSilicon.zip)。
- **Intel Mac / 双架构分发：**[Universal 下载](https://github.com/zhuolin272-dotcom/codex-welcome-animation/releases/download/v1.6.0/Codex-Welcome-macOS-universal.zip)。
- [发布记录与实际构建环境](https://github.com/zhuolin272-dotcom/codex-welcome-animation/releases/tag/v1.6.0)。

下载并解压后，双击 `Install.command`，或直接把两种速度和 `Codex Settings.app` 拖入应用程序文件夹。自动最大化 Codex 需要首次授予辅助功能权限；不需要屏幕录制权限。也可暂时保留窗口大小继续使用。

### Mac 首次打开注意事项

当前 Mac 安装包只有 **ad-hoc 本地签名，尚未进行 Apple Developer ID 签名和公证**。首次从网络下载打开时，可能出现 **“Codex (5.1s)” Not Opened** 或“Apple 无法验证此 App 是否包含恶意软件”的提示；此时应用尚未启动。编译、动画播放及签名结构检查通过，不等于已通过 Apple 公证或首次下载安全验证。

确认安装包来自本仓库 Releases 且未遭篡改后，可按以下步骤打开：

1. 在提示中点击 **Done（完成）**。
2. 打开 **系统设置 → 隐私与安全性**，向下滚动到 **安全性**。
3. 找到被阻止的 `Codex (5.1s)`，点击 **仍要打开（Open Anyway）**。
4. 按系统要求完成身份验证，在再次出现的提示中点击 **打开**。

`Codex Settings.app` 与 `Codex (8.1s).app` 首次打开时可能也需分别确认。系统会保存该应用的打开许可。步骤依据 [Apple 官方说明](https://support.apple.com/zh-cn/102445)；无需关闭整个系统的安全检查。

打开许可与自动最大化需要的“辅助功能”权限是两个独立步骤。完整安装、权限和源码构建说明见 **[macOS 使用说明](macos/README.md)**。

## 自定义欢迎名字

不需要 Python、Node.js 或重新编译。名字保存在本机，5.1s 和 8.1s 共用同一份设置，更新安装会保留。

- **Windows：**安装后打开桌面或开始菜单中的 **Codex Settings**，输入名字并保存。解压目录也可双击 `Settings.cmd`；这会设置该目录的启动入口，已安装版本请用桌面设置入口。
- **macOS：**打开 **Codex Settings.app**，输入名字并保存。安装器会连同两种速度一起安装，并创建桌面入口。
- **网页预览：**点击底部 **名字** 按钮，保存并预览。网页设置保存在当前浏览器，和桌面启动器的设置各自独立。

名字支持 **1–20 个字符**，自动居中并按宽度缩放。Sacramento 字体包含的拉丁字母、数字和标点沿用真实笔画遮罩的连笔动画；中文及字体未包含的字符使用系统字体、平滑逐字显现，不模拟不存在的连笔字形。更换名字不会改变两种速度的整体时长和果冻转场。

本机配置字段为 `WelcomeName`：Windows 位于安装目录 `config.json`，Mac 位于 `~/Library/Application Support/CodexWelcome/config.json`。保存名字会保留 `CodexPath` 等其他配置，不修改已签名的 Mac `.app`。

## Windows 使用方式

- 点击 **Codex (5.1s)**：播放快速欢迎动画，然后进入 Codex。
- 点击 **Codex (8.1s)**：播放完整版，然后进入 Codex。
- 动画中按 **Esc**：跳过动画，进入 Codex。
- 启动时会在动画后方将 Codex **最大化**，欢迎画面收拢后以果冻遮罩向外展开显示 Codex，保留标题栏、最小化/还原按钮与任务栏。如果此前使用了 F11 全屏，启动器会先退出全屏再最大化。
- 不想安装：解压后直接双击相应的 `Launch-*.cmd`，但此时要保留解压目录。
- 也可直接运行下列 PowerShell 命令，参数 `full` 对应完整版：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\launcher\Launch.ps1 -Variant fast
```

Windows 已运行 Codex 时直接复用现有窗口，不再重复发送应用打开请求；未运行时正常启动程序。v1.6.2 为动画专用浏览器加入独占应用模式，用于取消“退出全屏请长按 Esc”的浏览器引导，保持无标题栏和原有离屏预热方式。启动器不发送滚动或编辑快捷键。Mac 当前版本仍为 v1.6.0。启动器使用独立的 Edge 配置目录播放全屏动画，并在结束后只关闭自己的动画窗口。它不读取你的 Chrome/Edge 登录资料。

启动器在动画后方激活桌面应用、退出此前的 F11 全屏状态并最大化窗口，同时预热一个原生透明遮罩。欢迎画面在 7.4–8.1 秒（快速版相应加速）收拢到中心并消失，遮罩承接相同的底色，再以柔和的椭圆形变与羽化边缘向外展开，露出下方真实、可操作的 Codex。交接不截取或存储用户界面截图。窗口大小在动画后方准备好，不会在显露后再突然放大。

日志中的 `MAXIMIZED ready behind animation`、`JELLY COLLAPSE begin`、`JELLY REVEAL begin`、`JELLY REVEAL complete` 表示各阶段，最后的 `DESKTOP confirmed ... visible=True foreground=True maximized=True fullscreen=False` 表示窗口交接已确认。无法激活窗口时会提示错误。

动画页面带有禁止翻译标记，并在本项目独立的 Edge 配置目录中关闭翻译提示，避免弹出“翻译英语页面？”浮层。不会修改你日常使用的浏览器配置。

启动时在随机的 `127.0.0.1` 端口短暂提供本地文件，完成后关闭；不对局域网开放，也不依赖网络。窗口可用时，Codex 会在动画后方准备就绪。异常情况下最长等待 45 秒后结束交接并报告错误。

## 粒子通道、外观与启动交接

开场是由 OpenAI 标志截面形成的立体星尘通道，先聚焦辨认轮廓，再向前加速穿越，近处粒子带有径向拖影和柔和辉光。约 1.6 秒后从中心一点逐渐长成蓝球，约 0.42 秒完成长大，再内缩、交接 Logo。原生开场不受浏览器加载进度控制，后台慢时只会延长流动蓝球。

**Codex Settings → 动画外观** 提供 **跟随系统 / 浅色 / 深色**，默认跟随系统。Windows 读取应用的 `AppsUseLightTheme` 设置；Mac 读取当前有效 AppKit 外观。每次启动重新识别，启动后整段使用同一外观，保证粒子、Logo、书写和最后的真实界面展开衔接一致。手动外观保存在配置的 `Theme` 字段（`system` / `light` / `dark`），更新保留。深色底色为 `#050609`，Logo 为浅白色；浅色为暖白背景和石墨色 Logo。

Windows 原生 EXE 在 PowerShell / Edge 加载前创建窗口，后台线程解码共享粒子帧。Mac 使用 Core Animation 播放相同的离线帧。粒子源分辨率 1280×800、120 fps；蓝球为 512×512、120 fps。粒子分为六段，后台只预取下一段并释放已播放段，避免整段高分辨率图集同时常驻内存。Windows 使用绝对时间采样，避免高刷新率下的限帧取整造成掉帧；实际显示帧率取决于屏幕刷新率和运行负载。每帧只改变一层纹理的取景区域，避免实时计算数千粒子、编译网页着色器或重复创建可见开场。共享帧由 `python tools/build_tunnel.py` 生成，仅使用仓库现有 OpenAI 图形；不包含参考视频或用户桌面画面。

v1.6.0 同时修复专用浏览器配置反复转换后膨胀、导致读取过慢或内存不足并退出的问题：启动只写入固定大小的动画专用设置，不读取或重新序列化整个 Edge 配置，也不修改个人浏览器。

Windows 安装时保存 Codex 的 Store 应用标识，启动直接使用缓存，避免每次 `Get-StartApps` 重新扫描完整应用列表。重新安装会生成缓存，并保留欢迎名字。

推荐版的 Logo / 书写节奏从 1.6× 提升到 2×，完整版从 1× 提升到 1.15×；原生蓝球只短暂停留。两个版本的片尾展开分别缩短到约 0.8 秒与 0.95 秒。名字、无标题栏、防闪烁和 Codex 最大化设置保留。

Windows 在窗口不可见时隐藏浏览器内部标题栏，并确认网页实际宽高占满窗口，才放到原生粒子通道后方。动画不显示标题栏或右上角按钮；进入 Codex 后保留最小化与还原。窗口控制仅操作独立、未登录的本机 Edge 配置；不访问个人浏览器或外部页面，结束后相关进程与端口关闭。

## 浏览器预览

双击 `docs/index.html` 即可离线预览。页面提供重播、深浅色切换、5.1/8.1 秒切换和全屏按钮。浏览器预览包含欢迎画面的收拢，不会启动电脑上的 Codex；真实界面的向外展开由对应系统的原生启动器完成。

- `docs/fast.html`：默认 5.1 秒预览。
- `docs/full.html`：默认 8.1 秒预览。
- `docs/animation.html?play=1&variant=fast&desktop-preview=1&theme=system`：纯动画入口。
- `docs/animation.html?play=1&variant=full&desktop-preview=1&theme=dark`：深色完整版。

为了在本地 HTTP 环境测试，也可以安装 Node.js 后运行：

```sh
node tools/serve.mjs
```

然后打开终端中显示的本地地址。

## 部署到 GitHub Pages

无需构建，也不需要后端：

1. 打开仓库 **Settings → Pages**。
2. 在 **Build and deployment → Source** 选择 **Deploy from a branch**。
3. 分支选择 **main**，文件夹选择 **/docs**，点击 **Save**。
4. 等待 Pages 部署完成，访问设置页给出的站点地址。

例如，本仓库部署后的地址通常是：

```text
https://zhuolin272-dotcom.github.io/codex-welcome-animation/
https://zhuolin272-dotcom.github.io/codex-welcome-animation/?variant=full
```

这些是启用 Pages 后的预期地址，不代表刚克隆的仓库已经启用。静态站点用于分享和预览；打开桌面 Codex 的能力由下载后的 Windows / macOS 本地启动器提供。发布源配置参见 [GitHub 官方文档](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)。

也可把 `docs/` 中的全部文件上传到任意静态托管服务；保留 `vendor/` 相对路径即可。

## 开发与修改动画

日常修改名字请用上方设置入口。开发者修改字形素材或默认示例时，才需要 Python 3 和开发依赖：

```sh
python -m pip install -r requirements-dev.txt
python tools/build.py --name JimmSun --greeting welcome
```

构建参数 `--name` 和 `--greeting` 支持 Sacramento 字体包含的拉丁字符，建议使用简短文字以保持版式。字形生成结果保存在 `docs/animation.html`。修改动作、配色和着色器请编辑 `source/animation.template.html`，然后重新运行构建脚本；不要只修改生成文件。运行 `python tools/build_glyphs.py` 可重建离线可复用字库 `docs/glyphs.js`。Windows 重新运行 `Install.cmd` 可将修改更新到本机安装目录；Mac 重新执行 `bash macos/build.sh` 后安装生成的 `.app`。

```text
docs/                         可离线运行、可静态部署的预览
source/animation.template.html  动画、弹簧曲线、云雾着色器与交接逻辑
tools/build.py                SVG 手写字形生成器
launcher/StartupCover.cs       Windows 原生云雾开场与消失后交接
launcher/BrowserWindow.ps1     隐藏动画标题栏并校验实际视口
launcher/RainCurtain.cs        原生白色雨滴绘制
launcher/StartupBridge.cs      启动器与后台共享同一开场窗口
tools/export_startup_cloud.cjs 从 t=0 着色器生成 Windows 首帧素材
launcher/Launch.ps1            本地服务、全屏窗口与 Codex 交接
launcher/HandoffOverlay.cs     原生透明果冻展开遮罩，显露真实 Codex
macos/                        原生 Swift/AppKit/WebKit 启动器及安装、构建脚本
launcher/Bootstrap.cs          无控制台的原生入口，安装时编译为 CodexWelcome.exe
launcher/Start.vbs             旧版兼容入口，当前快捷方式不使用
Install.ps1 / Install.cmd      当前用户安装器
tests/Smoke.ps1               两种速度的真实浏览器完成回调测试
tests/Detection.ps1           桌面注册入口检测与 CLI 误识别回归检查
tests/Handoff.ps1             展开面积与收尾边缘覆盖检查
launcher/Settings.ps1          Windows 名字设置窗口及配置保存
docs/personalize.js             安全 SVG 名字排版与手写/中文显现
docs/glyphs.js                  已打包字形库，用户无需 Python
assets/                       图标、字形源、预览图及许可证
```

## 个性化开发检查

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/Personalization.ps1
```

Windows 检查包含不传 `ConfigPath`、安装路径含空格、从其他工作目录启动的默认路径回归检查。

前端检查需要开发机安装 `playwright`，运行 `node tests/startup.cjs` 验证首帧显示前时间线保持零点，再运行 `node tests/personalization.cjs`；覆盖拉丁/中文、最长名字缩放、输入安全、完整显字和浏览器保存。Mac 的 `bash macos/test.sh` 检查配置保存与验证，`bash macos/smoke.sh` 在原生 WebKit 中用中英文名字播放两种速度。

## 测试与排错

### Windows 最小化恢复后对话跳到顶部

这项问题**尚未解决**。在本机对照测试中，不播放本项目动画、只通过任务栏恢复 Codex，也会跳到对话顶部；因此 v1.6.1 的“复用现有窗口”不能保证保留滚动位置。相同 Store 包版本 `26.1013.4894.0` 有[公开问题记录 #55612](https://github.com/openai/codex/issues/55612)。该记录是用户报告，不代表已确认内部根因或已有官方修复。

启动器侧的恢复顺序调整、辅助功能“滚动到底部”补偿未通过本机实际验证，已撤回，不作为修复发布。临时可尝试保持 Codex 不最小化，改用 Alt+Tab 切换应用，以避开最小化/恢复这个触发方式；这不能代替应用本身的修复，也不保证消除其他滚动问题。


检查资源与 Codex/Edge 检测：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\launcher\Launch.ps1 -ValidateOnly
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Detection.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Handoff.ps1
```

使用无头 Edge 完整播放两个版本，确认真实的 READY、FADE、COMPLETE 回调；不打开 Codex、不显示全屏窗口：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Smoke.ps1
```

日志位于安装目录的 `logs\launch.log`。原生入口额外记录 `logs\bootstrap.log`，包含入口启动时间、PowerShell 输出与退出码；启动失败会弹出错误提示。如果 Codex 更新后更换了安装位置，先重新打开 Codex 再试；也可以重新安装并指定新的 `-CodexPath`。如果显卡不支持 WebGL，蓝球会使用渐变外观，其他动作继续播放。

如果旧版快捷方式出现 Windows Script Host 的“无法找到脚本文件 Start.vbs”提示，或双击后没有反应，下载最新版并重新运行 `Install.cmd`，即可重新生成桌面和开始菜单的两个快捷方式并刷新图标缓存。当前快捷方式的目标应为安装目录中的 `CodexWelcome.exe`，参数为 `fast` 或 `full`。也可直接双击安装目录中的 `CodexWelcome.exe`，默认播放快速版。

安装后可测试包含原生入口在内的完整调用链（无头模式，不打开 Codex）：

```powershell
$install = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'CodexWelcome'
Start-Process (Join-Path $install 'CodexWelcome.exe') -ArgumentList 'fast --test' -Wait
Start-Process (Join-Path $install 'CodexWelcome.exe') -ArgumentList 'full --test' -Wait
```

## 卸载

运行安装目录中的 `Uninstall.ps1` 会删除本项目创建的快捷方式，并保留安装文件。之后可手动删除“文档”中的 `CodexWelcome` 文件夹。它不会卸载 Codex 或 Edge。

## 许可证与素材

本项目自写代码使用 MIT 许可证；第三方素材保持各自许可，详见 [NOTICE.md](NOTICE.md)。OpenAI 标志的商标权属于 OpenAI。本项目是个人欢迎动画，与 OpenAI 没有官方隶属或背书关系。

Windows 可运行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/WindowStartup.ps1` 验证真实窗口的两种速度、完整播放和无标题栏视口；该检查不启动 Codex。
