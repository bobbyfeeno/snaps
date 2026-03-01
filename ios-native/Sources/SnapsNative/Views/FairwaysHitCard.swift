import SwiftUI

// MARK: - Fairway Stats Model
struct FairwayStats {
    let hit: Int
    let left: Int
    let right: Int
    let obLeft: Int
    let obRight: Int
    let short: Int
    let total: Int
    
    func pct(_ value: Int) -> Int {
        total > 0 ? Int(round(Double(value) / Double(total) * 100)) : 0
    }
}

// MARK: - Fairways Hit Card (Profile View — same visual as scorecard)
struct FairwaysHitCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let stats: FairwayStats
    
    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Fairways Hit")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text("\(stats.hit)/\(stats.total)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textMuted)
            }
            
            // Big percentage
            Text("\(stats.pct(stats.hit))%")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(Color.grassHit)
            
            // Fairway visualization with stats
            ZStack {
                // Deep rough background
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: isDark
                                ? [Color.grassDark1, Color.grassDark2]
                                : [Color.grassMid1, Color.grassMid2],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                
                // Tapered fairway
                FairwayShape()
                    .fill(
                        LinearGradient(
                            colors: isDark
                                ? [Color(hex: "#3A6B3A"), Color(hex: "#4A8A4A"), Color(hex: "#5A9D5A"), Color(hex: "#4A8A4A")]
                                : [Color(hex: "#6BAF6B"), Color(hex: "#7EC47E"), Color(hex: "#8FD48F"), Color(hex: "#7EC47E")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .padding(.horizontal, 32)
                    .padding(.top, 10)
                    .padding(.bottom, 36)
                
                // Mow lines
                FairwayShape()
                    .fill(
                        LinearGradient(
                            colors: Array(repeating: [Color.white.opacity(0.04), Color.clear], count: 6).flatMap { $0 },
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .padding(.horizontal, 32)
                    .padding(.top, 10)
                    .padding(.bottom, 36)
                
                // Zone labels with percentages
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            // OB Left
                            statZone("OB\nLeft", pct: stats.pct(stats.obLeft), w: w * 0.17, h: h - 34, danger: true)
                            
                            // Left
                            statZone("Left", pct: stats.pct(stats.left), w: w * 0.17, h: h - 34, danger: false)
                            
                            // Hit (center circle)
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 60, height: 60)
                                        .shadow(color: Color.grassHit.opacity(0.4), radius: 12)
                                    
                                    Circle()
                                        .fill(Color.white.opacity(0.95))
                                        .frame(width: 54, height: 54)
                                    
                                    VStack(spacing: 0) {
                                        Text("Hit")
                                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Color(hex: "#2E7D32").opacity(0.7))
                                        Text("\(stats.pct(stats.hit))%")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color(hex: "#2E7D32"))
                                    }
                                }
                            }
                            .frame(width: w * 0.32, height: h - 34)
                            
                            // Right
                            statZone("Right", pct: stats.pct(stats.right), w: w * 0.17, h: h - 34, danger: false)
                            
                            // OB Right
                            statZone("OB\nRight", pct: stats.pct(stats.obRight), w: w * 0.17, h: h - 34, danger: true)
                        }
                        
                        // Short zone
                        HStack(spacing: 6) {
                            Text("Short")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                            Text("\(stats.pct(stats.short))%")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            Color(hex: "#2A3F2A").opacity(0.6),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .padding(.horizontal, 16)
                    }
                }
                
                // Flag pin
                VStack(spacing: 0) {
                    FlagPin()
                        .frame(width: 16, height: 28)
                    Spacer()
                }
                .padding(.top, 2)
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.surface1)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        )
    }
    
    // Stat zone with label + percentage
    private func statZone(_ label: String, pct: Int, w: CGFloat, h: CGFloat, danger: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(2)
            Text("\(pct)%")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(danger && pct > 0 ? Color.red.opacity(0.9) : .white.opacity(0.9))
        }
        .frame(width: w, height: h)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.snapsBg.ignoresSafeArea()
        FairwaysHitCard(stats: FairwayStats(
            hit: 14, left: 2, right: 1, obLeft: 0, obRight: 1, short: 0, total: 18
        ))
        .padding(20)
    }
    .preferredColorScheme(.dark)
}
