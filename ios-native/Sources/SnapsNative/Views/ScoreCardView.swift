import SwiftUI

struct ScoreCardView: View {
    @Bindable var game: ActiveGame
    @Environment(\.dismiss) private var dismiss
    @State private var showResults = false
    @State private var showGrid = false

    var setup: GameSetup { game.setup! }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerBar

                // Hole cards (swipeable)
                TabView(selection: $game.currentHole) {
                    ForEach(0..<18, id: \.self) { hole in
                        HoleCard(game: game, hole: hole, setup: setup)
                            .tag(hole)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Footer
                footerBar
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showGrid) {
            ScorecardGridView(game: game, setup: setup)
        }
        .sheet(isPresented: $showResults) {
            ResultsView(game: game)
        }
    }

    var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08), in: Circle())
            }

            Spacer()

            // Hole indicator dots
            HStack(spacing: 4) {
                ForEach(0..<18, id: \.self) { i in
                    Circle()
                        .fill(i == game.currentHole ? Color(hex: "#39FF14") : Color.gray.opacity(0.3))
                        .frame(width: i == game.currentHole ? 8 : 5, height: i == game.currentHole ? 8 : 5)
                }
            }

            Spacer()

            // Hole number + grid toggle
            HStack(spacing: 8) {
                Text("H\(game.currentHole + 1)")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color(hex: "#39FF14"))

                Button {
                    showGrid = true
                } label: {
                    Image(systemName: "tablecells")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.gray)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    var footerBar: some View {
        VStack(spacing: 12) {
            // Running totals
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(setup.players) { player in
                        let total = game.totalScore(playerId: player.id)
                        let hasScores = game.scores[player.id]?.compactMap { $0 }.isEmpty == false
                        VStack(spacing: 2) {
                            Text(player.name)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.gray)
                            Text(hasScores ? "\(total)" : "—")
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(total < player.taxMan && hasScores ? Color(hex: "#39FF14") : .white)
                        }
                        .frame(minWidth: 48)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 16)
            }

            // Calculate / Next hole
            HStack(spacing: 12) {
                if game.currentHole < 17 {
                    Button {
                        withAnimation(.spring()) {
                            game.currentHole += 1
                        }
                    } label: {
                        HStack {
                            Text("Next Hole")
                                .font(.system(size: 16, weight: .bold))
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    }
                }

                Button {
                    showResults = true
                } label: {
                    Text(game.currentHole == 17 ? "Calculate Payout →" : "End Early →")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#52FF20"), Color(hex: "#1fa005")],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .shadow(color: Color(hex: "#39FF14").opacity(0.4), radius: 12, y: 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(hex: "#060606"))
    }
}

// MARK: - Hole Card
struct HoleCard: View {
    @Bindable var game: ActiveGame
    let hole: Int
    let setup: GameSetup

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Par selector
                parRow

                Divider().background(Color.white.opacity(0.08))

                // Player score rows
                ForEach(setup.players) { player in
                    PlayerScoreRow(game: game, player: player, hole: hole)
                }

                // Per-hole game tracking
                let modes = Set(setup.games.map { $0.mode })
                let manualModes: Set<GameMode> = [.wolf, .bingoBangoBongo, .snake, .ctp, .trouble, .arnies, .banker]
                if !modes.intersection(manualModes).isEmpty {
                    HoleTrackerView(game: game, hole: hole, setup: setup)
                }
            }
            .padding(20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "#111111"))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.6), radius: 20)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    var parRow: some View {
        HStack {
            Text("PAR")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.gray)
                .tracking(2)

            Spacer()

            HStack(spacing: 20) {
                Button {
                    if game.pars[hole] > 3 {
                        game.pars[hole] -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.gray.opacity(0.6))
                }

                Text("\(game.pars[hole])")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(.white)
                    .frame(minWidth: 40)

                Button {
                    if game.pars[hole] < 5 {
                        game.pars[hole] += 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(hex: "#39FF14").opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Player Score Row
struct PlayerScoreRow: View {
    @Bindable var game: ActiveGame
    let player: PlayerSnapshot
    let hole: Int
    @State private var bounceScale: CGFloat = 1.0
    @State private var voice = VoiceScoreManager()

    var score: Int? { game.getScore(playerId: player.id, hole: hole) }
    var relToPar: Int? { game.relToPar(playerId: player.id, hole: hole) }

    var scoreColor: Color {
        guard let rel = relToPar else { return .white }
        if rel <= -1 { return Color(hex: "#39FF14") }
        if rel == 1 { return Color(hex: "#ff4444") }
        if rel >= 2 { return Color(hex: "#cc2222") }
        return .white
    }

    var body: some View {
        HStack {
            // Player name + taxman
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("TM \(player.taxMan)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#39FF14"))
            }

            Spacer()

            // Score stepper
            HStack(spacing: 10) {
                // Voice entry
                VoiceScoreButton(par: game.pars[hole]) { s in
                    game.setScore(playerId: player.id, hole: hole, score: s)
                }

                Button {
                    let current = score ?? game.pars[hole]
                    if current > 1 {
                        withAnimation(.spring(duration: 0.2)) { bounceScale = 0.9 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(duration: 0.2)) { bounceScale = 1.0 }
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        game.setScore(playerId: player.id, hole: hole, score: current - 1)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(score != nil ? Color.gray.opacity(0.7) : Color.gray.opacity(0.3))
                }

                // Score display
                ZStack {
                    Circle()
                        .fill(score != nil ? scoreColor.opacity(0.15) : Color.clear)
                        .overlay(
                            Circle().strokeBorder(score != nil ? scoreColor.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 2)
                        )
                        .frame(width: 52, height: 52)

                    if let s = score {
                        Text("\(s)")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(scoreColor)
                            .shadow(color: scoreColor.opacity(0.5), radius: score != nil && relToPar != 0 ? 8 : 0)
                    } else {
                        Text("—")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.gray.opacity(0.4))
                    }
                }
                .scaleEffect(bounceScale)

                Button {
                    let current = score ?? (game.pars[hole] - 1)
                    withAnimation(.spring(duration: 0.2)) { bounceScale = 1.1 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(duration: 0.2)) { bounceScale = 1.0 }
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    game.setScore(playerId: player.id, hole: hole, score: current + 1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color(hex: "#39FF14").opacity(score != nil ? 0.8 : 0.5))
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
