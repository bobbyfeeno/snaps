import SwiftUI
import SwiftData
import Charts

// MARK: - RoundStatsData

struct RoundStatsData {
    let roundsPlayed: Int
    let roundsWon: Int
    let netEarnings: Double
    let bestRound: Double
    let worstRound: Double
    let avgPerRound: Double
    let totalPotPlayed: Double
}

// MARK: - EarningPoint (for chart)

struct EarningPoint: Identifiable {
    let id = UUID()
    let index: Int
    let cumulative: Double
}

// MARK: - HeadToHeadRecord

struct HeadToHeadRecord: Identifiable {
    let id = UUID()
    let opponentName: String
    let wins: Int
    let losses: Int
    let ties: Int

    var winRate: Double {
        let total = wins + losses + ties
        guard total > 0 else { return 0 }
        return Double(wins) / Double(total)
    }
}

// MARK: - GameModeBreakdown

struct GameModeBreakdown: Identifiable {
    let id = UUID()
    let mode: GameMode
    let roundsPlayed: Int
    let netEarnings: Double   // player net (if filtered) or total pot
    let isPlayerFiltered: Bool
}

// MARK: - ScoringDistribution

struct ScoringDistribution {
    var eagles: Int = 0
    var birdies: Int = 0
    var pars: Int = 0
    var bogeys: Int = 0
    var doubles: Int = 0

    var total: Int { eagles + birdies + pars + bogeys + doubles }

    func pct(_ value: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(value) / Double(total)
    }
}

// MARK: - ParBreakdown

struct ParBreakdown {
    var par3Scores: [Int] = []
    var par4Scores: [Int] = []
    var par5Scores: [Int] = []

    func avg(for parValue: Int) -> Double? {
        let arr: [Int]
        switch parValue {
        case 3: arr = par3Scores
        case 4: arr = par4Scores
        case 5: arr = par5Scores
        default: arr = []
        }
        guard !arr.isEmpty else { return nil }
        return Double(arr.reduce(0, +)) / Double(arr.count)
    }
}

// MARK: - StatsView

struct StatsView: View {
    @Query(sort: \RoundRecord.date, order: .reverse) private var rounds: [RoundRecord]

    @State private var selectedPlayer: String? = nil
    var appState: AppState = .shared

