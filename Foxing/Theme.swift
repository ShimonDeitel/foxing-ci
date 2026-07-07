import SwiftUI

// Foxing palette: crisp paper white + bold forest-green ink accent.
// The aging gimmick (parchment yellow -> deep umber) is reserved strictly for
// invoice CARDS as they age, never used as the app's own chrome/accent, so the
// brand identity stays sharp and distinct from any cream/amber "luxury" sibling.
enum FoxingPalette {
    static let ink = Color(red: 0x0F / 255, green: 0x3F / 255, blue: 0x2E / 255)      // deep forest-green ink
    static let inkBright = Color(red: 0x1E / 255, green: 0x6B / 255, blue: 0x4A / 255) // brighter green accent
    static let paper = Color(red: 0xFC / 255, green: 0xFC / 255, blue: 0xF9 / 255)     // crisp fresh paper
    static let paperShadow = Color(red: 0x2A / 255, green: 0x2A / 255, blue: 0x24 / 255)
    static let stampRed = Color(red: 0x8C / 255, green: 0x1D / 255, blue: 0x1D / 255)

    // Aging ramp: fresh white -> pale straw -> parchment yellow -> deep umber/brown
    static func agedTint(fraction: Double) -> Color {
        let f = min(max(fraction, 0), 1)
        let fresh = (r: 0xFC, g: 0xFC, b: 0xF9)
        let umber = (r: 0x8A, g: 0x6A, b: 0x3A)
        let r = Double(fresh.r) + (Double(umber.r) - Double(fresh.r)) * f
        let g = Double(fresh.g) + (Double(umber.g) - Double(fresh.g)) * f
        let b = Double(fresh.b) + (Double(umber.b) - Double(fresh.b)) * f
        return Color(red: r / 255, green: g / 255, blue: b / 255)
    }
}

// Maps an aging bucket to a 0...1 "age fraction" driving tint/curl/shadow intensity.
extension AgingBucket {
    var ageFraction: Double {
        switch self {
        case .current: return 0.0
        case .days1to30: return 0.30
        case .days31to60: return 0.55
        case .days61to90: return 0.78
        case .days90plus: return 1.0
        }
    }

    var label: String {
        switch self {
        case .current: return "Current"
        case .days1to30: return "1-30 Days Overdue"
        case .days31to60: return "31-60 Days Overdue"
        case .days61to90: return "61-90 Days Overdue"
        case .days90plus: return "90+ Days Overdue"
        }
    }
}

/// A visual modifier that "ages" a card: yellowing tint, a subtle corner curl
/// (achieved via rotation + anchor + shadow, no image assets), and deepening shadow.
struct AgedPaperCard: ViewModifier {
    let ageFraction: Double

    func body(content: Content) -> some View {
        let curl = ageFraction * 3.2       // degrees of corner curl
        let shadowRadius = 2 + ageFraction * 7
        let shadowOpacity = 0.10 + ageFraction * 0.28
        let tint = FoxingPalette.agedTint(fraction: ageFraction)

        return content
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint)
            )
            .overlay(
                // subtle corner-curl highlight in the bottom-trailing corner
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FoxingPalette.paperShadow.opacity(0.06 + ageFraction * 0.18), lineWidth: 1)
            )
            .rotation3DEffect(
                .degrees(curl),
                axis: (x: 0, y: 1, z: 0.15),
                anchor: .bottomTrailing,
                perspective: 0.35
            )
            .shadow(color: FoxingPalette.paperShadow.opacity(shadowOpacity), radius: shadowRadius, x: 2, y: 4)
    }
}

extension View {
    func agedPaperCard(ageFraction: Double) -> some View {
        modifier(AgedPaperCard(ageFraction: ageFraction))
    }

    /// Real tap-anywhere-to-dismiss-keyboard gesture (per keyboard-dismiss-tap-outside memory).
    /// Uses simultaneousGesture so it never swallows taps meant for rows/buttons underneath.
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(TapGesture().onEnded {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        })
    }
}

/// The "PAID" ink-stamp animation state + view.
struct PaidStampView: View {
    @State private var scale: CGFloat = 2.4
    @State private var rotation: Double = -28
    @State private var opacity: Double = 0

    var body: some View {
        Text("PAID")
            .font(.system(size: 34, weight: .black, design: .serif))
            .tracking(4)
            .foregroundStyle(FoxingPalette.stampRed)
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(FoxingPalette.stampRed, lineWidth: 4)
            )
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.interpolatingSpring(stiffness: 220, damping: 12)) {
                    scale = 1.0
                    rotation = -16
                    opacity = 1
                }
            }
    }
}
