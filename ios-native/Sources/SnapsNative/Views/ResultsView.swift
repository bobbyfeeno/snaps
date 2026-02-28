import SwiftUI

struct ResultsView: View {
    let game: ActiveGame
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var revealedCount = 0
    @State private var showConfetti = false

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
        extras.vegasTeamA = setup.vegasTeamA
        extras.vegasTeamB = setup.vegasTeamB
        let engineResult = calcAllGames(
            players: setup.players, games: setup.games, scores: game.scores, extras: extras)
        return setup.players.map { player in
            let net = engineResult.combinedNet[player.name] ?? 0
            return PlayerResult(id: player.id, name: player.name, netAmount: net,
                                venmoHandle: player.venmoHandle, cashappHandle: player.cashappHandle)
        }.sorted { $0.netAmount > $1.netAmount }
    }

    var winner: PlayerResult? { results.first }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            ScrollView {
                VStack(spacing: 24) {
                    // Title
                    VStack(spacing: 4) {
                        Text("RESULTS")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.gray)
                            .tracking(4)
                            .padding(.top, 24)

                        if let w = winner, revealedCount == results.count {
                            Text("🏆 \(w.name) Wins!")
                                .font(.system(size: 28, weight: .black))
                                .foregroundStyle(Color(hex: "#39FF14"))
                                .shadow(color: Color(hex: "#39FF14").opacity(0.5), radius: 10)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    // Result cards
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        if index < revealedCount {
                            ResultCard(result: result, rank: index + 1, isWinner: index == 0)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }

                    // Payment section
                    if revealedCount == results.count {
                        let payers = results.filter { $0.netAmount < 0 }
                        if !payers.isEmpty {
                            paymentSection(payers: payers)
                                .transition(.opacity)
                        }

                        // Share button
                        Button {
                            shareResults()
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Summary")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 20)
                        .transition(.opacity)

                        Button("Done") {
                            game.reset()
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.gray)
                        .padding(.bottom, 32)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear { revealNext() }
    }

    func revealNext() {
        guard revealedCount < results.count else {
            withAnimation(.spring(duration: 0.5)) {
                showConfetti = revealedCount > 0
            }
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(duration: 0.5)) {
            revealedCount += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            revealNext()
        }
    }

    func paymentSection(payers: [PlayerResult]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COLLECT PAYMENTS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.gray)
                .tracking(3)
                .padding(.horizontal, 20)

            ForEach(payers) { payer in
                PaymentRow(payer: payer, receivers: results.filter { $0.netAmount > 0 })
            }
        }
    }

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

// MARK: - Result Card
struct ResultCard: View {
    let result: PlayerResult
    let rank: Int
    let isWinner: Bool
    @State private var appear = false

    var body: some View {
        HStack {
            // Rank
            Text("#\(rank)")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(isWinner ? Color(hex: "#39FF14") : .gray)
                .frame(width: 40)

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                if isWinner {
                    Text("Champion")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "#39FF14"))
                }
            }

            Spacer()

            // Amount
            Text(result.netAmount >= 0 ? "+$\(String(format: "%.0f", result.netAmount))" : "-$\(String(format: "%.0f", abs(result.netAmount)))")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(result.netAmount >= 0 ? Color(hex: "#39FF14") : Color(hex: "#ff4444"))
                .shadow(color: result.netAmount >= 0 ? Color(hex: "#39FF14").opacity(0.4) : Color(hex: "#ff4444").opacity(0.3), radius: 8)
                .contentTransition(.numericText())
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isWinner ? Color(hex: "#39FF14").opacity(0.08) : Color(hex: "#111111"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(isWinner ? Color(hex: "#39FF14").opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .shadow(color: isWinner ? Color(hex: "#39FF14").opacity(0.1) : .clear, radius: 12)
        .scaleEffect(appear ? 1.0 : 0.95)
        .onAppear { withAnimation(.spring(duration: 0.4)) { appear = true } }
    }
}

// MARK: - Payment Row
struct PaymentRow: View {
    let payer: PlayerResult
    let receivers: [PlayerResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(payer.name) owes")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.gray)
                Text("$\(String(format: "%.0f", abs(payer.netAmount)))")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color(hex: "#ff4444"))
            }
            .padding(.horizontal, 20)

            HStack(spacing: 10) {
                if !payer.venmoHandle.isEmpty {
                    payButton(label: "Pay via Venmo", color: Color(hex: "#3D95CE")) {
                        openVenmo(handle: payer.venmoHandle, amount: abs(payer.netAmount))
                    }
                }
                if !payer.cashappHandle.isEmpty {
                    payButton(label: "Pay via Cash App", color: Color(hex: "#00D632")) {
                        openCashApp(tag: payer.cashappHandle, amount: abs(payer.netAmount))
                    }
                }
                if payer.venmoHandle.isEmpty && payer.cashappHandle.isEmpty {
                    Text("No payment handles saved")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
        .background(Color(hex: "#0f0f0f"), in: RoundedRectangle(cornerRadius: 12))
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
                let p = ConfettiParticle()
                particles.append(p)
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
    var color = [Color(hex: "#39FF14"), Color.yellow, Color.white, Color.cyan, Color.orange].randomElement()!
    var size = CGFloat.random(in: 4...10)
    var opacity = 1.0
}
