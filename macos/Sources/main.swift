import AppKit
import ApplicationServices
import Darwin
import UniformTypeIdentifiers
import WebKit

private let arguments = Set(CommandLine.arguments.dropFirst())
private let selfTest = arguments.contains("--self-test")
private let variant = Bundle.main.object(forInfoDictionaryKey: "CWVariant") as? String ?? "fast"
private let paper = NSColor(srgbRed: 247 / 255, green: 246 / 255, blue: 242 / 255, alpha: 1)
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
    if selfTest { print(message) }
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
        let colors = [CGColor(red: 247 / 255, green: 246 / 255, blue: 242 / 255, alpha: 0),
                      CGColor(red: 247 / 255, green: 246 / 255, blue: 242 / 255, alpha: 0),
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
    private var lockFD: Int32 = -1
    private var docs: URL!

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
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
                  welcomeFiles.fileExists(atPath: docs.appendingPathComponent("vendor/gsap.min.js").path) else {
                throw failure("动画资源不完整。请重新安装完整的 .app。")
            }
            if !selfTest {
                codexURL = try locateCodex()
                maximize = AXIsProcessTrusted()
                if !maximize { try explainAccessibility() }
            }
            screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main ?? NSScreen.screens.first
            guard screen != nil else { throw failure("没有可用的显示器。") }
            showAnimation()
            started = ProcessInfo.processInfo.systemUptime
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
        let data = try JSONSerialization.data(withJSONObject: ["CodexPath": chosen.path], options: .prettyPrinted)
        try data.write(to: config, options: .atomic)
        return chosen
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
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let root = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        window.contentView = root
        revealView = RevealView(frame: root.bounds)
        revealView.autoresizingMask = [.width, .height]
        root.addSubview(revealView)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(self, name: "codexWelcome")
        webView = WKWebView(frame: root.bounds, configuration: configuration)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.underPageBackgroundColor = paper
        root.addSubview(webView)
        window.onEscape = { [weak self] in self?.skipIntro() }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        var components = URLComponents(url: docs.appendingPathComponent("animation.html"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "launch", value: "1"), URLQueryItem(name: "play", value: "1"), URLQueryItem(name: "variant", value: variant)]
        webView.loadFileURL(components.url!, allowingReadAccessTo: docs)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.webView === webView, let kind = message.body as? String else { return }
        switch kind {
        case "ready": log("READY"); openCodex()
        case "fade": log("JELLY COLLAPSE begin")
        case "complete": introComplete = true; log("INTRO complete"); poll()
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
        polling?.invalidate()
        log("JELLY REVEAL begin")
        webView.isHidden = true
        webView.stopLoading()
        revealStarted = ProcessInfo.processInfo.systemUptime
        revealTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let p = (ProcessInfo.processInfo.systemUptime-self.revealStarted)/1.1
            self.revealView.progress = min(1,p)
            if p >= 1.06 { self.finish() }
        }
    }

    private func skipIntro() {
        if revealing { finish(); return }
        webView.evaluateJavaScript("window.__timelines?.['jimmsun-intro']?.progress(1)")
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
