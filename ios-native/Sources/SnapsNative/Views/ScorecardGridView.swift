import SwiftUI

// MARK: - Full 18-hole scorecard grid
// Toggle from ScoreCardView via the grid button

struct ScorecardGridView: View {
    @Bindable var game: ActiveGame
    let setup: GameSetup
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }

    // Live money calc
    var liveNet: [String: Double] {
        let extras = buildExtras()
        let result = calcAllGames(players: setup.players, games: setup.games,
                                  scores: game.scores, extras: extras)
        return result.combinedNet
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(theme.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(theme.surface2, in: Circle())
                    }

                    Spacer()

                    Text("SCORECARD")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(theme.textPrimary)
                        .tracking(2)

                    Spacer()

                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Money ticker
                moneyTicker

                // Grid
                scorecardGrid
            }
        }
    }

    // MARK: - Money Ticker

    var moneyTicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(setup.players) { player in
                    let net = liveNet[player.name] ?? 0
                    HStack(spacing: 6) {
                        Image(profileImageName(for: player.name))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(player.name)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(theme.textSecondary)
                            Text(net >= 0 ? "+$\(Int(net))" : "-$\(Int(abs(net)))")
                                .font(.system(size: 15, weight: .black, design: .monospaced))
                                .foregroundStyle(net > 0 ? Color.snapsGreen : net < 0 ? Color.snapsDanger : theme.textSecondary)
                                .contentTransition(.numericText())
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(net > 0 ? Color.snapsGreen.opacity(0.08) :
                                  net < 0 ? Color.snapsDanger.opacity(0.08) :
                                  theme.surface2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(
                                        net > 0 ? Color.snapsGreen.opacity(0.3) :
                                        net < 0 ? Color.snapsDanger.opacity(0.3) :
                                        theme.border,
                                        lineWidth: 1
                                    )
                            )
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Scorecard Grid

    var scorecardGrid: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Front 9
                nineBlock(label: "OUT", start: 0, end: 9)
                // Back 9
                nineBlock(label: "IN", start: 9, end: 18)
                // Totals
                totalsRow
            }
        }
    }

    func nineBlock(label: String, start: Int, end: Int) -> some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text(label == "OUT" ? "FRONT 9" : "BACK 9")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.snapsGreen)
                    .tracking(2)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.bg)

            // Scrollable hole columns
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header row (hole numbers)
                    holeHeaderRow(start: start, end: end, label: label)

                    // Par row
                    parRow(start: start, end: end, label: label)

                    Divider().background(Color.snapsGreen.opacity(0.3))

                    // Player score rows
                    ForEach(Array(setup.players.enumerated()), id: \.element.id) { idx, player in
                        playerScoreRow(player: player, start: start, end: end, label: label)
                        if idx < setup.players.count - 1 {
                            Divider().background(theme.border.opacity(0.5))
                        }
                    }
                }
            }
        }
        .background(theme.surface1)
        .overlay(
            Rectangle()
                .strokeBorder(theme.border, lineWidth: 1)
        )
        .padding(.bottom, 2)
    }

    func holeHeaderRow(start: Int, end: Int, label: String) -> some View {
        HStack(spacing: 0) {
            Text("PLAYER")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.textMuted)
                .tracking(1)
                .frame(width: 90, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            ForEach(start..<end, id: \.self) { hole in
                Text("\(hole + 1)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 44)
                    .padding(.vertical, 10)
            }

            Text(label)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 44)
                .padding(.vertical, 10)
        }
        .background(theme.surface2)
    }

    func parRow(start: Int, end: Int, label: String) -> some View {
        HStack(spacing: 0) {
            Text("PAR")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.snapsGreen)
                .frame(width: 90, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            ForEach(start..<end, id: \.self) { hole in
                Text("\(game.pars[hole])")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.snapsGreen)
                    .frame(width: 44)
                    .padding(.vertical, 8)
            }

            let nineTotal = game.pars[start..<end].reduce(0, +)
            Text("\(nineTotal)")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(Color.snapsGreen)
                .frame(width: 44)
                .padding(.vertical, 8)
        }
        .background(theme.surface1)
    }

    func playerScoreRow(player: PlayerSnapshot, start: Int, end: Int, label: String) -> some View {
        HStack(spacing: 0) {
            // Profile photo + Name + mini net
            let net = liveNet[player.name] ?? 0
            HStack(spacing: 8) {
                Image(profileImageName(for: player.name))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(player.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Text(net >= 0 ? "+$\(Int(net))" : "-$\(Int(abs(net)))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(net >= 0 ? Color.snapsGreen : Color.snapsDanger)
                }
            }
            .frame(width: 110, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            // Hole scores
            ForEach(start..<end, id: \.self) { hole in
                scoreCell(player: player, hole: hole)
            }

            // Nine total
            let scores = (start..<end).compactMap { game.getScore(playerId: player.id, hole: $0) }
            let nineTotal = scores.isEmpty ? nil : scores.reduce(0, +)
            let ninePar = game.pars[start..<end].reduce(0, +)

            Group {
                if let t = nineTotal {
                    let diff = t - ninePar
                    Text("\(t)")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(diff < 0 ? Color.snapsGreen : diff == 0 ? theme.textPrimary : Color.snapsDanger)
                } else {
                    Text("—")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.textMuted)
                }
            }
            .frame(width: 44)
            .padding(.vertical, 10)
        }
    }

    func scoreCell(player: PlayerSnapshot, hole: Int) -> some View {
        let score = game.getScore(playerId: player.id, hole: hole)
        let par = game.pars[hole]
        let rel = score.map { $0 - par }

        return Group {
            if let s = score, let r = rel {
                ZStack {
                    // Background shape based on score
                    scoreBadge(rel: r)
                    Text("\(s)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(scoreTextColor(rel: r))
                }
            } else {
                Text("·")
                    .font(.system(size: 18))
                    .foregroundStyle(theme.textMuted)
            }
        }
        .frame(width: 44, height: 40)
    }

    @ViewBuilder
    func scoreBadge(rel: Int) -> some View {
        if rel <= -2 {
            // Eagle or better: double circle (gold)
            ZStack {
                Circle()
                    .strokeBorder(Color.scoreEagle.opacity(0.8), lineWidth: 1.5)
                    .frame(width: 28, height: 28)
                Circle()
                    .strokeBorder(Color.scoreEagle.opacity(0.4), lineWidth: 1)
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(Color.scoreEagle.opacity(0.15))
                    .frame(width: 22, height: 22)
            }
        } else if rel == -1 {
            // Birdie: circle (green)
            Circle()
                .strokeBorder(Color.scoreBirdie.opacity(0.8), lineWidth: 1.5)
                .background(Circle().fill(Color.scoreBirdie.opacity(0.12)))
                .frame(width: 28, height: 28)
        } else if rel == 0 {
            // Par: no decoration
            Color.clear.frame(width: 28, height: 28)
        } else if rel == 1 {
            // Bogey: square (light red)
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.snapsDanger.opacity(0.6), lineWidth: 1.5)
                .background(RoundedRectangle(cornerRadius: 3).fill(Color.snapsDanger.opacity(0.08)))
                .frame(width: 28, height: 28)
        } else {
            // Double bogey+: double square (red)
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.scoreDouble.opacity(0.85), lineWidth: 1.5)
                    .frame(width: 28, height: 28)
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(Color.scoreDouble.opacity(0.4), lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 2).fill(Color.scoreDouble.opacity(0.12)))
                    .frame(width: 22, height: 22)
            }
        }
    }

    func scoreTextColor(rel: Int) -> Color {
        if rel <= -2 { return Color.scoreEagle }
        if rel == -1 { return Color.scoreBirdie }
        if rel == 0  { return Color.scorePar }
        if rel == 1  { return Color.scoreBogey }
        return Color.scoreDouble
    }

    // MARK: - Totals Row

    var totalsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                Divider().background(Color.snapsGreen.opacity(0.4))

                HStack(spacing: 0) {
                    Text("TOTAL")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color.snapsGreen)
                        .tracking(1)
                        .frame(width: 90, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)

                    ForEach(0..<18, id: \.self) { _ in
                        Color.clear.frame(width: 44)
                    }

                    Color.clear.frame(width: 44)  // OUT spacer
                    Color.clear.frame(width: 44)  // IN spacer
                }

                ForEach(setup.players) { player in
                    Divider().background(theme.border.opacity(0.5))
                    HStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Image(profileImageName(for: player.name))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(theme.textPrimary)
                                let net = liveNet[player.name] ?? 0
                                Text(net >= 0 ? "+$\(Int(net))" : "-$\(Int(abs(net)))")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundStyle(net >= 0 ? Color.snapsGreen : Color.snapsDanger)
                            }
                        }
                        .frame(width: 110, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)

                        let outScores = (0..<9).compactMap { game.getScore(playerId: player.id, hole: $0) }
                        let inScores = (9..<18).compactMap { game.getScore(playerId: player.id, hole: $0) }
                        let totalScores = outScores + inScores

                        ForEach(0..<18, id: \.self) { _ in Color.clear.frame(width: 44) }

                        // Out total
                        totalCell(scores: outScores, pars: Array(game.pars[0..<9]))
                        // In total
                        totalCell(scores: inScores, pars: Array(game.pars[9..<18]))
                        // Grand total
                        totalCell(scores: totalScores, pars: game.pars, isGrand: true)
                    }
                }
            }
        }
        .background(theme.surface1)
    }

    func totalCell(scores: [Int], pars: [Int], isGrand: Bool = false) -> some View {
        let total = scores.reduce(0, +)
        let par = pars.reduce(0, +)
        let diff = total - par
        let hasData = !scores.isEmpty

        return Group {
            if hasData {
                Text("\(total)")
                    .font(.system(size: 14, weight: isGrand ? .black : .bold, design: .monospaced))
                    .foregroundStyle(diff < 0 ? Color.snapsGreen : diff == 0 ? theme.textPrimary : Color.snapsDanger)
            } else {
                Text("—")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textMuted)
            }
        }
        .frame(width: 44)
        .padding(.vertical, 12)
    }

    // MARK: - Extras helper

    func buildExtras() -> GameExtras {
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
        return extras
    }
}
