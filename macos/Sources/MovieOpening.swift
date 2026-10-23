import AppKit
import AVFoundation
import QuartzCore
import CoreVideo

// AVPlayer's decoded frame delivery runs independently of AppKit's event loop.
// Keep this metric separate from the UI callback metric during WebKit startup.
private final class MovieFrameProbe {
    private let queue = DispatchQueue(label: "CodexWelcome.movie-frames", qos: .userInitiated)
    private var timer: DispatchSourceTimer?
    private var players: [AVPlayer] = []
    private var items: [AVPlayerItem?] = [nil, nil]
    private var outputs: [AVPlayerItemVideoOutput?] = [nil, nil]
    private var began = 0.0, previous = 0.0, maximumGap = 0.0
    private var frames = 0
    func start(tunnel: AVPlayer, orb: AVPlayer) {
        queue.sync {
            players = [tunnel, orb]; began = CACurrentMediaTime(); previous = began
            let source = DispatchSource.makeTimerSource(queue: queue)
            source.schedule(deadline: .now(), repeating: .milliseconds(8), leeway: .milliseconds(1))
            source.setEventHandler { [weak self] in self?.sample() }
            timer = source; source.resume()
        }
    }
    private func sample() {
        let now = CACurrentMediaTime(), active = now - began < 1.6 ? 0 : 1
        // Warm the hidden orb's output too, including AVPlayerLooper item changes.
        // Attaching an output only at the phase boundary measures output setup,
        // rather than playback delivery, and can also compete with first display.
        for index in players.indices {
            guard let current = players[index].currentItem else { continue }
            if current !== items[index] {
                if let output = outputs[index] { items[index]?.remove(output) }
                let output = current.outputs.compactMap { $0 as? AVPlayerItemVideoOutput }.first
                    ?? AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange])
                if !current.outputs.contains(where: { $0 === output }) { current.add(output) }
                outputs[index] = output; items[index] = current
            }
            guard let output = outputs[index] else { continue }
            let time = output.itemTime(forHostTime: now)
            guard output.hasNewPixelBuffer(forItemTime: time),
                  let _ = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) else { continue }
            if index == active { maximumGap = max(maximumGap, now - previous); previous = now; frames += 1 }
        }
    }
    func report() -> [String: Double] {
        queue.sync {
            let elapsed = max(0.001, CACurrentMediaTime() - began)
            return ["frames": Double(frames), "seconds": elapsed, "fps": Double(frames) / elapsed,
                    "maxGapMs": maximumGap * 1000]
        }
    }
    func stop() {
        queue.sync {
            timer?.cancel(); timer = nil
            for index in items.indices { if let output = outputs[index] { items[index]?.remove(output) } }
            items = [nil, nil]; outputs = [nil, nil]; players = []
        }
    }
}

// Each movie is decoded as a bounded frame stream. No 5120x6400 particle
// textures or 4096x8192 orb atlas are decoded/uploaded during startup.
private final class MovieSurface {
    let layer = CALayer()
    let player = AVQueuePlayer()
    private let video = AVPlayerLayer()
    private let poster = CALayer()
    private var looper: AVPlayerLooper?
    private var observations: [NSKeyValueObservation] = []
    private var endObserver: NSObjectProtocol?
    private var preparing = false
    private(set) var ready = false
    var onReady: (() -> Void)?
    var onEnd: (() -> Void)?
    var onFailure: ((String) -> Void)?

    init(movie: URL, posterURL: URL, loop: Bool) throws {
        guard FileManager.default.fileExists(atPath: movie.path),
              let image = NSImage(contentsOf: posterURL),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "CodexWelcome", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "缺少 Mac 动画素材，请重新安装完整应用。"])
        }
        poster.contents = cg
        poster.contentsGravity = .resizeAspect
        layer.addSublayer(poster)
        video.player = player
        video.videoGravity = .resizeAspect
        video.opacity = 0
        layer.addSublayer(video)
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = false
        let item = AVPlayerItem(url: movie)
        if loop { looper = AVPlayerLooper(player: player, templateItem: item) }
        else {
            player.actionAtItemEnd = .pause
            player.insert(item, after: nil)
            endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                object: item, queue: .main) { [weak self] _ in self?.onEnd?() }
        }
        observations.append(video.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] video, _ in
            guard video.isReadyForDisplay else { return }
            DispatchQueue.main.async {
                guard let self = self else { return }
                CATransaction.begin(); CATransaction.setDisableActions(true)
                self.video.opacity = 1
                CATransaction.commit()
            }
        })
        observations.append(player.observe(\.status, options: [.initial, .new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if player.status == .failed { self.onFailure?(player.error?.localizedDescription ?? "视频解码失败"); return }
                guard player.status == .readyToPlay, !self.preparing else { return }
                self.preparing = true
                if let item = player.currentItem {
                    item.add(AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]))
                }
                player.preroll(atRate: 1) { [weak self] success in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        guard success else { self.onFailure?("动画首帧预解码失败"); return }
                        self.ready = true
                        self.onReady?()
                    }
                }
            }
        })
    }

    func layout(_ frame: CGRect) {
        layer.frame = frame
        poster.frame = layer.bounds
        video.frame = layer.bounds
    }

    func stop() { player.pause(); looper?.disableLooping(); player.removeAllItems() }
    deinit { if let observer = endObserver { NotificationCenter.default.removeObserver(observer) }; stop() }
}

