import AppKit
import QuartzCore

// The render server animates a radial gradient's elliptical end point. AppKit
// no longer redraws a Retina-sized bitmap and constructs a gradient each frame.
final class RevealView: NSView {
    private let gradient = CAGradientLayer()
    var progress: Double = 0 { didSet { update() } }
    init(frame: NSRect, background: NSColor) {
        super.init(frame: frame)
        wantsLayer = true
        gradient.type = .radial
        gradient.colors = [background.withAlphaComponent(0).cgColor,
                           background.withAlphaComponent(0).cgColor, background.cgColor]
        gradient.locations = [0, 0.975, 1]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        layer?.addSublayer(gradient)
        update()
    }
    required init?(coder: NSCoder) { fatalError("Not supported") }
    override var isOpaque: Bool { false }
    override func layout() { super.layout(); update() }
    private func endPoint(_ progress: Double) -> CGPoint {
        let (x, y) = JellyGeometry.radii(progress: progress, width: bounds.width, height: bounds.height)
        return CGPoint(x: 0.5 + x / max(1, bounds.width), y: 0.5 + y / max(1, bounds.height))
    }
    private func update() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        gradient.frame = bounds
        gradient.endPoint = endPoint(progress)
        CATransaction.commit()
    }
    func play(duration: Double, completion: @escaping () -> Void) {
        let animation = CAKeyframeAnimation(keyPath: "endPoint")
        animation.values = (0...120).map { NSValue(point: endPoint(Double($0) / 120)) }
        animation.duration = duration
        animation.calculationMode = .linear
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        gradient.endPoint = endPoint(1)
        gradient.add(animation, forKey: "jelly-reveal")
        CATransaction.commit()
    }
}
