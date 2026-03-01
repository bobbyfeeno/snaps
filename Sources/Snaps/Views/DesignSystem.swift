import SwiftUI

// MARK: - Theme Colors (responds to colorScheme)
struct SnapsTheme {
    let colorScheme: ColorScheme
    
    // Backgrounds
    var bg: Color { colorScheme == .dark ? Color(hex: "#080808") : Color(hex: "#F8F8F8") }
    var surface1: Color { colorScheme == .dark ? Color(hex: "#111111") : Color(hex: "#FFFFFF") }
    var surface2: Color { colorScheme == .dark ? Color(hex: "#1A1A1A") : Color(hex: "#F0F0F0") }
    var surface3: Color { colorScheme == .dark ? Color(hex: "#242424") : Color(hex: "#E8E8E8") }
    var border: Color { colorScheme == .dark ? Color(hex: "#2C2C2C") : Color(hex: "#E0E0E0") }
    
    // Text
    var textPrimary: Color { colorScheme == .dark ? Color(hex: "#F5F5F5") : Color(hex: "#1A1A1A") }
    var textSecondary: Color { colorScheme == .dark ? Color(hex: "#737373") : Color(hex: "#6B6B6B") }
    var textMuted: Color { colorScheme == .dark ? Color(hex: "#404040") : Color(hex: "#A0A0A0") }
    
    // Score colors
    var scorePar: Color { colorScheme == .dark ? Color(hex: "#F5F5F5") : Color(hex: "#1A1A1A") }
    
    // Accents — same in both modes
    let green = Color(hex: "#22C55E")
    let neon = Color(hex: "#39FF14")
    let danger = Color(hex: "#EF4444")
    let gold = Color(hex: "#F59E0B")
    let venmo = Color(hex: "#3D95CE")
    let cashApp = Color(hex: "#00D632")
    let scoreEagle = Color(hex: "#F59E0B")
    let scoreBirdie = Color(hex: "#22C55E")
    let scoreBogey = Color(hex: "#EF4444").opacity(0.7)
    let scoreDouble = Color(hex: "#EF4444")
}

// MARK: - Environment Key
private struct ThemeKey: EnvironmentKey {
    static let defaultValue = SnapsTheme(colorScheme: .dark)
}

extension EnvironmentValues {
    var theme: SnapsTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Legacy static colors (for gradual migration)
// These still work but won't update dynamically
extension Color {
    static let snapsBg       = Color(hex: "#080808")
    static let snapsSurface1 = Color(hex: "#111111")
    static let snapsSurface2 = Color(hex: "#1A1A1A")
    static let snapsSurface3 = Color(hex: "#242424")
    static let snapsBorder   = Color(hex: "#2C2C2C")
    static let snapsGreen    = Color(hex: "#22C55E")
    static let snapsNeon     = Color(hex: "#39FF14")
    static let snapsDanger   = Color(hex: "#EF4444")
    static let snapsGold     = Color(hex: "#F59E0B")
    static let snapsVenmo    = Color(hex: "#3D95CE")
    static let snapsCashApp  = Color(hex: "#00D632")
    static let snapsTextPrimary   = Color(hex: "#F5F5F5")
    static let snapsTextSecondary = Color(hex: "#737373")
    static let snapsTextMuted     = Color(hex: "#404040")
    static let scoreEagle  = Color(hex: "#F59E0B")
    static let scoreBirdie = Color(hex: "#22C55E")
    static let scorePar    = Color(hex: "#F5F5F5")
    static let scoreBogey  = Color(hex: "#EF4444").opacity(0.7)
    static let scoreDouble = Color(hex: "#EF4444")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255,
                  blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Typography
extension Font {
    static let snapsHero         = Font.system(size: 56, weight: .black, design: .default)
    static let snapsTitle        = Font.system(size: 28, weight: .bold)
    static let snapsSectionHeader = Font.system(size: 13, weight: .semibold)
    static let snapsCardTitle    = Font.system(size: 17, weight: .semibold)
    static let snapsBody         = Font.system(size: 15, weight: .regular)
    static let snapsScoreNumber  = Font.system(size: 22, weight: .bold, design: .monospaced)
    static let snapsLabel        = Font.system(size: 12, weight: .medium)
}

// MARK: - Button Style
struct SnapsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Card Modifier
struct SnapsCard: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var accentColor: Color = .clear

    func body(content: Content) -> some View {
        let theme = SnapsTheme(colorScheme: colorScheme)
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.surface1)
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 1)
                            .padding(.horizontal, 1)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                accentColor == .clear ? theme.border : accentColor.opacity(0.3),
                                lineWidth: 1
                            )
                    }
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.15), radius: 12, y: 4)
    }
}

extension View {
    func snapsCard(accent: Color = .clear) -> some View {
        modifier(SnapsCard(accentColor: accent))
    }
}
