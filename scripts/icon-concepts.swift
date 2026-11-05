// Old Dominion Eats icon concepts (2026-11-05), drawn in the shared Eats Ranked style (state-prompts/ICON-STYLE.md): one flat, level,
// centred food on Blue Ridge navy #1F3A5F (the prompt's landscape palette), no backing shape, no text or texture, no state seal.
// Food hexes: biscuit gold #D9A35B, country ham #C8505A, ham fat #F6E7D0, shell #E8E4DC, oyster #B9A88C, lemon #F2D046,
// peanut shell #C9955B.
//   A  a country ham biscuit: a split biscuit with a slice of ham, front view
//   B  an oyster on the half shell with a lemon wedge, top view
//   C  a peanut in the shell, lying level
// Usage, from va-eats/: swift scripts/icon-concepts.swift <out dir>   -> concept-{a,b,c}-1024.png
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
}
let NAVY: UInt32 = 0x1F3A5F, BISCUIT: UInt32 = 0xD9A35B, HAM: UInt32 = 0xC8505A, FAT: UInt32 = 0xF6E7D0, SHELL: UInt32 = 0xE8E4DC
let OYSTER: UInt32 = 0xB9A88C, LEMON: UInt32 = 0xF2D046, PEANUT: UInt32 = 0xC9955B

/// A: the ham biscuit. CoreGraphics y-up, s = canvas size. Identical to make-brand.swift's biscuit().
func biscuit(_ c: CGContext, _ s: CGFloat) {
    func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
        CGPath(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s), cornerWidth: r * s, cornerHeight: r * s, transform: nil)
    }
    c.setFillColor(rgb(BISCUIT))
    c.addPath(R(0.18, 0.22, 0.64, 0.20, 0.06)); c.fillPath()          // the bottom half
    c.addPath(R(0.20, 0.54, 0.60, 0.22, 0.10)); c.fillPath()          // the top half, rounder
    c.setFillColor(rgb(HAM)); c.addPath(R(0.14, 0.42, 0.72, 0.12, 0.04)); c.fillPath()   // the slice of country ham, wider than the biscuit
    c.setFillColor(rgb(FAT)); c.fill(CGRect(x: 0.16 * s, y: 0.505 * s, width: 0.68 * s, height: 0.02 * s))   // its fat edge
}

/// B: an oyster on the half shell, a lemon wedge beside it.
func oyster(_ c: CGContext, _ s: CGFloat) {
    c.setFillColor(rgb(SHELL)); c.fillEllipse(in: CGRect(x: 0.14 * s, y: 0.28 * s, width: 0.62 * s, height: 0.44 * s))
    c.setFillColor(rgb(OYSTER)); c.fillEllipse(in: CGRect(x: 0.24 * s, y: 0.36 * s, width: 0.42 * s, height: 0.28 * s))
    let w = CGMutablePath()
    w.move(to: CGPoint(x: 0.66 * s, y: 0.30 * s)); w.addLine(to: CGPoint(x: 0.86 * s, y: 0.30 * s))
    w.addArc(center: CGPoint(x: 0.76 * s, y: 0.30 * s), radius: 0.10 * s, startAngle: 0, endAngle: .pi, clockwise: false); w.closeSubpath()
    c.setFillColor(rgb(LEMON)); c.addPath(w); c.fillPath()
}

/// C: a peanut in the shell, two lobes and a waist, lying level.
func peanut(_ c: CGContext, _ s: CGFloat) {
    c.setFillColor(rgb(PEANUT))
    c.fillEllipse(in: CGRect(x: 0.14 * s, y: 0.31 * s, width: 0.38 * s, height: 0.38 * s))
    c.fillEllipse(in: CGRect(x: 0.48 * s, y: 0.31 * s, width: 0.38 * s, height: 0.38 * s))
    c.fillEllipse(in: CGRect(x: 0.38 * s, y: 0.36 * s, width: 0.24 * s, height: 0.28 * s))
}

func render(_ n: Int, _ path: String, _ draw: (CGContext, CGFloat) -> Void) {
    let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setShouldAntialias(true)
    ctx.setFillColor(rgb(NAVY)); ctx.fill(CGRect(x: 0, y: 0, width: n, height: n))
    draw(ctx, CGFloat(n))
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(d) else { fatalError("could not write \(path)") }
    print("wrote", path)
}
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "playbook/brand"
render(1024, out + "/concept-a-1024.png", biscuit)
render(1024, out + "/concept-b-1024.png", oyster)
render(1024, out + "/concept-c-1024.png", peanut)
