import AppKit
import AVFoundation

@main struct RendererCheck {
    static func main() throws {
        let media = URL(fileURLWithPath: CommandLine.arguments[1])
        for (name, width, height, duration) in [("tunnel-dark", 1280, 800, 1.6), ("tunnel-light", 1280, 800, 1.6), ("orb-loop", 512, 512, 128.0 / 120)] {
            let asset = AVURLAsset(url: media.appendingPathComponent(name + ".mp4"))
            let track = asset.tracks(withMediaType: .video).first!
            precondition(track.naturalSize == CGSize(width: CGFloat(width), height: CGFloat(height)))
            precondition(abs(track.nominalFrameRate - 120) < 0.1)
            precondition(abs(asset.duration.seconds - duration) < 0.02)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            let first = try generator.copyCGImage(at: .zero, actualTime: nil)
            let later = try generator.copyCGImage(at: CMTime(seconds: 0.6, preferredTimescale: 600), actualTime: nil)
            precondition((first.dataProvider!.data! as Data) != (later.dataProvider!.data! as Data), "Movie does not move")
        }
        print("Mac movies: dimensions, 120 fps, duration and distinct decoded frames PASS")

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let view = RevealView(frame: NSRect(x: 0, y: 0, width: 640, height: 400), background: .white)
        func alpha(_ x: Int, _ y: Int, progress: Double) -> UInt8 {
            view.progress = progress; view.layoutSubtreeIfNeeded()
            let context = CGContext(data: nil, width: 640, height: 400, bitsPerComponent: 8, bytesPerRow: 640 * 4,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.clear(CGRect(x: 0, y: 0, width: 640, height: 400))
            view.layer!.render(in: context)
            return context.data!.assumingMemoryBound(to: UInt8.self)[(y * 640 + x) * 4 + 3]
        }
        precondition(alpha(5, 5, progress: 0) > 250, "Initial cover is not opaque")
        precondition(alpha(320, 200, progress: 0.5) < 5, "Reveal center is not transparent")
        precondition(alpha(5, 5, progress: 0.5) > 250, "Reveal clears the corners too soon")
        precondition(alpha(5, 5, progress: 1) < 5, "Final reveal leaves an opaque corner")
        print("GPU reveal: opaque start, transparent center and clear final corners PASS")

        var warmupTicks = 0, ticks = 0, started = false, complete = false
        let worker = DesktopPreparation()
        // Start the measured wait only after AppKit's run loop is ticking.
        // First-use AVFoundation/layer initialization can otherwise consume
        // the entire unit-test interval before its first timer is delivered.
        let timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            if started { ticks += 1; return }
            warmupTicks += 1
            if warmupTicks == 5 {
                started = true
                worker.request(pid: 0, frame: .zero, maximize: false, simulatedDelay: 0.4) { _ in complete = true }
            }
        }
        let deadline = Date().addingTimeInterval(5)
        while !complete && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
        timer.invalidate()
        print("Desktop worker heartbeat: \(ticks) ticks during slow response")
        precondition(complete && ticks >= 8, "Desktop preparation blocked the animation thread")
        print("Desktop preparation: slow response leaves main run loop responsive PASS")
    }
}
