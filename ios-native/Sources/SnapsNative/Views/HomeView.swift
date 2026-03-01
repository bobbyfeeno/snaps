import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var game = ActiveGame()
    @State private var showSetup = false
    @State private var glowPulse = false
    @State private var logoScale: CGFloat = 0.85
    @State private var buttonsOffset: CGFloat = 40
    @State private var buttonsOpacity: Double = 0
    @AppStorage("isDarkMode") private var isDarkMode = true

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            // Background
            theme.bg.ignoresSafeArea()

            // Subtle green glow at top center — very faint texture
            RadialGradient(
                colors: [Color.snapsGreen.opacity(0.04), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 420
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                // Logo / Title
                VStack(spacing: 8) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260, height: 160)
                        .shadow(color: Color.snapsGreen.opacity(glowPulse ? 0.45 : 0.15), radius: 24)
                        .scaleEffect(logoScale)

                    Text("bet that.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                        .opacity(buttonsOpacity)
                }
                .padding(.bottom, 48)

                // Buttons
                VStack(spacing: 14) {
                    // Start Round
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showSetup = true
                    } label: {
                        ZStack {
                            // Flat green fill
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.snapsGreen)

                            // Subtle top highlight
                            LinearGradient(
                                colors: [.white.opacity(0.18), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                            Text("Start Round")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(.black)
                        }
                        .frame(height: 60)
                        .shadow(color: Color.snapsGreen.opacity(glowPulse ? 0.45 : 0.20), radius: 18, y: 6)
                    }
                    .buttonStyle(SnapsButtonStyle())
                    .accessibilityLabel("Start a new golf round")
                    .accessibilityHint("Opens game setup")

                }
                .padding(.horizontal, 32)
                .offset(y: buttonsOffset)
                .opacity(buttonsOpacity)

                Spacer()
                Spacer()
            }
            
            // Dark/Light mode toggle — top right (must be last in ZStack for tap priority)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isDarkMode.toggle()
                        }
                    } label: {
                        Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isDarkMode ? theme.textSecondary : theme.gold)
                            .frame(width: 44, height: 44)
                            .background(theme.surface2, in: Circle())
                            .overlay(Circle().strokeBorder(theme.border, lineWidth: 1))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isDarkMode ? "Switch to light mode" : "Switch to dark mode")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
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
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
        .sheet(isPresented: $showSetup) {
            SetupView(game: game)
        }
    }

    func secondaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(theme.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(SnapsButtonStyle())
    }
}
