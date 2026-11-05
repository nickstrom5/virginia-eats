// Old Dominion Eats brand (provisional, 2026-11-05; Nick picks the name, icon and palette): the app icon is concept A of
// scripts/icon-concepts.swift, a country ham biscuit, on Blue Ridge navy; the shared Eats Ranked icon style, state-prompts/ICON-STYLE.md,
// no backing shape. No state seal (it fills the flag), no team or school marks, no "Virginia is for Lovers" play.
// Usage, from va-eats/: swift scripts/make-brand.swift   -> VirginiaEats/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png,
// docs/ favicons and touch icons, docs/og.png. scripts/make-site.py draws the same mark as its inline SVG: change both together.
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
}
let NAVY: UInt32 = 0x1F3A5F, BISCUIT: UInt32 = 0xD9A35B, HAM: UInt32 = 0xC8505A, FAT: UInt32 = 0xF6E7D0
let CARDINAL: UInt32 = 0xB0172B, CREAM: UInt32 = 0xFBF7EE

/// A: the ham biscuit. CoreGraphics y-up, s = canvas size. Identical to icon-concepts.swift's concept A.
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


func render(_ n: Int, _ path: String, background: Bool) {
    let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: background ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setShouldAntialias(true)
    if background { ctx.setFillColor(rgb(NAVY)); ctx.fill(CGRect(x: 0, y: 0, width: n, height: n)) }
    biscuit(ctx, CGFloat(n))
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(d) else { fatalError("could not write \(path)") }
    print("wrote", path)
}
render(1024, "VirginiaEats/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png", background: true)
try? FileManager.default.createDirectory(atPath: "docs", withIntermediateDirectories: true)
for (n, name) in [(512, "icon-512.png"), (192, "icon-192.png"), (180, "apple-touch-icon.png"), (32, "favicon-32.png")] {
    render(n, "docs/" + name, background: true)
}

/// The share image (1200 x 630): navy, the biscuit at the left, the name and tagline at the right, and the app's header band along the
/// bottom: three receding Blue Ridge ridgelines over a cardinal baseline, on cream (Theme.swift's Stripes.ridges).
func og(_ path: String) {
    let W = 1200, H = 630
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setShouldAntialias(true)
    ctx.setFillColor(rgb(NAVY)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    let band: CGFloat = 70, base: CGFloat = 14
    ctx.setFillColor(rgb(CREAM)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: Int(band)))
    let ridges: [[(CGFloat, CGFloat)]] = [
        [(0, 0.70), (0.12, 0.85), (0.25, 0.74), (0.40, 1.0), (0.55, 0.80), (0.70, 0.95), (0.85, 0.78), (1, 0.88)],
        [(0, 0.45), (0.15, 0.62), (0.30, 0.50), (0.48, 0.70), (0.62, 0.55), (0.78, 0.68), (0.92, 0.52), (1, 0.58)],
        [(0, 0.22), (0.18, 0.36), (0.35, 0.25), (0.52, 0.40), (0.68, 0.28), (0.84, 0.38), (1, 0.26)]]
    for (i, ridge) in ridges.enumerated() {
        let p = CGMutablePath(); p.move(to: CGPoint(x: 0, y: base))
        for (x, rise) in ridge { p.addLine(to: CGPoint(x: x * CGFloat(W), y: base + (band - base) * rise)) }
        p.addLine(to: CGPoint(x: CGFloat(W), y: base)); p.closeSubpath()
        ctx.setFillColor(rgb(NAVY).copy(alpha: [0.35, 0.65, 1.0][i])!); ctx.addPath(p); ctx.fillPath()
    }
    ctx.setFillColor(rgb(CARDINAL)); ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(W), height: base))
    ctx.saveGState(); ctx.translateBy(x: 40, y: 90); biscuit(ctx, 500); ctx.restoreGState()
    let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ns
    let title = NSFont(name: "AvenirNextCondensed-Heavy", size: 80) ?? NSFont.boldSystemFont(ofSize: 70)
    let sub = NSFont(name: "AvenirNextCondensed-DemiBold", size: 34) ?? NSFont.boldSystemFont(ofSize: 30)
    NSAttributedString(string: "OLD DOMINION", attributes: [.font: title, .foregroundColor: NSColor.white]).draw(at: NSPoint(x: 560, y: 380))
    NSAttributedString(string: "EATS", attributes: [.font: title, .foregroundColor: NSColor.white]).draw(at: NSPoint(x: 560, y: 296))
    NSAttributedString(string: "HAM BISCUITS, OYSTERS & POLLO", attributes: [.font: sub, .foregroundColor: NSColor(srgbRed: 0.894, green: 0.631, blue: 0.106, alpha: 1)]).draw(at: NSPoint(x: 564, y: 246))
    NSGraphicsContext.restoreGraphicsState()
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(d) else { fatalError("could not write \(path)") }
    print("wrote", path)
}
og("docs/og.png")
