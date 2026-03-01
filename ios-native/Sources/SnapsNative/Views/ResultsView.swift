import SwiftUI

struct ResultsView: View {
    let game: ActiveGame
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }

    // Round save state
    @State private var roundSaved = false

    // Reveal sequencing
    @State private var showWinnerName = false
    @State private var showWinnerCard = false
    @State private var winnerAmountDisplay: Double = 0
    @State private var showLoserCards = false
    @State private var showPayments = false
    @State private var showActionButtons = false
    @State private var showConfetti = false
    @State private var neonGlowBurst = false

    var results: [PlayerResult] {
        guard let setup = game.setup else { return [] }
        var extras = GameExtras(pars: game.pars)
        extras.wolf = game.wolfHoles
        extras.bbb = game.bbbHoles
        extras.snake = game.snakeHoles
        extras.ctp = game.ctpHoles
        extras.trouble = game.troubleHoles
        extras.arnies = game.arniesHoles
        extras.banker = game.bankerHoles
        extras.dots = game.dotsHoles
        extras.vegasTeamA = setup.vegasTeamA
        extras.vegasTeamB = setup.vegasTeamB
        extras.pressMatches = game.pressMatches
        let engineResult = calcAllGames(
            players: setup.players, games: setup.games, scores: game.scores, extras: extras)
        return setup.players.map { player in
            let net = engineResult.combinedNet[player.name] ?? 0
            return PlayerResult(id: player.id, name: player.name, netAmount: net,
                                venmoHandle: player.venmoHandle, cashappHandle: player.cashappHandle)
        }.sorted { $0.netAmount > $1.netAmount }
    }

    var winner: PlayerResult? { results.first }
    var losers: [PlayerResult] { Array(results.dropFirst()) }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            ScrollView {
                VStack(spacing: 28) {

                    // Header label
                    Text("RESULTS")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(theme.textSecondary)
                        .tracking(4)
                        .padding(.top, 28)
                        .opacity(showWinnerName ? 1 : 0)

                    // Winner reveal block
                    if let w = winner {
                        VStack(spacing: 20) {

                            // Winner name slides up
                            if showWinnerName {
                                VStack(spacing: 4) {
                                    Text("🏆")
                                        .font(.system(size: 40))
                                    Text(w.name)
                                        .font(.system(size: 34, weight: .black))
                                        .foregroundStyle(theme.textPrimary)
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }

                            // Winner card with count-up amount
                            if showWinnerCard {
                                HStack {
                                    // Rank
                                    Text("#1")
                                        .font(.system(size: 18, weight: .black, design: .monospaced))
                                        .foregroundStyle(Color.snapsNeon)
                                        .frame(width: 40)

                                    // Name + label
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(w.name)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(theme.textPrimary)
                                        Text("Champion")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color.snapsNeon)
                                    }

                                    Spacer()

                                    // Count-up amount
                                    Text("+$\(String(format: "%.0f", winnerAmountDisplay))")
                                        .font(.system(size: 26, weight: .black, design: .monospaced))
                                        .foregroundStyle(Color.snapsNeon)
                                        .shadow(color: Color.snapsNeon.opacity(neonGlowBurst ? 0.9 : 0.4),
                                                radius: neonGlowBurst ? 24 : 8)
                                        .contentTransition(.numericText())
                                }
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.snapsNeon.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .strokeBorder(Color.snapsNeon.opacity(0.25), lineWidth: 1)
                                        )
                                )
                                .shadow(color: Color.snapsNeon.opacity(neonGlowBurst ? 0.25 : 0.08), radius: 20)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }

                    // Loser cards
                    if showLoserCards {
                        VStack(spacing: 12) {
                            ForEach(Array(losers.enumerated()), id: \.element.id) { index, result in
                                LoserResultCard(result: result, rank: index + 2)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }

                    // Payment section — bounces in last
                    if showPayments {
                        let payers = results.filter { $0.netAmount < 0 }
                        if !payers.isEmpty {
                            paymentSection(payers: payers)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }

                    // Action buttons
                    if showActionButtons {
                        VStack(spacing: 12) {
                            Button {
                                shareResults()
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share Summary")
                                }
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(theme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(SnapsButtonStyle())

                            Button("Done") {
                                NotificationCenter.default.post(name: .switchToYouTab, object: nil)
                                dismiss()
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.textSecondary)
                            .padding(.bottom, 32)
                        }
                        .padding(.horizontal, 20)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            startRevealSequence()
            saveRound()
        }
        .onDisappear {
            game.reset()
        }
    }

    // MARK: - Save Round

    func saveRound() {
        guard !roundSaved, let setup = game.setup else { return }
        roundSaved = true

        let record = RoundRecord(
            players: setup.players,
            pars: game.pars,
            games: setup.games,
            results: results,
            scores: game.scores,
            fairwayDirs: game.fairwayDirs,
            greenDirs: game.greenDirs,
            putts: game.putts
        )
        modelContext.insert(record)
        try? modelContext.save()
    }

    // MARK: - Reveal Sequence

    func startRevealSequence() {
        // Step 1: After 300ms — winner name slides up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                showWinnerName = true
            }
        }

        // Step 2: After 750ms — winner card appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                showWinnerCard = true
            }

            // Haptic at reveal
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Neon glow burst
            withAnimation(.easeOut(duration: 0.3)) {
                neonGlowBurst = true
            }
            withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                neonGlowBurst = false
            }

            // Count-up amount animation
            if let w = winner {
                withAnimation(.easeInOut(duration: 1.2)) {
                    winnerAmountDisplay = max(0, w.netAmount)
                }
            }

            // Confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(duration: 0.4)) {
                    showConfetti = true
                }
            }
        }

        // Step 3: After 1.6s — loser cards
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                showLoserCards = true
            }
        }

        // Step 4: After 2.2s — payment section bounces in
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showPayments = true
                showActionButtons = true
            }
        }
    }

    // MARK: - Payment Section

    func paymentSection(payers: [PlayerResult]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COLLECT PAYMENTS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.textSecondary)
                .tracking(3)
                .padding(.horizontal, 20)

            ForEach(payers) { payer in
                PaymentRow(payer: payer, receivers: results.filter { $0.netAmount > 0 })
            }
        }
    }

    // MARK: - Share

    func shareResults() {
        let dateStr = Date().formatted(date: .abbreviated, time: .omitted)
        var text = "Snaps Round — \(dateStr)\n"
        for r in results {
            let sign = r.netAmount >= 0 ? "+" : ""
            text += "\(r.name): \(sign)$\(String(format: "%.0f", r.netAmount))\n"
        }
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController?
            .present(av, animated: true)
    }
}

