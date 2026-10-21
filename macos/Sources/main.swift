import AppKit
import ApplicationServices
import Darwin
import UniformTypeIdentifiers
import WebKit
import QuartzCore

private let arguments = Set(CommandLine.arguments.dropFirst())
private let selfTest = arguments.contains("--self-test")
private let variant = Bundle.main.object(forInfoDictionaryKey: "CWVariant") as? String ?? "fast"
private let settingsMode = arguments.contains("--settings") || variant == "settings"
private var darkTheme = false
private var paper = NSColor(srgbRed: 247 / 255, green: 246 / 255, blue: 242 / 255, alpha: 1)
private let welcomeFiles = FileManager.default
private let support = welcomeFiles.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CodexWelcome", isDirectory: true)

private func log(_ message: String) {
    let line = ISO8601DateFormatter().string(from: Date()) + " " + message + "\n"
    let directory = welcomeFiles.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/CodexWelcome", isDirectory: true)
    try? welcomeFiles.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent(variant + (selfTest ? "-self-test.log" : ".log"))
    if !welcomeFiles.fileExists(atPath: url.path) { welcomeFiles.createFile(atPath: url.path, contents: nil) }
    if let handle = try? FileHandle(forWritingTo: url) {
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(line.utf8))
    }
    if selfTest { print(message); fflush(stdout) }
}

private func axAttribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

private final class WelcomeWindow: NSWindow {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?() } else { super.keyDown(with: event) }
    }
}

private final class RevealView: NSView {
    var progress: Double = 0 { didSet { needsDisplay = true } }
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        let (rx, ry) = JellyGeometry.radii(progress: progress, width: bounds.width, height: bounds.height)
        let space = CGColorSpaceCreateDeviceRGB()
        let colors = [paper.withAlphaComponent(0).cgColor,
                      paper.withAlphaComponent(0).cgColor,
                      paper.cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.975, 1]) else { return }
        context.saveGState()
        context.translateBy(x: bounds.midX, y: bounds.midY)
        context.scaleBy(x: rx, y: ry)
        context.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0,
                                   endCenter: .zero, endRadius: 1, options: [.drawsAfterEndLocation])
        context.restoreGState()
    }
}