    // MARK: Computed: All unique player names
    private var allPlayers: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for round in rounds {
            for r in round.results {
                if !seen.contains(r.name) {
                    seen.insert(r.name)
                    result.append(r.name)
                }
            }
        }
        return result.sorted()
    }

    // MARK: Filtered rounds
    private var filteredRounds: [RoundRecord] {
        guard let player = selectedPlayer else { return rounds }
        return rounds.filter { round in
            round.results.contains { $0.name == player }
        }
    }

    // MARK: Player Stats
    private var playerStats: RoundStatsData {
        if let player = selectedPlayer {
            return computeRoundStatsData(player: player)
        } else {
            return computeAllStats()
        }
    }

    private func computeRoundStatsData(player: String) -> RoundStatsData {
        var totalNet = 0.0
        var best = -Double.infinity
        var worst = Double.infinity
        var totalPot = 0.0
        var wins = 0
        var played = 0

        for round in filteredRounds {
            guard let result = round.results.first(where: { $0.name == player }) else { continue }
            played += 1
            totalNet += result.netAmount
            best = max(best, result.netAmount)
            worst = min(worst, result.netAmount)
            totalPot += round.totalPot
            // Win: player has highest netAmount
            if result.netAmount == round.results.map(\.netAmount).max() ?? 0 {
                wins += 1
            }
        }

        let avg = played > 0 ? totalNet / Double(played) : 0
        return RoundStatsData(
            roundsPlayed: played,
            roundsWon: wins,
            netEarnings: totalNet,
            bestRound: best == -Double.infinity ? 0 : best,
            worstRound: worst == Double.infinity ? 0 : worst,
            avgPerRound: avg,
            totalPotPlayed: totalPot
        )
    }

    private func computeAllStats() -> RoundStatsData {
        let played = rounds.count
        let totalPot = rounds.reduce(0.0) { $0 + $1.totalPot }
        return RoundStatsData(
            roundsPlayed: played,
            roundsWon: 0,
            netEarnings: 0,
            bestRound: rounds.compactMap { $0.results.map(\.netAmount).max() }.max() ?? 0,
            worstRound: rounds.compactMap { $0.results.map(\.netAmount).min() }.min() ?? 0,
            avgPerRound: played > 0 ? totalPot / Double(played) : 0,
            totalPotPlayed: totalPot
        )
    }

    // MARK: Earnings over time
    private var earningPoints: [EarningPoint] {
        guard let player = selectedPlayer else { return [] }
        let sorted = filteredRounds.sorted { $0.date < $1.date }
        var cumulative = 0.0
        return sorted.enumerated().compactMap { index, round in
            guard let result = round.results.first(where: { $0.name == player }) else { return nil }
            cumulative += result.netAmount
            return EarningPoint(index: index, cumulative: cumulative)
        }
    }

    // MARK: Scoring Distribution
    private var scoringDistribution: ScoringDistribution? {
        guard let player = selectedPlayer else { return nil }
        var dist = ScoringDistribution()
        var hasData = false

        for round in filteredRounds {
            let pars = round.pars
            guard let playerScores = round.scores[
                round.players.first(where: { $0.name == player })?.id ?? ""
            ] else { continue }

            for (i, scoreOpt) in playerScores.enumerated() {
                guard let score = scoreOpt, i < pars.count else { continue }
                hasData = true
                let rel = score - pars[i]
                if rel <= -2 { dist.eagles += 1 }
                else if rel == -1 { dist.birdies += 1 }
                else if rel == 0 { dist.pars += 1 }
                else if rel == 1 { dist.bogeys += 1 }
                else { dist.doubles += 1 }
            }
        }
        return hasData ? dist : nil
    }

    // MARK: Par Breakdown
    private var parBreakdown: ParBreakdown? {
        guard let player = selectedPlayer else { return nil }
        var breakdown = ParBreakdown()
        var hasData = false

        for round in filteredRounds {
            let pars = round.pars
            guard let playerScores = round.scores[
                round.players.first(where: { $0.name == player })?.id ?? ""
            ] else { continue }

            for (i, scoreOpt) in playerScores.enumerated() {
                guard let score = scoreOpt, i < pars.count else { continue }
                hasData = true
                switch pars[i] {
                case 3: breakdown.par3Scores.append(score)
                case 4: breakdown.par4Scores.append(score)
                case 5: breakdown.par5Scores.append(score)
                default: break
                }
            }
        }
        return hasData ? breakdown : nil
    }

    // MARK: Game Mode Breakdown
    private var gameModeBreakdown: [GameModeBreakdown] {
        var modeData: [GameMode: (rounds: Int, net: Double)] = [:]

        for round in filteredRounds {
            let gameModes = round.games.map(\.mode)
            let modeCount = gameModes.count

            if let player = selectedPlayer,
               let result = round.results.first(where: { $0.name == player }) {
                let perMode = modeCount > 0 ? result.netAmount / Double(modeCount) : 0
                for mode in gameModes {
                    modeData[mode, default: (0, 0)].rounds += 1
                    modeData[mode, default: (0, 0)].net += perMode
                }
            } else {
                let perMode = modeCount > 0 ? round.totalPot / Double(modeCount) : 0
                for mode in gameModes {
                    modeData[mode, default: (0, 0)].rounds += 1
                    modeData[mode, default: (0, 0)].net += perMode
                }
            }
        }

        return modeData
            .map { mode, data in
                GameModeBreakdown(
                    mode: mode,
                    roundsPlayed: data.rounds,
                    netEarnings: data.net,
                    isPlayerFiltered: selectedPlayer != nil
                )
            }
            .sorted { abs($0.netEarnings) > abs($1.netEarnings) }
    }

    // MARK: Head to Head
    private var headToHead: [HeadToHeadRecord] {
        guard let player = selectedPlayer else { return [] }
        var records: [String: (wins: Int, losses: Int, ties: Int)] = [:]

        for round in filteredRounds {
            guard let myResult = round.results.first(where: { $0.name == player }) else { continue }
            for other in round.results where other.name != player {
                let key = other.name
                if myResult.netAmount > other.netAmount {
                    records[key, default: (0, 0, 0)].wins += 1
                } else if myResult.netAmount < other.netAmount {
                    records[key, default: (0, 0, 0)].losses += 1
                } else {
                    records[key, default: (0, 0, 0)].ties += 1
                }
            }
        }

        return records.map { name, rec in
            HeadToHeadRecord(opponentName: name, wins: rec.wins, losses: rec.losses, ties: rec.ties)
        }.sorted { $0.wins + $0.losses + $0.ties > $1.wins + $1.losses + $1.ties }
    }

    // MARK: Scoring Average vs Par (avg strokes above/below par per round)
    private var scoringAvgVsPar: Double? {
        guard let player = selectedPlayer else { return nil }
        var totalDiff = 0.0
        var roundCount = 0
        for round in filteredRounds {
            let pars = round.pars
            let totalPar = pars.reduce(0, +)
            guard let playerScores = round.scores[
                round.players.first(where: { $0.name == player })?.id ?? ""
            ] else { continue }
            let played = playerScores.compactMap { $0 }
            guard played.count >= 9 else { continue }
            let adjPar = Double(totalPar) * Double(played.count) / 18.0
            totalDiff += Double(played.reduce(0, +)) - adjPar
            roundCount += 1
        }
        guard roundCount > 0 else { return nil }
        return totalDiff / Double(roundCount)
    }

    // MARK: Best Round vs Par (lowest round score relative to par, full 18 holes only)
    private var bestRoundVsPar: Int? {
        guard let player = selectedPlayer else { return nil }
        var best: Int? = nil
        for round in filteredRounds {
            let pars = round.pars
            let totalPar = pars.reduce(0, +)
            guard let playerScores = round.scores[
                round.players.first(where: { $0.name == player })?.id ?? ""
            ] else { continue }
            let played = playerScores.compactMap { $0 }
            guard played.count >= 18 else { continue }
            let diff = played.reduce(0, +) - totalPar
            if best == nil || diff < best! { best = diff }
        }
        return best
    }

    // MARK: Scoring Trend (positive = improving; compares last 3 rounds vs rest)
    private var scoringTrend: Double? {
        guard let player = selectedPlayer else { return nil }
        let sorted = filteredRounds.sorted { $0.date < $1.date }
        var diffs: [Double] = []
        for round in sorted {
            let pars = round.pars
            let totalPar = pars.reduce(0, +)
            guard let playerScores = round.scores[
                round.players.first(where: { $0.name == player })?.id ?? ""
            ] else { continue }
            let played = playerScores.compactMap { $0 }
            guard played.count >= 9 else { continue }
            let adjPar = Double(totalPar) * Double(played.count) / 18.0
            diffs.append(Double(played.reduce(0, +)) - adjPar)
        }
        guard diffs.count >= 4 else { return nil }
        let recent = Array(diffs.suffix(3))
        let earlier = Array(diffs.prefix(diffs.count - 3))
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let earlierAvg = earlier.reduce(0, +) / Double(earlier.count)
        return earlierAvg - recentAvg  // positive = recent rounds are lower (better)
    }

    // MARK: GIR % (Greens in Regulation)
    private var girPct: Double? {
        guard let player = selectedPlayer else { return nil }
        var hit = 0; var total = 0
        for round in filteredRounds {
            guard let playerGreens = round.greenDirs[
                round.players.first(where: { $0.name == player })?.id ?? ""
            ] else { continue }
            for val in playerGreens {
                guard let v = val else { continue }
                total += 1
                if v == "hit" { hit += 1 }
            }
        }
        guard total > 0 else { return nil }
        return Double(hit) / Double(total) * 100
    }

    // MARK: Fairways Hit % (FIR)
    private var fairwaysPct: Double? {
        guard let player = selectedPlayer else { return nil }
        var hit = 0; var total = 0
        for round in filteredRounds {
            guard let playerFairways = round.fairwayDirs[
                round.players.first(where: { $0.name == player })?.id ?? ""
            ] else { continue }
            for val in playerFairways {
                guard let v = val else { continue }  // nil = par 3, skip
                total += 1
                if v == "hit" { hit += 1 }
            }
        }
        guard total > 0 else { return nil }
        return Double(hit) / Double(total) * 100
    }

    // MARK: Win Rate
    private var winRateString: String {
        guard let _ = selectedPlayer else {
            guard playerStats.roundsPlayed > 0 else { return "—" }
            return "—"
        }
        guard playerStats.roundsPlayed > 0 else { return "0%" }
        let pct = Int(Double(playerStats.roundsWon) / Double(playerStats.roundsPlayed) * 100)
        return "\(pct)%"
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Color.snapsBg.ignoresSafeArea()

            if rounds.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        headerSection
                        playerPicker
                            .padding(.top, 16)
                        heroCard
                            .padding(.top, 20)
                            .padding(.horizontal, 20)
                        // Improvement Stats (golf performance — shown when player selected and has score data)
                        if selectedPlayer != nil {
                            improvementStatsSection
                                .padding(.top, 20)
                        }
                        keyStatsGrid
                            .padding(.top, 16)
                        // Earnings Trend
                        if selectedPlayer != nil && earningPoints.count >= 2 {
                            earningsTrendChart
                                .padding(.top, 20)
                        }
                        // Scoring Distribution
                        if let dist = scoringDistribution, dist.total > 0 {
                            scoringDistributionSection(dist: dist)
                                .padding(.top, 20)
                        }
                        // Par Breakdown
                        if let pb = parBreakdown {
                            parBreakdownSection(pb)
                                .padding(.top, 20)
                        }
                        // Game Mode Breakdown
                        if !gameModeBreakdown.isEmpty {
                            gameModeSection
                                .padding(.top, 20)
                        }
                        // Head to Head
                        if selectedPlayer != nil && !headToHead.isEmpty {
                            headToHeadSection
                                .padding(.top, 20)
                        }
                        // Recent Rounds
                        recentRoundsSection
                            .padding(.top, 20)
                            .padding(.bottom, 100)
                    }
                }
            }
        }
        .onAppear {
            guard selectedPlayer == nil else { return }
            // Auto-select the logged-in user if they have rounds, else first player
            let userName = appState.currentUser?.displayName
            if let name = userName, allPlayers.contains(name) {
                selectedPlayer = name
            } else {
                selectedPlayer = allPlayers.first
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.snapsGreen.opacity(0.3))
            Text("No rounds yet")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.snapsTextPrimary)
            Text("Complete a round to see your stats")
                .font(.system(size: 15))
                .foregroundStyle(Color.snapsTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("STATS")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(Color.snapsTextPrimary)
                    .tracking(2)
                Text("\(rounds.count) round\(rounds.count == 1 ? "" : "s") recorded")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.snapsTextSecondary)
            }
            Spacer()
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.snapsGreen)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Player Picker

    private var playerPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All Players pill
                pillButton(label: "All Players", isSelected: selectedPlayer == nil) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedPlayer = nil
                    }
                }
                ForEach(allPlayers, id: \.self) { name in
                    pillButton(label: name, isSelected: selectedPlayer == name) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPlayer = name
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func pillButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.black : Color.snapsTextSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.snapsGreen : Color.snapsSurface1)
                )
        }
        .buttonStyle(SnapsButtonStyle())
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 0) {
            // Gradient background
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#0D2818"), Color.snapsBg],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 0) {
                    // Player label
                    Text(selectedPlayer ?? "All Players")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.snapsTextMuted)
                        .tracking(3)
                        .textCase(.uppercase)
                        .padding(.top, 24)

                    // Big win rate
                    if selectedPlayer != nil {
                        Text(winRateString)
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .foregroundStyle(Color.snapsGreen)
                            .padding(.top, 8)
                        Text("WIN RATE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.snapsTextMuted)
                            .tracking(3)
                            .padding(.top, 2)
                    } else {
                        Text("$\(String(format: "%.0f", playerStats.totalPotPlayed))")
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundStyle(Color.snapsGreen)
                            .padding(.top, 8)
                        Text("TOTAL POT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.snapsTextMuted)
                            .tracking(3)
                            .padding(.top, 2)
                    }

                    Rectangle()
                        .fill(Color.snapsBorder)
                        .frame(height: 1)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)

                    // Stats row
                    HStack(spacing: 0) {
                        heroStatCell(
                            label: "NET EARNINGS",
                            value: earningsString(playerStats.netEarnings),
                            valueColor: earningsColor(playerStats.netEarnings)
                        )
                        Divider()
                            .background(Color.snapsBorder)
                            .frame(height: 40)
                        heroStatCell(
                            label: "ROUNDS",
                            value: "\(playerStats.roundsPlayed)",
                            valueColor: Color.snapsTextPrimary
                        )
                        if selectedPlayer != nil {
                            Divider()
                                .background(Color.snapsBorder)
                                .frame(height: 40)
                            heroStatCell(
                                label: "WINS",
                                value: "\(playerStats.roundsWon)",
                                valueColor: Color.snapsTextPrimary
                            )
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.snapsGreen.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.snapsGreen.opacity(0.08), radius: 20, y: 8)
    }

    private func heroStatCell(label: String, value: String, valueColor: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(valueColor)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.snapsTextMuted)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Key Stats Grid

    private var keyStatsGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        let totalPotValue: String = selectedPlayer == nil
            ? "$\(String(format: "%.0f", playerStats.totalPotPlayed))"
            : earningsString(playerStats.netEarnings)

        return LazyVGrid(columns: columns, spacing: 12) {
            statCard(
                icon: "flame.fill",
                iconColor: Color.snapsGold,
                value: earningsString(playerStats.bestRound),
                label: "Best Round"
            )
            statCard(
                icon: "arrow.down.circle.fill",
                iconColor: Color.snapsDanger,
                value: earningsString(playerStats.worstRound),
                label: "Worst Round"
            )
            statCard(
                icon: "chart.line.uptrend.xyaxis",
                iconColor: Color.snapsGreen,
                value: earningsString(playerStats.avgPerRound),
                label: "Avg / Round"
            )
            statCard(
                icon: "dollarsign.circle.fill",
                iconColor: Color.snapsGold,
                value: totalPotValue,
                label: selectedPlayer == nil ? "Total Pot" : "Net Earnings"
            )
        }
        .padding(.horizontal, 20)
    }

    private func statCard(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.snapsTextPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.snapsTextMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.snapsSurface1)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.snapsBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Improvement Stats Section

    private var improvementStatsSection: some View {
        let dist = scoringDistribution
        let pb = parBreakdown
        let totalHoles = dist?.total ?? 0
        let hasGolfData = totalHoles > 0

        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("IMPROVE YOUR GAME")
                .padding(.horizontal, 20)

            if !hasGolfData {
                Text("Score data needed — use the 🎲 fill or play a full round")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.snapsTextMuted)
                    .padding(.horizontal, 20)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {

                    // 1. Scoring Avg vs Par
                    improveStat(
                        icon: "gauge.medium",
                        iconColor: Color.snapsGreen,
                        value: scoringAvgVsPar.map { v in
                            let s = String(format: "%.1f", abs(v))
                            return v <= 0 ? "-\(s)" : "+\(s)"
                        } ?? "—",
                        label: "Scoring Avg",
                        sub: "per round vs par",
                        highlight: scoringAvgVsPar.map { $0 <= 0 } ?? false
                    )

                    // 2. Best Round
                    improveStat(
                        icon: "trophy.fill",
                        iconColor: Color.snapsGold,
                        value: bestRoundVsPar.map { v in
                            v == 0 ? "E" : v < 0 ? "\(v)" : "+\(v)"
                        } ?? "—",
                        label: "Best Round",
                        sub: "vs par (18 holes)",
                        highlight: bestRoundVsPar.map { $0 <= 0 } ?? false
                    )

                    // 3. GIR %
                    improveStat(
                        icon: "flag.fill",
                        iconColor: girPct.map { $0 >= 50 ? Color.snapsGreen : Color.snapsGold } ?? Color.snapsTextMuted,
                        value: girPct.map { "\(String(format: "%.1f", $0))%" } ?? "—",
                        label: "Greens in Reg.",
                        sub: girPct != nil ? "track GIR on scorecard" : "tap GIR on each hole",
                        highlight: girPct.map { $0 >= 50 } ?? false
                    )

                    // 4. FWY %
                    improveStat(
                        icon: "arrow.up.forward",
                        iconColor: fairwaysPct.map { $0 >= 50 ? Color.snapsGreen : Color.snapsGold } ?? Color.snapsTextMuted,
                        value: fairwaysPct.map { "\(String(format: "%.1f", $0))%" } ?? "—",
                        label: "Fairways Hit",
                        sub: fairwaysPct != nil ? "par 4 & 5 holes" : "tap FWY on each hole",
                        highlight: fairwaysPct.map { $0 >= 55 } ?? false
                    )

                    // 5. Birdie Rate
                    let birdieCount = (dist?.eagles ?? 0) + (dist?.birdies ?? 0)
                    improveStat(
                        icon: "bird.fill",
                        iconColor: Color.snapsGreen,
                        value: totalHoles > 0 ? "\(String(format: "%.1f", Double(birdieCount) / Double(totalHoles) * 100))%" : "—",
                        label: "Birdie Rate",
                        sub: "\(birdieCount) of \(totalHoles) holes",
                        highlight: totalHoles > 0 && Double(birdieCount) / Double(totalHoles) > 0.1
                    )

                    // 6. Double+ Avoidance (% of holes WITHOUT double bogey or worse)
                    let doubleCount = dist?.doubles ?? 0
                    let doubleAvoidPct = totalHoles > 0 ? (1.0 - Double(doubleCount) / Double(totalHoles)) * 100 : 0.0
                    improveStat(
                        icon: "shield.fill",
                        iconColor: doubleAvoidPct >= 85 ? Color.snapsGreen : Color.snapsGold,
                        value: totalHoles > 0 ? "\(String(format: "%.1f", doubleAvoidPct))%" : "—",
                        label: "Double Avoidance",
                        sub: "\(totalHoles - doubleCount) clean of \(totalHoles)",
                        highlight: doubleAvoidPct >= 90
                    )

                    // 7. Par or Better %
                    let parOrBetter = (dist?.eagles ?? 0) + (dist?.birdies ?? 0) + (dist?.pars ?? 0)
                    let parOrBetterPct = totalHoles > 0 ? Double(parOrBetter) / Double(totalHoles) * 100 : 0.0
                    improveStat(
                        icon: "checkmark.circle.fill",
                        iconColor: Color.snapsGreen,
                        value: totalHoles > 0 ? "\(String(format: "%.1f", parOrBetterPct))%" : "—",
                        label: "Par or Better",
                        sub: "\(parOrBetter) of \(totalHoles) holes",
                        highlight: parOrBetterPct >= 50
                    )

                    // 8. Scoring Trend
                    let trend = scoringTrend
                    improveStat(
                        icon: trend.map { $0 > 0.5 ? "arrow.up.right.circle.fill" : ($0 < -0.5 ? "arrow.down.right.circle.fill" : "arrow.right.circle.fill") } ?? "circle.dashed",
                        iconColor: trend.map { $0 > 0.5 ? Color.snapsGreen : ($0 < -0.5 ? Color.snapsDanger : Color.snapsGold) } ?? Color.snapsTextMuted,
                        value: trend.map { v in
                            let s = String(format: "%.1f", abs(v))
                            if v > 0.5 { return "↗ \(s)" }
                            if v < -0.5 { return "↘ \(s)" }
                            return "→ Even"
                        } ?? "—",
                        label: "Trend",
                        sub: trend != nil ? "last 3 vs earlier" : "need 4+ rounds",
                        highlight: trend.map { $0 > 0.5 } ?? false
                    )

                    // 7. Par 3 Average
                    if let p3 = pb?.avg(for: 3) {
                        let diff = p3 - 3.0
                        improveStat(
                            icon: "3.circle.fill",
                            iconColor: diff <= 0 ? Color.snapsGreen : Color.snapsGold,
                            value: (diff >= 0 ? "+" : "") + String(format: "%.2f", diff),
                            label: "Par 3 Avg",
                            sub: String(format: "%.2f", p3) + " strokes",
                            highlight: diff <= 0
                        )
                    } else {
                        improveStat(icon: "3.circle.fill", iconColor: Color.snapsTextMuted, value: "—", label: "Par 3 Avg", sub: "no data", highlight: false)
                    }

                    // 8. Par 4 Average
                    if let p4 = pb?.avg(for: 4) {
                        let diff = p4 - 4.0
                        improveStat(
                            icon: "4.circle.fill",
                            iconColor: diff <= 0 ? Color.snapsGreen : Color.snapsGold,
                            value: (diff >= 0 ? "+" : "") + String(format: "%.2f", diff),
                            label: "Par 4 Avg",
                            sub: String(format: "%.2f", p4) + " strokes",
                            highlight: diff <= 0
                        )
                    } else {
                        improveStat(icon: "4.circle.fill", iconColor: Color.snapsTextMuted, value: "—", label: "Par 4 Avg", sub: "no data", highlight: false)
                    }

                    // 9. Par 5 Average
                    if let p5 = pb?.avg(for: 5) {
                        let diff = p5 - 5.0
                        improveStat(
                            icon: "5.circle.fill",
                            iconColor: diff <= 0 ? Color.snapsGreen : Color.snapsGold,
                            value: (diff >= 0 ? "+" : "") + String(format: "%.2f", diff),
                            label: "Par 5 Avg",
                            sub: String(format: "%.2f", p5) + " strokes",
                            highlight: diff <= 0
                        )
                    } else {
                        improveStat(icon: "5.circle.fill", iconColor: Color.snapsTextMuted, value: "—", label: "Par 5 Avg", sub: "no data", highlight: false)
                    }

                    // 10. Eagle Rate
                    let eagleCount = dist?.eagles ?? 0
                    improveStat(
                        icon: "star.fill",
                        iconColor: Color.snapsGold,
                        value: totalHoles > 0 ? "\(String(format: "%.1f", Double(eagleCount) / Double(totalHoles) * 100))%" : "—",
                        label: "Eagle Rate",
                        sub: "\(eagleCount) eagle\(eagleCount == 1 ? "" : "s") total",
                        highlight: eagleCount > 0
                    )
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func improveStat(icon: String, iconColor: Color, value: String, label: String, sub: String, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
                Spacer()
                if highlight {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.snapsGreen)
                }
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.snapsTextPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.snapsTextPrimary)
                Text(sub)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.snapsTextMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(highlight ? Color.snapsGreen.opacity(0.06) : Color.snapsSurface1)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(highlight ? Color.snapsGreen.opacity(0.3) : Color.snapsBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Earnings Trend Chart

    private var earningsTrendChart: some View {
        let pts = earningPoints
        let minY = pts.map(\.cumulative).min() ?? 0
        let maxY = pts.map(\.cumulative).max() ?? 1

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("EARNINGS TREND")
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 0) {
                Chart {
                    // Area gradient
                    ForEach(pts) { pt in
                        AreaMark(
                            x: .value("Round", pt.index),
                            y: .value("Earnings", pt.cumulative)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.snapsGreen.opacity(0.25), Color.snapsGreen.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    // Line
                    ForEach(pts) { pt in
                        LineMark(
                            x: .value("Round", pt.index),
                            y: .value("Earnings", pt.cumulative)
                        )
                        .foregroundStyle(Color.snapsGreen)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    }
                    // Break-even rule
                    RuleMark(y: .value("Break Even", 0))
                        .foregroundStyle(Color.white.opacity(0.2))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(earningsString(v))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(v >= 0 ? Color.snapsGreen : Color.snapsDanger)
                            }
                        }
                    }
                }
                .chartXAxis(.hidden)
                .chartYScale(domain: min(minY, 0)...max(maxY, 1))
                .frame(height: 160)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.snapsSurface1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.snapsBorder, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Scoring Distribution

    private func scoringDistributionSection(dist: ScoringDistribution) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SCORING")
                .padding(.horizontal, 20)

            VStack(spacing: 14) {
                scoringRow(emoji: "🦅", label: "Eagle+", count: dist.eagles, total: dist.total, color: Color.snapsGreen.opacity(0.8))
                scoringRow(emoji: "🐦", label: "Birdie", count: dist.birdies, total: dist.total, color: Color.snapsGreen)
                scoringRow(emoji: "⛳", label: "Par", count: dist.pars, total: dist.total, color: Color.white.opacity(0.6))
                scoringRow(emoji: "1️⃣", label: "Bogey", count: dist.bogeys, total: dist.total, color: Color.snapsGold)
                scoringRow(emoji: "2️⃣", label: "Double+", count: dist.doubles, total: dist.total, color: Color.snapsDanger)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.snapsSurface1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.snapsBorder, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
        }
    }

    private func scoringRow(emoji: String, label: String, count: Int, total: Int, color: Color) -> some View {
        let pct = total > 0 ? Double(count) / Double(total) : 0
        return HStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 16))
                .frame(width: 24)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.snapsTextSecondary)
                .frame(width: 70, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.snapsTextMuted.opacity(0.3))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(pct), height: 6)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 20)
            Text("\(Int(pct * 100))%")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.snapsTextSecondary)
                .frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: - Par Breakdown

    private func parBreakdownSection(_ pb: ParBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("BY PAR TYPE")
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                ForEach([3, 4, 5], id: \.self) { parVal in
                    parCard(parValue: parVal, avg: pb.avg(for: parVal))
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func parCard(parValue: Int, avg: Double?) -> some View {
        VStack(spacing: 8) {
            Text("PAR \(parValue)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.snapsTextMuted)
                .tracking(2)

            if let avg = avg {
                let diff = avg - Double(parValue)
                Text(String(format: "%.1f", avg))
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(avgScoreColor(diff: diff))

                Text(diffString(diff))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(avgScoreColor(diff: diff))
            } else {
                Text("—")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.snapsTextMuted)
                Text("no data")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.snapsTextMuted)
            }

            Text("avg on par \(parValue)")
                .font(.system(size: 10))
                .foregroundStyle(Color.snapsTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.snapsSurface1)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.snapsBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Game Mode Breakdown

    private var gameModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("BY GAME MODE")
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(gameModeBreakdown) { item in
                    HStack(spacing: 12) {
                        Text(item.mode.emoji)
                            .font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.mode.displayName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.snapsTextPrimary)
                            Text("\(item.roundsPlayed)x played")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.snapsTextMuted)
                        }
                        Spacer()
                        if item.isPlayerFiltered {
                            Text(earningsString(item.netEarnings))
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(earningsColor(item.netEarnings))
                        } else {
                            Text("$\(String(format: "%.0f", item.netEarnings))")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.snapsGold)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                    if item.id != gameModeBreakdown.last?.id {
                        Divider()
                            .background(Color.snapsBorder)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.snapsSurface1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.snapsBorder, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Head to Head

    private var headToHeadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("HEAD TO HEAD")
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(headToHead) { record in
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("vs \(record.opponentName)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.snapsTextPrimary)
                            Text("\(record.wins)W – \(record.losses)L – \(record.ties)T")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.snapsTextMuted)
                        }
                        Spacer()
                        // 60pt progress bar
                        GeometryReader { _ in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.snapsDanger.opacity(0.5))
                                    .frame(width: 60, height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.snapsGreen)
                                    .frame(width: 60 * CGFloat(record.winRate), height: 8)
                            }
                        }
                        .frame(width: 60, height: 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                    if record.id != headToHead.last?.id {
                        Divider()
                            .background(Color.snapsBorder)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.snapsSurface1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.snapsBorder, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Recent Rounds

    private var recentRoundsSection: some View {
        let recent = Array(filteredRounds.prefix(5))

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("RECENT ROUNDS")
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(recent, id: \.id) { round in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(round.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.snapsTextPrimary)
                            Text(round.date.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 12))
                                .foregroundStyle(Color.snapsTextMuted)
                        }
                        Spacer()
                        if let player = selectedPlayer,
                           let result = round.results.first(where: { $0.name == player }) {
                            Text(earningsString(result.netAmount))
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(earningsColor(result.netAmount))
                        } else if let winner = round.winner {
                            HStack(spacing: 4) {
                                Text("🏆")
                                    .font(.system(size: 14))
                                Text(winner.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.snapsGold)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                    if round.id != recent.last?.id {
                        Divider()
                            .background(Color.snapsBorder)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.snapsSurface1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.snapsBorder, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.snapsTextSecondary)
            .tracking(3)
    }

    private func earningsString(_ amount: Double) -> String {
        if amount >= 0 {
            return "+$\(String(format: "%.0f", amount))"
        } else {
            return "-$\(String(format: "%.0f", abs(amount)))"
        }
    }

    private func earningsColor(_ amount: Double) -> Color {
        amount >= 0 ? Color.snapsGreen : Color.snapsDanger
    }

    private func avgScoreColor(diff: Double) -> Color {
        if diff < 0 { return Color.snapsGreen }
        if diff == 0 { return Color.snapsTextPrimary }
        return Color.snapsDanger
    }

    private func diffString(_ diff: Double) -> String {
        if diff > 0 { return "+\(String(format: "%.1f", diff))" }
        if diff < 0 { return "\(String(format: "%.1f", diff))" }
        return "E"
    }
}

// End of StatsView
