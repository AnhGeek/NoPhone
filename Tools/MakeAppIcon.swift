import AppKit
import CoreGraphics

// NoPhone app icon generator.
//
// The icon is Bloop, drawn from the same tokens as the UI rather than exported
// from a design tool — so a palette change can be re-rendered rather than
// redrawn by hand, and the icon can never quietly drift from the app it sits
// next to.
//
// Regenerate:
//   xcrun swift Tools/MakeAppIcon.swift \
//     NoPhone/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
//
// Values below are mirrored from Shared/DesignSystem/Tokens/Palette.swift.
// Keep them in sync when the palette changes.
let S: CGFloat = 1024

func c(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF)/255,
            green: CGFloat((hex >> 8) & 0xFF)/255,
            blue: CGFloat(hex & 0xFF)/255, alpha: 1)
}
let ink       = c(0x241B4A)
let paper     = c(0xFFFDF7)
let paperTint = c(0xFFF3E2)
let grape     = c(0x9B6BFF)
let grapeUp   = c(0xBFA0FF)
let mint      = c(0x3ED9A4)
let mintUp    = c(0x7BECC4)
let sunshine  = c(0xFFCB3D)

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: Int(S), height: Int(S),
                          bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("no context")
}
// Flip to UIKit-style coordinates so the drawing reads top-down.
ctx.translateBy(x: 0, y: S)
ctx.scaleBy(x: 1, y: -1)

// MARK: Background — the paper gradient the app's canvas uses.
let bg = CGGradient(colorsSpace: cs, colors: [paperTint, paper] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: .zero, end: CGPoint(x: S, y: S), options: [])

// Dotted playground texture.
ctx.setFillColor(c(0x241B4A).copy(alpha: 0.07)!)
let step: CGFloat = 64
var gy = step / 2
while gy < S {
    var gx = step / 2
    while gx < S {
        ctx.fillEllipse(in: CGRect(x: gx - 4, y: gy - 4, width: 8, height: 8))
        gx += step
    }
    gy += step
}

// MARK: Geometry
let cx = S / 2
let cy = S * 0.56          // low, leaving headroom for the antenna
let r  = S * 0.30
let stroke = S * 0.036

// Blob: a circle with gentle wobble, matching Mascot's silhouette.
func blobPath(cx: CGFloat, cy: CGFloat, r: CGFloat, wobble: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let points = 8
    var pts: [CGPoint] = []
    for i in 0..<points {
        let a = CGFloat(i) / CGFloat(points) * .pi * 2 - .pi / 2
        let rr = r * (1 + wobble * sin(CGFloat(i) * 2.0))
        pts.append(CGPoint(x: cx + cos(a) * rr, y: cy + sin(a) * rr))
    }
    p.move(to: midpoint(pts[points - 1], pts[0]))
    for i in 0..<points {
        let cur = pts[i]
        let next = pts[(i + 1) % points]
        p.addQuadCurve(to: midpoint(cur, next), control: cur)
    }
    p.closeSubpath()
    return p
}
func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
    CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
}

// MARK: Antenna — drawn first so the body overlaps its base.
ctx.setStrokeColor(ink)
ctx.setLineWidth(S * 0.026)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: cx, y: cy - r * 0.78))
ctx.addLine(to: CGPoint(x: cx, y: cy - r * 1.30))
ctx.strokePath()

let bulbR = S * 0.048
let bulb = CGRect(x: cx - bulbR, y: cy - r * 1.30 - bulbR, width: bulbR * 2, height: bulbR * 2)
ctx.setFillColor(sunshine)
ctx.fillEllipse(in: bulb)
ctx.setStrokeColor(ink)
ctx.setLineWidth(stroke * 0.72)
ctx.strokeEllipse(in: bulb.insetBy(dx: stroke * 0.36, dy: stroke * 0.36))

// MARK: Sticker shadow — opaque, offset, no blur.
let body = blobPath(cx: cx, cy: cy, r: r, wobble: 0.055)
ctx.saveGState()
ctx.translateBy(x: 0, y: S * 0.022)
ctx.addPath(body)
ctx.setFillColor(ink)
ctx.fillPath()
ctx.restoreGState()

// MARK: Body — grape→mint gradient, the brand pair.
ctx.saveGState()
ctx.addPath(body)
ctx.clip()
let grad = CGGradient(colorsSpace: cs, colors: [mintUp, mint, grape, grapeUp] as CFArray,
                      locations: [0, 0.32, 0.78, 1])!
ctx.drawLinearGradient(grad,
                       start: CGPoint(x: cx - r, y: cy - r),
                       end: CGPoint(x: cx + r, y: cy + r), options: [])
// Top-light sheen.
let sheen = CGGradient(colorsSpace: cs,
                       colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.5),
                                CGColor(red: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
                       locations: [0, 1])!
ctx.drawLinearGradient(sheen, start: CGPoint(x: cx, y: cy - r),
                       end: CGPoint(x: cx, y: cy), options: [])
ctx.restoreGState()

ctx.addPath(body)
ctx.setStrokeColor(ink)
ctx.setLineWidth(stroke)
ctx.strokePath()

// MARK: Face — the .happy mood.
let eyeDX = r * 0.40
let eyeY  = cy - r * 0.10
let eyeW  = S * 0.042
let eyeH  = S * 0.072
ctx.setFillColor(ink)
for sx in [-eyeDX, eyeDX] {
    let e = CGRect(x: cx + sx - eyeW / 2, y: eyeY - eyeH / 2, width: eyeW, height: eyeH)
    ctx.addPath(CGPath(roundedRect: e, cornerWidth: eyeW / 2, cornerHeight: eyeW / 2,
                       transform: nil))
    ctx.fillPath()
    // Catchlight.
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: cx + sx + eyeW * 0.06, y: eyeY - eyeH * 0.30,
                               width: eyeW * 0.34, height: eyeW * 0.34))
    ctx.setFillColor(ink)
}

// Smile — an open arc, round caps, same as Mascot's happy mouth.
ctx.setStrokeColor(ink)
ctx.setLineWidth(S * 0.034)
ctx.setLineCap(.round)
let mouthR = r * 0.40
ctx.addArc(center: CGPoint(x: cx, y: cy + r * 0.16), radius: mouthR,
           startAngle: .pi * 0.16, endAngle: .pi * 0.84, clockwise: false)
ctx.strokePath()

// MARK: Write
guard let image = ctx.makeImage() else { fatalError("no image") }
let rep = NSBitmapImageRep(cgImage: image)
rep.size = NSSize(width: S, height: S)
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("no png") }
let out = CommandLine.arguments[1]
try! data.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
