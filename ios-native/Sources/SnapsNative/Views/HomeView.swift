import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RoundRecord.date, order: .reverse) private var rounds: [RoundRecord]
    @State private var game = ActiveGame()
    @State private var showSetup = false
    @State private var showHistory = false
    @State private var showPlayers = false
    @State private var glowPulse = false
    @State private var logoScale: CGFloat = 0.85
    @State private var buttonsOffset: CGFloat = 40
    @State private var buttonsOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Radial glow behind logo
            RadialGradient(
                colors: [Color(hex: "#39FF14").opacity(0.08), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo / Title
                VStack(spacing: 8) {
                    Text("SNAPS")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#60FF28"), Color(hex: "#1a7005")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color(hex: "#39FF14").opacity(glowPulse ? 0.9 : 0.3), radius: 20)
                        .scaleEffect(logoScale)

                    Text("Golf Betting Scorecard")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.gray)
                        .opacity(buttonsOpacity)
                }
                .padding(.bottom, 48)

                // Recent round summary
                if let lastRound = rounds.first {
                    recentRoundChip(round: lastRound)
                        .opacity(buttonsOpacity)
                        .padding(.bottom, 24)
                }

                // Buttons
                VStack(spacing: 14) {
                    // Start Round
                    Button {
                        showSetup = true
                    } label: {
                        ZStack {
                            LinearGradient(
                                colors: [Color(hex: "#60FF28"), Color(hex: "#28a808"), Color(hex: "#1a7005")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                            // Specular
                            LinearGradient(
                                colors: [.white.opacity(0.4), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                            Text("Start Round")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(.black)
                        }
                        .frame(height: 60)
                        .shadow(color: Color(hex: "#39FF14").opacity(glowPulse ? 0.7 : 0.3), radius: 20, y: 8)
                    }
                    .buttonStyle(SpringButtonStyle())

                    // Secondary buttons
                    HStack(spacing: 12) {
                        secondaryButton("Past Rounds", icon: "clock.arrow.trianglehead.counterclockwise.rotate.90") {
                            showHistory = true
                        }
                        secondaryButton("Players", icon: "person.2.fill") {
                            showPlayers = true
                        }
                    }
                }
                .padding(.horizontal, 32)
                .offset(y: buttonsOffset)
                .opacity(buttonsOpacity)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6)) {
                logoScale = 1.0
            }
            withAnimation(.spring(duration: 0.5).delay(0.4)) {
                buttonsOffset = 0
                buttonsOpacity = 1
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
        .sheet(isPresented: $showSetup) {
            SetupView(game: game)
        }
        .sheet(isPresented: $showHistory) {
            HistoryView()
        }
        .sheet(isPresented: $showPlayers) {
            PlayersView()
        }
    }

    func recentRoundChip(round: RoundRecord) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .foregroundStyle(Color(hex: "#39FF14"))
                .font(.system(size: 14))

            if let winner = round.winner {
                Text("\(winner.name) won $\(String(format: "%.0f", winner.netAmount))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Text(round.date, style: .relative)
                .font(.system(size: 11))
                .foregroundStyle(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(hex: "#39FF14").opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 32)
    }

    func secondaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(Color(hex: "#c0c0c0"))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#1a1a1a"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(SpringButtonStyle())
    }
}

// MARK: - Spring Button Style
struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
