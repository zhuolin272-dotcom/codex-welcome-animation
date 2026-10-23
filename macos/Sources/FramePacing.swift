import AppKit
import QuartzCore

final class FramePacing: NSObject {
    private var link: CADisplayLink?
    private var began = 0.0, previous = 0.0, maximumGap = 0.0
    private var frames = 0
    func start(view: NSView) {
        stop()
        began = CACurrentMediaTime(); previous = began; frames = 0; maximumGap = 0
        link = view.displayLink(target: self, selector: #selector(tick(_:)))
        link?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
        link?.add(to: .main, forMode: .common)
    }
    @objc private func tick(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        maximumGap = max(maximumGap, now - previous); previous = now; frames += 1
    }
    func report() -> [String: Double] {
        let elapsed = max(0.001, CACurrentMediaTime() - began)
        return ["frames": Double(frames), "seconds": elapsed, "fps": Double(frames) / elapsed,
                "maxGapMs": maximumGap * 1000]
    }
    func stop() { link?.invalidate(); link = nil }
}