private final class StartupOrbView: NSView {
    private let orb = CALayer()
    private let particles = CALayer()
    private let tunnelDirectory: URL
    private var chunkImages: [Int: CGImage] = [:]
    private var requestedChunks: Set<Int> = []
    private var visibleAt = CACurrentMediaTime()
    private var orbShownAt = 0.0
    private var preparing = false
    private var collapsing = false
    var rainIsActive: Bool { particles.opacity > 0 && orb.opacity == 0 }
    init(frame: NSRect, image: NSImage, tunnel: NSImage, directory: URL) {
        tunnelDirectory = directory
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = paper.cgColor
        layer?.masksToBounds = true
        var rect = NSRect(origin: .zero, size: tunnel.size)
        chunkImages[0] = tunnel.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        particles.contents = chunkImages[0]
        particles.contentsRect = CGRect(x: 0, y: 0, width: 0.25, height: 0.125)
        layer?.addSublayer(particles)
        orb.opacity = 0
        rect = NSRect(origin: .zero, size: image.size)
        orb.contents = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        orb.contentsRect = CGRect(x: 0, y: 0, width: 0.125, height: 0.0625)
        orb.masksToBounds = true
        layer?.addSublayer(orb)
        let flow = CAKeyframeAnimation(keyPath: "contentsRect")
        flow.values = (0...128).map { index in
            let f = index % 128
            return NSValue(rect: NSRect(x: Double(f % 8) / 8, y: Double(f / 8) / 16, width: 0.125, height: 0.0625))
        }
        flow.calculationMode = .discrete
        flow.duration = 128.0 / 120
        flow.repeatCount = .infinity
        orb.add(flow, forKey: "cloud-flow")
    }
    required init?(coder: NSCoder) { fatalError("Not supported") }
    override func layout() {
        super.layout()
        let diameter = 280 * min(bounds.width / 1920, bounds.height / 1080)
        let fit = min(bounds.width / 640, bounds.height / 400)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        particles.bounds = CGRect(x: 0, y: 0, width: 640 * fit, height: 400 * fit)
        particles.position = CGPoint(x: bounds.midX, y: bounds.midY)
        orb.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        orb.position = CGPoint(x: bounds.midX, y: bounds.midY)
        orb.cornerRadius = diameter / 2
        CATransaction.commit()
    }
    private func loadChunk(_ index: Int) {
        guard index < 6, requestedChunks.insert(index).inserted else { return }
        let url = tunnelDirectory.appendingPathComponent(String(format: "tunnel-%@-%02d.png", darkTheme ? "dark" : "light", index))
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            autoreleasepool {
                guard let image = NSImage(contentsOf: url) else { return }
                var rect = NSRect(origin: .zero, size: image.size)
                guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return }
                DispatchQueue.main.async {
                    guard let self = self, self.particles.opacity > 0 else { return }
                    let current = Int((CACurrentMediaTime() - self.visibleAt) * 120) / 32
                    guard index >= current else { return }
                    self.chunkImages[index] = cg
                    if index == current { self.showChunk(index) }
                }
            }
        }
    }
    private func showChunk(_ index: Int) {
        guard let image = chunkImages[index] else { loadChunk(index); return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        particles.contents = image
        CATransaction.commit()
        let flight = CAKeyframeAnimation(keyPath: "contentsRect")
        flight.values = (0...32).map { value in
            let f = min(31, value)
            return NSValue(rect: NSRect(x: Double(f % 4) / 4, y: Double(f / 4) / 8, width: 0.25, height: 0.125))
        }
        flight.calculationMode = .discrete
        flight.duration = 32.0 / 120
        flight.beginTime = visibleAt + Double(index) * 32 / 120
        flight.fillMode = .both
        flight.isRemovedOnCompletion = false
        particles.add(flight, forKey: "tunnel-flight")
        for key in Array(chunkImages.keys) where key < index { chunkImages.removeValue(forKey: key) }
        loadChunk(index + 1)
    }
    func startRainFill() {
        visibleAt = CACurrentMediaTime()
        showChunk(0)
        for index in 1..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 32 / 120) { [weak self] in self?.showChunk(index) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self = self else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.particles.opacity = 0
            self.particles.contents = nil
            self.chunkImages.removeAll()
            self.orb.opacity = 1
            CATransaction.commit()
            let grow = CAKeyframeAnimation(keyPath: "transform")
            grow.values = (0...30).map { index in
                let p = Double(index) / 30
                let scale = max(0.001, p * p * (3 - 2 * p))
                return NSValue(caTransform3D: CATransform3DMakeScale(scale, scale, 1))
            }
            grow.duration = 0.42
            self.orb.add(grow, forKey: "point-to-orb")
            self.orbShownAt = CACurrentMediaTime()
        }
    }
    func prepareForContent(completion: @escaping () -> Void) {
        guard !preparing else { return }
        preparing = true
        let delay = max(0, 2.05 - (CACurrentMediaTime() - visibleAt))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { completion() }
    }
    func collapse(speed: Double, completion: @escaping () -> Void) {
        guard !collapsing else { return }
        collapsing = true
        let delay = max(0, 0.54 - (CACurrentMediaTime() - orbShownAt))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            let collapse = CAKeyframeAnimation(keyPath: "transform")
            collapse.values = (0...32).map { index in
                let p = Double(index) / 32
                let scale = 1 - (pow(2, 10 * p) - 1) / 1023
                return NSValue(caTransform3D: CATransform3DMakeScale(scale, scale, 1))
            }
            collapse.duration = 0.22 / speed
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.orb.transform = CATransform3DMakeScale(0, 0, 1)
            CATransaction.commit()
            self.orb.add(collapse, forKey: "collapse")
            DispatchQueue.main.asyncAfter(deadline: .now() + collapse.duration + 1.0 / 60) { completion() }
        }
    }
}

