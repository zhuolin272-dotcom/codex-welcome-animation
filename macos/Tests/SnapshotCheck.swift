import AppKit

guard (2...4).contains(CommandLine.arguments.count),
      let data = try? Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])),
      let image = NSBitmapImageRep(data: data),
      image.pixelsWide >= 100, image.pixelsHigh >= 100 else { fatalError("Missing startup first-frame image") }
var count = 0, dark = 0, blue = 0, opaque = 0
for row in 0..<24 {
    for column in 0..<32 {
        let x = (column*2+1)*image.pixelsWide/64
        let y = (row*2+1)*image.pixelsHigh/48
        guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { fatalError("Invalid startup pixel") }
        count += 1
        if max(color.redComponent, color.greenComponent, color.blueComponent) < 0.12 { dark += 1 }
        if color.blueComponent > color.redComponent+0.03 && color.blueComponent >= color.greenComponent-0.02 { blue += 1 }
        if color.alphaComponent > 0.98 { opaque += 1 }
    }
}
let darkTheme = CommandLine.arguments.contains("--dark")
precondition(darkTheme ? Double(dark)/Double(count) > 0.85 : Double(dark)/Double(count) < 0.01, "Startup background does not match the selected appearance")
let handoff = CommandLine.arguments.contains("--handoff")
let center = image.colorAt(x: image.pixelsWide/2, y: image.pixelsHigh/2)!.usingColorSpace(.deviceRGB)!
if handoff {
    precondition(blue == 0, "A second orb appears at the logo handoff")
    precondition(darkTheme ? center.redComponent < 0.08 && center.greenComponent < 0.08 : center.redComponent > 0.9 && center.greenComponent > 0.9, "Logo handoff theme mismatch")
} else {
    precondition(Double(blue)/Double(count) > 0.008, "Missing native blue cloud")
    precondition(Double(blue)/Double(count) < 0.12, "The native orb fills too much of the screen")
    precondition(center.blueComponent > center.redComponent + 0.03, "Missing centered blue orb")
}
precondition(Double(opaque)/Double(count) > 0.99, "The startup frame is transparent")
for (x, y) in [(0, 0), (image.pixelsWide-1, 0), (0, image.pixelsHigh-1), (image.pixelsWide-1, image.pixelsHigh-1)] {
    let c = image.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
    precondition(darkTheme ? max(c.redComponent, c.greenComponent, c.blueComponent) < 0.08 : min(c.redComponent, c.greenComponent, c.blueComponent) > 0.9, "Startup corner theme mismatch")
}
print("Startup frame: native orb / invisible web handoff, no black surface PASS (\(image.pixelsWide)x\(image.pixelsHigh))")
