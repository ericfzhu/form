// Run from the repository root: swift tools/render-counterweight-mark.swift
// Vector companion to the generated app icon. Keep paths aligned with
// CounterweightActivityMark in FormLiveActivity.swift.
import AppKit

let ink = CGColor(red: 5/255, green: 18/255, blue: 48/255, alpha: 1)
let blue = CGColor(red: 151/255, green: 172/255, blue: 200/255, alpha: 1)
func drawMark(_ context: CGContext, size: CGFloat) {
    context.saveGState()
    context.scaleBy(x: size / 100, y: size / 100)
    let hood = CGMutablePath()
    hood.move(to: CGPoint(x: 5, y: 70))
    hood.addCurve(to: CGPoint(x: 60, y: 10), control1: CGPoint(x: 10, y: 39), control2: CGPoint(x: 34, y: 8))
    hood.addCurve(to: CGPoint(x: 96, y: 72), control1: CGPoint(x: 84, y: 9), control2: CGPoint(x: 92, y: 42))
    hood.addCurve(to: CGPoint(x: 5, y: 70), control1: CGPoint(x: 100, y: 94), control2: CGPoint(x: 2, y: 96))
    context.addPath(hood); context.setFillColor(blue); context.fillPath()
    let face = CGMutablePath()
    face.move(to: CGPoint(x: 19, y: 66))
    face.addCurve(to: CGPoint(x: 60, y: 23), control1: CGPoint(x: 24, y: 43), control2: CGPoint(x: 41, y: 22))
    face.addCurve(to: CGPoint(x: 82, y: 65), control1: CGPoint(x: 75, y: 23), control2: CGPoint(x: 81, y: 47))
    face.addCurve(to: CGPoint(x: 19, y: 66), control1: CGPoint(x: 85, y: 79), control2: CGPoint(x: 15, y: 80))
    context.addPath(face); context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fillPath()
    context.setFillColor(ink)
    context.fillEllipse(in: CGRect(x: 40, y: 48, width: 8, height: 15))
    context.fillEllipse(in: CGRect(x: 61, y: 47, width: 8, height: 15))
    context.restoreGState()
}
func render(width: Int, height: Int, path: String, draw: (CGContext) -> Void) throws {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
    draw(context)
    let image = NSBitmapImageRep(cgImage: context.makeImage()!)
    try image.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
for size in [16, 32, 48] {
    try render(width: size, height: size, path: "public/brand/favicon-\(size).png") { drawMark($0, size: CGFloat(size)) }
}
try FileManager.default.removeItem(atPath: "public/favicon-32.png")
try FileManager.default.copyItem(atPath: "public/brand/favicon-32.png", toPath: "public/favicon-32.png")
try render(width: 384, height: 144, path: "public/brand/favicon-size-check.png") { context in
    context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 384, height: 144))
    for (index, size) in [16, 32, 48].enumerated() {
        context.saveGState(); context.translateBy(x: CGFloat(index * 128 + 64 - size / 2), y: CGFloat(72 - size / 2))
        drawMark(context, size: CGFloat(size)); context.restoreGState()
    }
}
let svg = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" role="img" aria-labelledby="title">
  <title id="title">Form — Counterweight</title>
  <path fill="#97acc8" d="M5 70C10 39 34 8 60 10C84 9 92 42 96 72C100 94 2 96 5 70Z"/>
  <path fill="#fff" d="M19 66C24 43 41 22 60 23C75 23 81 47 82 65C85 79 15 80 19 66Z"/>
  <g fill="#051230"><ellipse cx="44" cy="55.5" rx="4" ry="7.5"/><ellipse cx="65" cy="54.5" rx="4" ry="7.5"/></g>
</svg>
"""
for path in ["public/favicon.svg", "public/form-icon.svg", "public/brand/form-icon.svg"] {
    try (svg + "\n").write(toFile: path, atomically: true, encoding: .utf8)
}