private final class Launcher: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    private var window: WelcomeWindow!
    private var webView: WKWebView!
    private var revealView: RevealView!
    private var screen: NSScreen!
    private var codex: NSRunningApplication?
    private var codexURL: URL?
    private var maximize = false
    private var desktopReady = false
    private var introComplete = false
    private var openingRequested = false
    private var revealing = false
    private var finishing = false
    private var polling: Timer?
    private var revealTimer: Timer?
    private var revealStarted = 0.0
    private var started = 0.0
    private var introStarted = 0.0
    private var webIntroStarted: Double?
    private var lockFD: Int32 = -1
    private var docs: URL!
    private var welcomeName = "JimmSun"
    private var startupPhase = "loading"
    private var startupCover: StartupOrbView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            if settingsMode { showNameSettings(); NSApp.terminate(nil); return }
            let config = support.appendingPathComponent("config.json")
            welcomeName = WelcomePreferences.name(at: config)
            let systemDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            darkTheme = WelcomePreferences.theme(at: config, systemDark: systemDark) == "dark"
            if selfTest, let override = CommandLine.arguments.first(where: { $0.hasPrefix("--theme=") }) { darkTheme = override == "--theme=dark" }
            paper = darkTheme ? NSColor(srgbRed: 5 / 255, green: 6 / 255, blue: 9 / 255, alpha: 1) : NSColor(srgbRed: 247 / 255, green: 246 / 255, blue: 242 / 255, alpha: 1)
            if selfTest, let override = CommandLine.arguments.first(where: { $0.hasPrefix("--welcome-name=") }) {
                welcomeName = try WelcomePreferences.validatedName(String(override.dropFirst("--welcome-name=".count)))
            }
            try welcomeFiles.createDirectory(at: support, withIntermediateDirectories: true)
            lockFD = Darwin.open(support.appendingPathComponent("launch.lock").path, O_CREAT | O_RDWR, 0o600)
            guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
                log("BUSY another welcome animation is running")
                NSApp.terminate(nil)
                return
            }
            guard let resources = Bundle.main.resourceURL else { throw failure("无法找到应用资源。请重新安装。") }
            docs = resources.appendingPathComponent("docs", isDirectory: true).resolvingSymlinksInPath()
            guard welcomeFiles.fileExists(atPath: docs.appendingPathComponent("animation.html").path),
                  welcomeFiles.fileExists(atPath: docs.appendingPathComponent("vendor/gsap.min.js").path),
                  welcomeFiles.fileExists(atPath: docs.appendingPathComponent("glyphs.js").path),
                  welcomeFiles.fileExists(atPath: docs.appendingPathComponent("personalize.js").path) else {
                throw failure("动画资源不完整。请重新安装完整的 .app。")
            }
            if !selfTest {
                codexURL = try locateCodex()
                maximize = AXIsProcessTrusted()
                if !maximize { try explainAccessibility() }
            }
            screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main ?? NSScreen.screens.first
            guard screen != nil else { throw failure("没有可用的显示器。") }
            started = ProcessInfo.processInfo.systemUptime
            showAnimation()
            polling = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in self?.poll() }
            log("START variant=\(variant) selfTest=\(selfTest)")
        } catch { abort(error.localizedDescription) }
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "CodexWelcome", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func locateCodex() throws -> URL {
        let config = support.appendingPathComponent("config.json")
        var candidates = [URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true),
                          welcomeFiles.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Codex.app", isDirectory: true)]
        if let data = try? Data(contentsOf: config),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: String], let path = object["CodexPath"] {
            candidates.insert(URL(fileURLWithPath: path, isDirectory: true), at: 0)
        }
        if let registered = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") { candidates.append(registered) }
        if let found = candidates.first(where: { $0.pathExtension == "app" && welcomeFiles.fileExists(atPath: $0.path) }) { return found }
        let picker = NSOpenPanel()
        picker.title = "请选择 Codex.app"
        picker.message = "请选择已经安装的 Codex 桌面应用，不是命令行程序。"
        picker.allowedContentTypes = [.applicationBundle]
        picker.allowsMultipleSelection = false
        picker.canChooseDirectories = false
        guard picker.runModal() == .OK, let chosen = picker.url else { throw failure("未选择 Codex.app。") }
        try WelcomePreferences.set(chosen.path, forKey: "CodexPath", at: config)
        return chosen
    }

    private func showNameSettings() {
        let config = support.appendingPathComponent("config.json")
        let alert = NSAlert()
        alert.messageText = "你希望欢迎动画如何称呼你？"
        let hint = "1–20 个字符。英文字母连笔书写，中文平滑显字。保存后，5.1s 和 8.1s 两版同时生效。"
        alert.informativeText = hint
        let pane = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 96))
        let input = NSTextField(frame: NSRect(x: 0, y: 66, width: 340, height: 28))
        let appearance = NSPopUpButton(frame: NSRect(x: 0, y: 4, width: 340, height: 30))
        appearance.addItems(withTitles: ["跟随系统（自动深色 / 浅色）", "浅色", "深色"])
        let choices = ["system", "light", "dark"]
        appearance.selectItem(at: choices.firstIndex(of: WelcomePreferences.read(at: config)["Theme"] as? String ?? "system") ?? 0)
        let label = NSTextField(labelWithString: "动画外观")
        label.frame = NSRect(x: 0, y: 38, width: 340, height: 22)
        pane.addSubview(input); pane.addSubview(label); pane.addSubview(appearance)
        input.stringValue = WelcomePreferences.name(at: config)
        alert.accessoryView = pane
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        NSApp.activate()
        alert.window.initialFirstResponder = input
        while alert.runModal() == .alertFirstButtonReturn {
            do {
                try WelcomePreferences.set(input.stringValue, forKey: "WelcomeName", at: config)
                try WelcomePreferences.set(choices[appearance.indexOfSelectedItem], forKey: "Theme", at: config)
                return
            } catch { alert.informativeText = error.localizedDescription + "\n\n" + hint }
        }
    }

    private func explainAccessibility() throws {
        let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(prompt)
        let alert = NSAlert()
        alert.messageText = "允许启动器自动最大化 Codex？"
        alert.informativeText = "请在“系统设置 → 隐私与安全性 → 辅助功能”中启用此启动器，然后点重试。只用于调整 Codex 窗口，不需要屏幕录制权限。也可以保留 Codex 当前大小继续播放。"
        alert.addButton(withTitle: "已授权，重试")
        alert.addButton(withTitle: "保留窗口大小继续")
        alert.addButton(withTitle: "取消")
        while true {
            let response = alert.runModal()
            if response == .alertSecondButtonReturn { maximize = false; return }
            if response == .alertThirdButtonReturn { throw failure("已取消启动。") }
            if AXIsProcessTrusted() { maximize = true; return }
        }
    }

    private func showAnimation() {
        window = WelcomeWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.title = "Codex Welcome"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.animationBehavior = .none
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let root = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        window.contentView = root
        revealView = RevealView(frame: root.bounds)
        revealView.autoresizingMask = [.width, .height]
        revealView.isHidden = true
        root.addSubview(revealView)
        guard let imageURL = Bundle.main.url(forResource: "orb-motion", withExtension: "png"),
              let image = NSImage(contentsOf: imageURL) else { abort("缺少中央蓝球素材，请重新安装。"); return }
        guard let tunnelURL = Bundle.main.url(forResource: darkTheme ? "tunnel-dark-00" : "tunnel-light-00", withExtension: "png", subdirectory: "docs"),
              let tunnel = NSImage(contentsOf: tunnelURL) else { abort("缺少粒子通道素材"); return }
        let nativeOrb = StartupOrbView(frame: root.bounds, image: image, tunnel: tunnel, directory: docs)
        nativeOrb.autoresizingMask = [.width, .height]
        root.addSubview(nativeOrb)
        startupCover = nativeOrb
        window.onEscape = { [weak self] in self?.skipIntro() }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        root.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        CATransaction.flush()
        if selfTest && !nativeOrb.rainIsActive { abort("Rain did not start before WebKit"); return }
        nativeOrb.startRainFill()
        log("RAIN native visible elapsed=\(String(format: "%.3f", ProcessInfo.processInfo.systemUptime - started))s; WebKit warming behind it")
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(self, name: "codexWelcome")
        webView = WKWebView(frame: root.bounds.offsetBy(dx: root.bounds.width * 2, dy: 0), configuration: configuration)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.underPageBackgroundColor = paper
        root.addSubview(webView, positioned: .below, relativeTo: nativeOrb)
        // The native centered orb stays responsive during WebKit's cold start.
        root.layoutSubtreeIfNeeded()
        var components = URLComponents(url: docs.appendingPathComponent("animation.html"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "launch", value: "1"), URLQueryItem(name: "play", value: "1"), URLQueryItem(name: "variant", value: variant), URLQueryItem(name: "name", value: welcomeName), URLQueryItem(name: "defer-start", value: "1"), URLQueryItem(name: "native-orb", value: "1"), URLQueryItem(name: "theme", value: darkTheme ? "dark" : "light")]
        if selfTest { components.queryItems?.append(URLQueryItem(name: "motion-test", value: "1")) }
        // URLSearchParams treats a literal + as a space; preserve plus signs in nicknames.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        webView.loadFileURL(components.url!, allowingReadAccessTo: docs)
    }

    private func prepareFirstFrame() {
        guard startupPhase == "loading", !finishing else { return }
        startupPhase = "rain-finishing"
        guard let opening = startupCover else { abort("Native rain is missing"); return }
        opening.prepareForContent { [weak self] in
            guard let self = self, !self.finishing, !self.revealing else { return }
            self.webView.setFrameOrigin(.zero)
            self.window.contentView?.layoutSubtreeIfNeeded()
            self.captureNativeFrame()
            self.snapshotPreparedFrame()
        }
    }
    private func captureNativeFrame() {
        guard let nativeOrb = startupCover, let root = window.contentView else { return }
        if selfTest, let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--native-startup-snapshot=") }) {
            guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(root.bounds.width), pixelsHigh: Int(root.bounds.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                  let context = NSGraphicsContext(bitmapImageRep: bitmap) else { abort("Cannot validate native startup orb"); return }
            nativeOrb.layer?.render(in: context.cgContext)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { abort("Cannot encode native startup orb"); return }
            do { try png.write(to: URL(fileURLWithPath: String(argument.dropFirst("--native-startup-snapshot=".count))), options: .atomic) }
            catch { abort(error.localizedDescription); return }
        }
    }
    private func snapshotPreparedFrame() {
        startupPhase = "snapshotting"
        log("FIRST FRAME preparing windowVisible=\(window.isVisible)")
        let configuration = WKSnapshotConfiguration()
        configuration.rect = webView.bounds
        configuration.afterScreenUpdates = true
        webView.takeSnapshot(with: configuration) { [weak self] image, error in
            guard let self = self, !self.finishing, !self.revealing else { return }
            guard let image = image, error == nil else {
                self.abort(error?.localizedDescription ?? "无法准备动画首帧。")
                return
            }
            if selfTest {
                guard self.window.isVisible, self.startupCover != nil else { self.abort("Native orb did not cover WebKit startup"); return }
                if let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--startup-snapshot=") }),
                   let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
                   let png = bitmap.representation(using: .png, properties: [:]) {
                    do { try png.write(to: URL(fileURLWithPath: String(argument.dropFirst("--startup-snapshot=".count))), options: .atomic) }
                    catch { self.abort(error.localizedDescription); return }
                }
            }
            self.startupPhase = "presenting"
            log("LOGO ENTRY web prepared at t=1.72; native orb stays in motion")
            self.webView.evaluateJavaScript("window.__prepareWelcomeDisplay()") { result, error in
                if let error = error { self.abort(error.localizedDescription) }
                else if result as? Bool != true { self.abort("动画首帧未能提交。") }
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.webView === webView else { return }
        let payload = message.body as? [String: Any]
        guard let kind = payload?["kind"] as? String ?? message.body as? String else { return }
        let webClock = payload?["clock"] as? Double
        switch kind {
        case "prepared":
            prepareFirstFrame()
        case "presented":
            guard startupPhase == "presenting", !finishing, !revealing else { return }
            if selfTest && (payload?["time"] as? Double != 1.72 || startupCover == nil) {
                abort("Startup timeline advanced before its first visible frame"); return
            }
            startupPhase = "collapsing"
            guard let nativeOrb = startupCover else { abort("Native opening orb is missing"); return }
            nativeOrb.collapse(speed: variant == "full" ? 1.15 : 2) { [weak self] in
                guard let self = self, !self.finishing, !self.revealing else { return }
                self.startupPhase = "running"
                // Both surfaces are now the same paper color. The orb is gone;
                // continue at the logo entry, without replaying a second orb.
                self.startupCover?.removeFromSuperview()
                self.startupCover = nil
                log("LIVE ORB collapsed; continue with logo at t=1.72")
                self.webView.evaluateJavaScript("window.__startWelcome()") { result, error in
                    if let error = error { self.abort(error.localizedDescription) }
                    else if result as? Bool != true { self.abort("动画未能启动。"); }
                }
            }
        case "ready":
            if selfTest && payload?["name"] as? String != welcomeName { abort("Personalized name did not reach WebKit"); return }
            introStarted = ProcessInfo.processInfo.systemUptime
            webIntroStarted = webClock
            log("READY"); openCodex()
        case "fade": log("JELLY COLLAPSE begin")
        case "complete":
            // Web-process timestamps exclude main-thread IPC delivery delays.
            let elapsed: Double
            if let clock = webClock, let start = webIntroStarted { elapsed = (clock - start) / 1000 }
            else { elapsed = ProcessInfo.processInfo.systemUptime - introStarted }
            if selfTest && elapsed < (variant == "full" ? 5.3 : 3.0) {
                abort("Self-test animation completed too early: \(elapsed)s")
                return
            }
            introComplete = true
            log(String(format: "INTRO complete elapsed=%.3fs", elapsed)); poll()
        default: break
        }
    }

    private func openCodex() {
        guard !openingRequested else { return }
        openingRequested = true
        if selfTest { desktopReady = true; return }
        guard let url = codexURL else { abort("无法找到 Codex.app。"); return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] app, error in
            DispatchQueue.main.async {
                guard let self = self, !self.finishing else { return }
                if let error = error { self.abort(error.localizedDescription); return }
                guard let app = app else { self.abort("Codex 未能启动。"); return }
                self.codex = app
                app.unhide()
                log("DESKTOP launched pid=\(app.processIdentifier)")
                self.poll()
            }
        }
    }

    private func prepareDesktop() -> Bool {
        guard let app = codex, !app.isTerminated else { return false }
        guard maximize else { return true }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        let focused = axAttribute(application, kAXMainWindowAttribute)
        let windows = axAttribute(application, kAXWindowsAttribute) as? [AXUIElement] ?? []
        let chosen = focused.map { $0 as! AXUIElement } ?? windows.first
        guard let chosen = chosen else { return false }
        if axAttribute(chosen, "AXFullScreen") as? Bool == true {
            _ = AXUIElementSetAttributeValue(chosen, "AXFullScreen" as CFString, kCFBooleanFalse)
            return false
        }
        if axAttribute(chosen, kAXMinimizedAttribute) as? Bool == true {
            _ = AXUIElementSetAttributeValue(chosen, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            return false
        }
        let visible = screen.visibleFrame
        let primaryTop = NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
        var position = CGPoint(x: visible.minX, y: primaryTop - visible.maxY)
        var size = CGSize(width: visible.width, height: visible.height)
        if let value = AXValueCreate(.cgPoint, &position) { _ = AXUIElementSetAttributeValue(chosen, kAXPositionAttribute as CFString, value) }
        if let value = AXValueCreate(.cgSize, &size) { _ = AXUIElementSetAttributeValue(chosen, kAXSizeAttribute as CFString, value) }
        guard let currentPosition = axAttribute(chosen, kAXPositionAttribute), let currentSize = axAttribute(chosen, kAXSizeAttribute) else { return false }
        var actualPosition = CGPoint.zero, actualSize = CGSize.zero
        guard AXValueGetValue(currentPosition as! AXValue, .cgPoint, &actualPosition),
              AXValueGetValue(currentSize as! AXValue, .cgSize, &actualSize) else { return false }
        return abs(actualPosition.x-position.x) < 4 && abs(actualPosition.y-position.y) < 4 && abs(actualSize.width-size.width) < 4 && abs(actualSize.height-size.height) < 4
    }

    private func poll() {
        guard !finishing && !revealing else { return }
        if !desktopReady && !selfTest && codex != nil {
            desktopReady = prepareDesktop()
            if desktopReady { log("DESKTOP ready maximized=\(maximize)") }
        }
        if ProcessInfo.processInfo.systemUptime - started > 45 { abort("Codex 窗口或动画未能及时就绪。请检查日志。" ); return }
        if introComplete && desktopReady { beginReveal() }
    }

    private func beginReveal() {
        guard !revealing else { return }
        revealing = true
        revealView.isHidden = false
        polling?.invalidate()
        startupCover?.removeFromSuperview()
        startupCover = nil
        window.isOpaque = false
        window.backgroundColor = .clear
        log("JELLY REVEAL begin")
        // Put the real desktop in front while the opaque native cover still hides it.
        // Otherwise the aperture would reveal Finder and switch to Codex only at the end.
        if let app = codex {
            app.activate(from: .current, options: [.activateAllWindows])
            if maximize {
                let application = AXUIElementCreateApplication(app.processIdentifier)
                if let main = axAttribute(application, kAXMainWindowAttribute) {
                    _ = AXUIElementPerformAction(main as! AXUIElement, kAXRaiseAction as CFString)
                }
            }
        }
        webView.isHidden = true
        webView.stopLoading()
        revealStarted = ProcessInfo.processInfo.systemUptime
        revealTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let p = (ProcessInfo.processInfo.systemUptime-self.revealStarted)/(variant == "full" ? 0.95 : 0.8)
            self.revealView.progress = min(1,p)
            if p >= 1.06 { self.finish() }
        }
    }

    private func skipIntro() {
        if revealing { finish(); return }
        webView?.evaluateJavaScript("window.__timelines?.['jimmsun-intro']?.progress(1)")
        introComplete = true
        openCodex()
        poll()
    }

    private func finish() {
        guard !finishing else { return }
        finishing = true
        log("JELLY REVEAL complete")
        cleanup()
        if let app = codex { app.activate(from: .current, options: [.activateAllWindows]) }
        if selfTest { print("SELF_TEST_OK variant=\(variant)") }
        NSApp.terminate(nil)
    }

    private func cleanup() {
        polling?.invalidate(); revealTimer?.invalidate()
        webView?.stopLoading()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "codexWelcome")
        window?.orderOut(nil)
        if lockFD >= 0 { flock(lockFD, LOCK_UN); Darwin.close(lockFD); lockFD = -1 }
    }

    private func abort(_ message: String) {
        guard !finishing else { return }
        finishing = true
        log("ERROR " + message)
        cleanup()
        if selfTest { fputs(message + "\n", stderr); Darwin.exit(1) }
        let alert = NSAlert()
        alert.messageText = "Codex Welcome 未能完成启动"
        alert.informativeText = message + "\n\n日志：~/Library/Logs/CodexWelcome/"
        alert.runModal()
        NSApp.terminate(nil)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { abort(error.localizedDescription) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { abort(error.localizedDescription) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { abort("动画渲染进程退出，请重试。") }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, url.isFileURL,
              url.resolvingSymlinksInPath().path.hasPrefix(docs.path + "/") else { decisionHandler(.cancel); return }
        decisionHandler(.allow)
    }
    func applicationWillTerminate(_ notification: Notification) { cleanup() }
}

if arguments.contains("--diagnose") {
    #if arch(arm64)
    let architecture = "arm64"
    #else
    let architecture = "x86_64"
    #endif
    let resource = Bundle.main.resourceURL?.appendingPathComponent("docs/animation.html")
    let result: [String: Any] = ["os": ProcessInfo.processInfo.operatingSystemVersionString, "architecture": architecture,
                               "variant": variant, "accessibility": AXIsProcessTrusted(),
                               "assetsPresent": resource.map { welcomeFiles.fileExists(atPath: $0.path) } ?? false]
    let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    print(String(decoding: data, as: UTF8.self))
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = Launcher()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