final class StartupOrbView: NSView {
    private let orb: MovieSurface
    private let tunnel: MovieSurface
    private var visibleAt = 0.0
    private var orbShownAt = 0.0
    private var preparing = false
    private var collapsing = false
    private var started = false
    private let motion = MovieFrameProbe()
    var onReady: (() -> Void)?
    var onFailure: ((String) -> Void)?
    var rainIsActive: Bool { tunnel.layer.opacity > 0 && orb.layer.opacity == 0 }

    init(frame: NSRect, media: URL, dark: Bool, background: NSColor) throws {
        let theme = dark ? "dark" : "light"
        tunnel = try MovieSurface(movie: media.appendingPathComponent("tunnel-\(theme).mp4"),
                                  posterURL: media.appendingPathComponent("tunnel-\(theme)-poster.png"), loop: false)
        orb = try MovieSurface(movie: media.appendingPathComponent("orb-loop.mp4"),
                              posterURL: media.appendingPathComponent("orb-poster.png"), loop: true)
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = background.cgColor
        layer?.masksToBounds = true
        layer?.addSublayer(tunnel.layer)
        orb.layer.opacity = 0
        orb.layer.masksToBounds = true
        layer?.addSublayer(orb.layer)
        tunnel.onReady = { [weak self] in self?.checkReady() }
        orb.onReady = { [weak self] in self?.checkReady() }
        tunnel.onFailure = { [weak self] message in self?.onFailure?(message) }
        orb.onFailure = { [weak self] message in self?.onFailure?(message) }
    }
    required init?(coder: NSCoder) { fatalError("Not supported") }
    private func checkReady() { if tunnel.ready && orb.ready { onReady?() } }

    override func layout() {
        super.layout()
        let diameter = 280 * min(bounds.width / 1920, bounds.height / 1080)
        let fit = min(bounds.width / 1280, bounds.height / 800)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        tunnel.layout(CGRect(x: bounds.midX - 640 * fit, y: bounds.midY - 400 * fit,
                             width: 1280 * fit, height: 800 * fit))
        orb.layout(CGRect(x: bounds.midX - diameter / 2, y: bounds.midY - diameter / 2,
                          width: diameter, height: diameter))
        orb.layer.cornerRadius = diameter / 2
        CATransaction.commit()
    }

    func startRainFill() {
        guard !started else { return }; started = true
        visibleAt = CACurrentMediaTime()
        motion.start(tunnel: tunnel.player, orb: orb.player)
        tunnel.player.play()
        orb.player.play()
        showOrb()
    }

    private func showOrb() {
        guard orbShownAt == 0 else { return }
        // Schedule the whole native transition on the render server now. A
        // later WKWebView initialization cannot delay the 1.6s phase boundary.
        orbShownAt = visibleAt + 1.6
        CATransaction.begin(); CATransaction.setDisableActions(true)
        tunnel.layer.opacity = 0
        orb.layer.opacity = 1
        CATransaction.commit()
        for (surface, from, to) in [(tunnel.layer, Float(1), Float(0)), (orb.layer, Float(0), Float(1))] {
            let visibility = CABasicAnimation(keyPath: "opacity")
            visibility.fromValue = from; visibility.toValue = to
            visibility.beginTime = orbShownAt; visibility.duration = 0.001
            visibility.fillMode = .both; visibility.isRemovedOnCompletion = false
            surface.add(visibility, forKey: "native-phase")
        }
        let grow = CAKeyframeAnimation(keyPath: "transform")
        grow.values = (0...60).map { index in
            let p = Double(index) / 60, scale = max(0.001, p * p * (3 - 2 * p))
            return NSValue(caTransform3D: CATransform3DMakeScale(scale, scale, 1))
        }
        grow.duration = 0.42
        grow.beginTime = orbShownAt
        grow.fillMode = .both
        grow.isRemovedOnCompletion = false
        orb.layer.add(grow, forKey: "point-to-orb")
    }

    func afterMovingFrames(_ completion: @escaping () -> Void) {
        if motion.report()["frames", default: 0] >= 3 { completion(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in self?.afterMovingFrames(completion) }
    }

    func prepareForContent(completion: @escaping () -> Void) {
        guard !preparing else { return }; preparing = true
        func waitForBloom() {
            if orbShownAt > 0 && CACurrentMediaTime() - orbShownAt >= 0.43 { completion(); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
                guard self != nil else { return }; waitForBloom()
            }
        }
        waitForBloom()
    }

    func collapse(speed: Double, completion: @escaping () -> Void) {
        guard !collapsing else { return }; collapsing = true
        let delay = max(0, 0.54 - (CACurrentMediaTime() - orbShownAt))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            let animation = CAKeyframeAnimation(keyPath: "transform")
            animation.values = (0...32).map { index in
                let p = Double(index) / 32, scale = 1 - (pow(2, 10 * p) - 1) / 1023
                return NSValue(caTransform3D: CATransform3DMakeScale(scale, scale, 1))
            }
            animation.duration = 0.22 / speed
            CATransaction.begin(); CATransaction.setDisableActions(true)
            self.orb.layer.transform = CATransform3DMakeScale(0, 0, 1)
            CATransaction.commit()
            self.orb.layer.add(animation, forKey: "collapse")
            DispatchQueue.main.asyncAfter(deadline: .now() + animation.duration + 1.0 / 120) { completion() }
        }
    }
    func motionReport() -> [String: Double] { let result = motion.report(); motion.stop(); return result }
    func stop() { motion.stop(); tunnel.stop(); orb.stop() }
}
