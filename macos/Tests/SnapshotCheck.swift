import AppKit

guard CommandLine.arguments.count == 2,
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
precondition(Double(dark)/Double(count) < 0.01, "The startup frame contains a black surface")
precondition(Double(blue)/Double(count) > 0.05, "The startup frame is missing the blue cloud")
precondition(Double(opaque)/Double(count) > 0.99, "The startup frame is transparent")
print("Startup frame: opaque blue cloud, no black surface PASS (\(image.pixelsWide)x\(image.pixelsHigh))")