// MARK: - Loser Result Card
struct LoserResultCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let result: PlayerResult
    let rank: Int
    @State private var appear = false

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }

    var body: some View {
        HStack {
            // Rank
            Text("#\(rank)")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 40)

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
            }

            Spacer()

            // Amount — red for losers
            Text("-$\(String(format: "%.0f", abs(result.netAmount)))")
                .font(.system(size: 26, weight: .black, design: .monospaced))
                .foregroundStyle(Color.snapsDanger)
                .shadow(color: Color.snapsDanger.opacity(0.3), radius: 6)
                .contentTransition(.numericText())
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surface1)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(theme.border, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 10, y: 3)
        .scaleEffect(appear ? 1.0 : 0.95)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { appear = true }
        }
    }
}

// MARK: - Payment Row
struct PaymentRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let payer: PlayerResult
    let receivers: [PlayerResult]

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(payer.name) owes")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Text("$\(String(format: "%.0f", abs(payer.netAmount)))")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.snapsDanger)
            }
            .padding(.horizontal, 20)

            HStack(spacing: 10) {
                if !payer.venmoHandle.isEmpty {
                    payButton(label: "Pay via Venmo", color: Color.snapsVenmo) {
                        openVenmo(handle: payer.venmoHandle, amount: abs(payer.netAmount))
                    }
                }
                if !payer.cashappHandle.isEmpty {
                    payButton(label: "Pay via Cash App", color: Color.snapsCashApp) {
                        openCashApp(tag: payer.cashappHandle, amount: abs(payer.netAmount))
                    }
                }
                if payer.venmoHandle.isEmpty && payer.cashappHandle.isEmpty {
                    Text("No payment handles saved")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
        .background(theme.surface1, in: RoundedRectangle(cornerRadius: 12))
    }

    func payButton(label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(color, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(SnapsButtonStyle())
    }

    func openVenmo(handle: String, amount: Double) {
        let note = "Snaps%20Golf%20Round"
        let urlStr = "venmo://paycharge?txn=charge&recipients=\(handle)&amount=\(String(format: "%.2f", amount))&note=\(note)"
        if let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let fallback = URL(string: "https://venmo.com/") {
            UIApplication.shared.open(fallback)
        }
    }

    func openCashApp(tag: String, amount: Double) {
        let urlStr = "https://cash.app/\(tag)/\(String(format: "%.2f", amount))"
        if let url = URL(string: urlStr) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Simple Confetti View
struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Circle()
                    .fill(p.color)
                    .frame(width: p.size, height: p.size)
                    .position(p.position)
                    .opacity(p.opacity)
            }
        }
        .onAppear {
            for _ in 0..<80 {
                particles.append(ConfettiParticle())
            }
            withAnimation(.linear(duration: 2.5)) {
                for i in particles.indices {
                    particles[i].position.y += CGFloat.random(in: 600...900)
                    particles[i].position.x += CGFloat.random(in: -100...100)
                    particles[i].opacity = 0
                }
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var position = CGPoint(x: CGFloat.random(in: 0...400), y: CGFloat.random(in: -50...100))
    // Keep colorful confetti — intentionally multi-color including neon
    var color = [Color.snapsNeon, Color.yellow, Color.white, Color.cyan, Color.orange].randomElement()!
    var size = CGFloat.random(in: 4...10)
    var opacity = 1.0
}
