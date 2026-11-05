import SwiftUI
import UIKit
import CoreText

/// Virginia palette, a landscape one (provisional, 2026-11-05; Nick decides, playbook/05-naming.md), light only. Loyalties split (no
/// in-state major-league team; UVA navy and orange against Virginia Tech maroon and orange), so the colors come from the land
/// (state-prompts/VIRGINIA_PROMPT.md): Blue Ridge navy #1F3A5F (11.5:1 on white) for titles, tint and accents; cardinal red #B0172B (white
/// on it 7.0:1) for the hand-checked guide cards and honors chips; peanut gold #E4A11B only as a pin and card fill under navy text (5.2:1;
/// as text on white it's 2.2:1); dogwood cream #FBF7EE pages. The names `green`/`gold` are kept from Wisconsin Eats so the shared views
/// read the same; here `green` is Blue Ridge navy and `gold` is cardinal red.
enum Theme {
    static let green = Color(hex: 0x1F3A5F)      // Blue Ridge navy: titles, tint, primary text accents
    static let green2 = Color(hex: 0x2E5480)
    static let gold = Color(hex: 0xB0172B)       // cardinal red: card fills under white text, chips
    static let goldSoft = Color(hex: 0xF5D9DD)   // soft cardinal
    static let lime = Color(hex: 0xE4A11B)       // peanut gold, fills only (hand-checked pins, the title shadow), under navy text
    static let limeSoft = Color(hex: 0xFBEBC6)
    static let sand = Color(hex: 0xFBF7EE)       // the Home background, dogwood cream
    static let red = Color(hex: 0xB0172B)        // honors chips
    static let sandstone = Color(hex: 0x8C1222)  // a darker cardinal accent (9.2:1 on white)
    static let teal = Color(hex: 0x1F6E78)       // Chesapeake accent (5.9:1 on white)
    static let ink = Color(hex: 0x1A1A1A)
    static let ink2 = Color(hex: 0x2E3440)
    static let muted = Color(hex: 0x5B6270)
    static let surface = Color.white
    static let surface2 = Color(hex: 0xF1EEE6)
    static let surface3 = Color(hex: 0xE4DFD3)
    static let rule = Color(hex: 0xE4DFD3)
    static let rule2 = Color(hex: 0xCCC4B3)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// A small uppercase label: "STONE CRAB", "1 MICHELIN STAR".
struct Chip: View {
    enum Style { case gold, green, red, plain, dashed }
    let text: String
    var style: Style = .plain

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.4)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .foregroundStyle(style == .green || style == .red ? Color.white : style == .dashed ? Theme.muted : style == .gold ? Theme.ink : Theme.green)
            .background {
                RoundedRectangle(cornerRadius: 5).fill(style == .gold ? Theme.goldSoft : style == .green ? Theme.green : style == .red ? Theme.red
                                                       : style == .dashed ? .clear : Theme.surface2)
            }
            .overlay {
                if style == .dashed { RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.rule2, style: StrokeStyle(lineWidth: 1, dash: [3, 2])) }
            }
            .accessibilityLabel(text)
    }
}

/// Old Dominion Eats' lettering: the system face drawn compressed and heavy for titles and guide names (like a show poster), and the
/// system monospaced face for numbers, dates and small labels. No bundled fonts.
struct DisplayFont: ViewModifier {
    let size: CGFloat
    var weight: Font.Weight = .black
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content.font(.system(size: size * min(scale, 1.6), weight: weight).width(.compressed))
    }
}

/// Numbers, dates and small labels in the system monospaced face, scaled like DisplayFont.
struct MonoFont: ViewModifier {
    let size: CGFloat
    var weight: Font.Weight = .semibold
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content.font(.system(size: size * min(scale, 1.6), weight: weight, design: .monospaced))
    }
}

extension View {
    func displayFont(_ size: CGFloat, weight: Font.Weight = .black) -> some View {
        modifier(DisplayFont(size: size, weight: weight))
    }

    func monoFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> some View {
        modifier(MonoFont(size: size, weight: weight))
    }
}

/// The header band: three receding Blue Ridge ridgelines, the farthest palest, over a cardinal baseline.
struct Stripes: View {
    var height: CGFloat = 6

    /// (x, rise) for each ridge, back to front: 0 is the baseline, 1 the band's top
    static let ridges: [[(CGFloat, CGFloat)]] = [
        [(0, 0.70), (0.12, 0.85), (0.25, 0.74), (0.40, 1.0), (0.55, 0.80), (0.70, 0.95), (0.85, 0.78), (1, 0.88)],
        [(0, 0.45), (0.15, 0.62), (0.30, 0.50), (0.48, 0.70), (0.62, 0.55), (0.78, 0.68), (0.92, 0.52), (1, 0.58)],
        [(0, 0.22), (0.18, 0.36), (0.35, 0.25), (0.52, 0.40), (0.68, 0.28), (0.84, 0.38), (1, 0.26)]]

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height, base = h * 0.78
            for (i, ridge) in Self.ridges.enumerated() {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: base))
                for (x, rise) in ridge { p.addLine(to: CGPoint(x: x * w, y: base - base * rise)) }
                p.addLine(to: CGPoint(x: w, y: base)); p.closeSubpath()
                ctx.fill(p, with: .color(Theme.green.opacity([0.35, 0.65, 1.0][i])))
            }
            // the cardinal baseline last
            ctx.fill(Path(CGRect(x: 0, y: base, width: w, height: h - base)), with: .color(Theme.gold))
        }
        .frame(height: height * 2.4)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .accessibilityHidden(true)
    }
}

extension View {
    /// An inline navigation title in the display type. UINavigationBar.appearance() didn't reach every SwiftUI bar on iOS 27
    /// (the Map title went from compressed blue to plain black after a push and pop; place titles were always plain), so the
    /// title is our own view in the bar. The navigation title is still set, for the back button and VoiceOver.
    func inlineTitle(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title).displayFont(19, weight: .heavy).foregroundStyle(Theme.green)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }
}
