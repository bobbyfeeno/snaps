import SwiftUI
import SwiftData
import Charts

// MARK: - Profile Image Helper
func profileImageName(for name: String) -> String {
    let lower = name.lowercased()
    if lower.contains("scottie") || lower.contains("scheffler") { return "profile-scottie" }
    if lower.contains("xander") || lower.contains("schauffele") { return "profile-xander" }
    if lower.contains("rory") || lower.contains("mcilroy") { return "profile-rory" }
    if lower.contains("bobby") || lower.contains("feeno") { return "profile-bobby" }
    // Default fallback — returns bobby's image for now
    return "profile-bobby"
}

// MARK: - YouView (merged Profile + Stats)

struct YouView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \RoundRecord.date, order: .reverse) private var rounds: [RoundRecord]
    @State private var isEditing = false
    @State private var selectedPlayer: String? = nil
    @State private var selectedRound: RoundRecord? = nil

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }
    var user: UserProfile { appState.currentUser ?? .empty }

    // MARK: - All Players
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

    // MARK: - Filtered Rounds
    private var filteredRounds: [RoundRecord] {
        guard let player = selectedPlayer else { return rounds }
        return rounds.filter { round in
            round.results.contains { $0.name == player }
        }
    }

    // MARK: - Player Stats
    private var playerStats: RoundStatsData {
        selectedPlayer != nil ? computeRoundStatsData(player: selectedPlayer!) : computeAllStats()
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
            if result.netAmount == round.results.map(\.netAmount).max() ?? 0 { wins += 1 }
        }
        let avg = played > 0 ? totalNet / Double(played) : 0
        return RoundStatsData(roundsPlayed: played, roundsWon: wins, netEarnings: totalNet,
                              bestRound: best == -Double.infinity ? 0 : best,
                              worstRound: worst == Double.infinity ? 0 : worst,
                              avgPerRound: avg, totalPotPlayed: totalPot)
    }

    private func computeAllStats() -> RoundStatsData {
        let played = rounds.count
        let totalPot = rounds.reduce(0.0) { $0 + $1.totalPot }
        return RoundStatsData(
            roundsPlayed: played, roundsWon: 0, netEarnings: 0,
            bestRound: rounds.compactMap { $0.results.map(\.netAmount).max() }.max() ?? 0,
            worstRound: rounds.compactMap { $0.results.map(\.netAmount).min() }.min() ?? 0,
            avgPerRound: played > 0 ? totalPot / Double(played) : 0,
            totalPotPlayed: totalPot
        )
    }

    // MARK: - Earnings Over Time
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

    // MARK: - Scoring Distribution
    private var scoringDistribution: ScoringDistribution? {
        guard let player = selectedPlayer else { return nil }
        var dist = ScoringDistribution()
        var hasData = false
        for round in filteredRounds {
            let pars = round.pars
            guard let playerScores = round.scores[round.players.first(where: { $0.name == player })?.id ?? ""] else { continue }
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

    // MARK: - Par Breakdown
    private var parBreakdown: ParBreakdown? {
        guard let player = selectedPlayer else { return nil }
        var breakdown = ParBreakdown()
        var hasData = false
        for round in filteredRounds {
            let pars = round.pars
            guard let playerScores = round.scores[round.players.first(where: { $0.name == player })?.id ?? ""] else { continue }
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

    // MARK: - Game Mode Breakdown
    private var gameModeBreakdown: [GameModeBreakdown] {
        var modeData: [GameMode: (rounds: Int, net: Double)] = [:]
        for round in filteredRounds {
            let gameModes = round.games.map(\.mode)
            let modeCount = gameModes.count
            if let player = selectedPlayer, let result = round.results.first(where: { $0.name == player }) {
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
        return modeData.map { mode, data in
            GameModeBreakdown(mode: mode, roundsPlayed: data.rounds, netEarnings: data.net, isPlayerFiltered: selectedPlayer != nil)
        }.sorted { abs($0.netEarnings) > abs($1.netEarnings) }
    }

    // MARK: - Head to Head
    private var headToHead: [HeadToHeadRecord] {
        guard let player = selectedPlayer else { return [] }
        var records: [String: (wins: Int, losses: Int, ties: Int)] = [:]
        for round in filteredRounds {
            guard let myResult = round.results.first(where: { $0.name == player }) else { continue }
            for other in round.results where other.name != player {
                let key = other.name
                if myResult.netAmount > other.netAmount { records[key, default: (0, 0, 0)].wins += 1 }
                else if myResult.netAmount < other.netAmount { records[key, default: (0, 0, 0)].losses += 1 }
                else { records[key, default: (0, 0, 0)].ties += 1 }
            }
        }
        return records.map { name, rec in
            HeadToHeadRecord(opponentName: name, wins: rec.wins, losses: rec.losses, ties: rec.ties)
        }.sorted { $0.wins + $0.losses + $0.ties > $1.wins + $1.losses + $1.ties }
    }

    // MARK: - Golf Improvement Metrics

    private var scoringAvgVsPar: Double? {
        guard let player = selectedPlayer else { return nil }
        var totalDiff = 0.0; var roundCount = 0
        for round in filteredRounds {
            let pars = round.pars; let totalPar = pars.reduce(0, +)
            guard let playerScores = round.scores[round.players.first(where: { $0.name == player })?.id ?? ""] else { continue }
            let played = playerScores.compactMap { $0 }
            guard played.count >= 9 else { continue }
            let adjPar = Double(totalPar) * Double(played.count) / 18.0
            totalDiff += Double(played.reduce(0, +)) - adjPar
            roundCount += 1
        }
        guard roundCount > 0 else { return nil }
        return totalDiff / Double(roundCount)
    }

    private var bestRoundVsPar: Int? {
        guard let player = selectedPlayer else { return nil }
        var best: Int? = nil
        for round in filteredRounds {
            let pars = round.pars; let totalPar = pars.reduce(0, +)
            guard let playerScores = round.scores[round.players.first(where: { $0.name == player })?.id ?? ""] else { continue }
            let played = playerScores.compactMap { $0 }
            guard played.count >= 18 else { continue }
            let diff = played.reduce(0, +) - totalPar
            if best == nil || diff < best! { best = diff }
        }
        return best
    }

    private var scoringTrend: Double? {
        guard let player = selectedPlayer else { return nil }
        let sorted = filteredRounds.sorted { $0.date < $1.date }
        var diffs: [Double] = []
        for round in sorted {
            let pars = round.pars; let totalPar = pars.reduce(0, +)
            guard let playerScores = round.scores[round.players.first(where: { $0.name == player })?.id ?? ""] else { continue }
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
        return earlierAvg - recentAvg
    }

    private var girPct: Double? {
        guard let player = selectedPlayer else { return nil }
        var hit = 0; var total = 0
        for round in filteredRounds {
            guard let playerGreens = round.greenDirs[round.players.first(where: { $0.name == player })?.id ?? ""] else { continue }
            for val in playerGreens { guard let v = val else { continue }; total += 1; if v == "hit" { hit += 1 } }
        }
        guard total > 0 else { return nil }
        return Double(hit) / Double(total) * 100
    }

    private var fairwaysPct: Double? {
        guard let player = selectedPlayer else { return nil }
        var hit = 0; var total = 0
        for round in filteredRounds {
            guard let playerFairways = round.fairwayDirs[round.players.first(where: { $0.name == player })?.id ?? ""] else { continue }
            for val in playerFairways { guard let v = val else { continue }; total += 1; if v == "hit" { hit += 1 } }
        }
        guard total > 0 else { return nil }
        return Double(hit) / Double(total) * 100
    }

    // MARK: - FIR Miss Direction Split (left% / right%)
    private var firMissSplit: (leftPct: Double, rightPct: Double)? {
        guard let player = selectedPlayer else { return nil }
        var left = 0; var right = 0; var total = 0
        for round in filteredRounds {
            guard let fwys = round.fairwayDirs[round.players.first(where: { $0.name == player })?.id ?? ""] else { continue }
            for val in fwys {
                guard let v = val, v != "hit" else { continue }
                total += 1
                if v == "left" { left += 1 } else if v == "right" { right += 1 }
            }
        }
        guard total > 0 else { return nil }
        return (Double(left) / Double(total) * 100, Double(right) / Double(total) * 100)
    }

    // MARK: - GIR Miss Direction Breakdown
    private var girMissBreakdown: (short: Int, long: Int, left: Int, right: Int, total: Int)? {
        guard let player = selectedPlayer else { return nil }
        var short = 0; var long = 0; var left = 0; var right = 0; var total = 0
        for round in filteredRounds {
            guard let greens = round.greenDirs[round.players.first(where: { $0.name == player })?.id ?? ""] else { continue }
            for val in greens {
                guard let v = val, v != "hit" else { continue }
                total += 1
                switch v {
                case "short": short += 1
                case "long": long += 1
                case "left": left += 1
                case "right": right += 1
                default: break
                }
            }
        }
        guard total > 0 else { return nil }
        return (short, long, left, right, total)
    }

    // MARK: - Avg Putts per Round
    private var avgPuttsPerRound: Double? {
        guard let player = selectedPlayer else { return nil }
        var totalPutts = 0; var roundCount = 0
        for round in filteredRounds {
            guard let playerPutts = round.putts[round.players.first(where: { $0.name == player })?.id ?? ""] else { continue }
            let entered = playerPutts.compactMap { $0 }
            guard entered.count >= 9 else { continue }
            totalPutts += entered.reduce(0, +)
            roundCount += 1
        }
        guard roundCount > 0 else { return nil }
        return Double(totalPutts) / Double(roundCount)
    }

    // MARK: - 3-Putt Count (total across all rounds)
    private var threePuttCount: Int? {
        guard let player = selectedPlayer else { return nil }
        var count = 0; var hasData = false
        for round in filteredRounds {
            guard let playerPutts = round.putts[round.players.first(where: { $0.name == player })?.id ?? ""] else { continue }
            for val in playerPutts {
                guard let v = val else { continue }
                hasData = true
                if v >= 3 { count += 1 }
            }
        }
        return hasData ? count : nil
    }

    private var winRateString: String {
        guard selectedPlayer != nil, playerStats.roundsPlayed > 0 else { return "—" }
        return "\(Int(Double(playerStats.roundsWon) / Double(playerStats.roundsPlayed) * 100))%"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    profileHeader
                        .padding(.top, 16)

                    if rounds.isEmpty {
                        emptyState.padding(.top, 40)
                    } else {
                        playerPicker.padding(.top, 20)

                        // ── PERFORMANCE ─────────────────────────────────
                        performanceHero.padding(.top, 16)

                        if let dist = scoringDistribution, dist.total > 0 {
                            scoringDistributionSection(dist: dist).padding(.top, 16)
                        }

                        if let pb = parBreakdown {
                            parBreakdownSection(pb).padding(.top, 16)
                        }

                        if selectedPlayer != nil {
                            improvementStatsSection.padding(.top, 16)
                        }

                        // ── BETTING ──────────────────────────────────────
                        bettingSectionDivider.padding(.top, 28)

                        bettingCard.padding(.top, 12)

                        if selectedPlayer != nil && earningPoints.count >= 2 {
                            earningsTrendChart.padding(.top, 16)
                        }

                        if !gameModeBreakdown.isEmpty {
                            gameModeSection.padding(.top, 16)
                        }

                        if selectedPlayer != nil && !headToHead.isEmpty {
                            headToHeadSection.padding(.top, 16)
                        }

                        recentRoundsSection
                            .padding(.top, 16)
                            .padding(.bottom, 100)
                    }
                }
            }
        }
        .onAppear {
            guard selectedPlayer == nil else { return }
            let userName = appState.currentUser?.displayName
            if let name = userName, allPlayers.contains(name) {
                selectedPlayer = name
            } else {
                selectedPlayer = allPlayers.first
            }
        }
        .sheet(isPresented: $isEditing) {
            EditProfileView().environment(appState)
        }
        .sheet(item: $selectedRound) { round in
            RoundDetailView(round: round)
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                // Profile photo with green border
                Image(profileImageName(for: user.displayName))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.snapsGreen, lineWidth: 3))
                    .shadow(color: Color.snapsGreen.opacity(0.35), radius: 14)
            }

            VStack(spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                Text("@\(user.username)")
                    .font(.system(size: 13))
                    .foregroundStyle(.gray)
                if user.handicap > 0 {
                    Text("HCP \(user.handicap)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.snapsGreen)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.snapsGreen.opacity(0.12), in: Capsule())
                }
            }

            if !user.venmoHandle.isEmpty || !user.cashappHandle.isEmpty {
                HStack(spacing: 12) {
                    if !user.venmoHandle.isEmpty {
                        paymentBadge("V", handle: user.venmoHandle, color: Color(hex: "#3D95CE"))
                    }
                    if !user.cashappHandle.isEmpty {
                        paymentBadge("$", handle: user.cashappHandle, color: Color(hex: "#00D632"))
                    }
                }
            }

            Button { isEditing = true } label: {
                Label("Edit Profile", systemImage: "pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(theme.surface1, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private func paymentBadge(_ prefix: String, handle: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(prefix)
                .font(.system(size: 11, weight: .black)).foregroundStyle(.white)
                .frame(width: 20, height: 20).background(color, in: Circle())
            Text(handle)
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.gray)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.snapsGreen.opacity(0.3))
            Text("No rounds yet")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(theme.textPrimary)
            Text("Complete a round to see your stats")
                .font(.system(size: 14))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Player Picker

    private var playerPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pillButton(label: "All", isSelected: selectedPlayer == nil) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedPlayer = nil }
                }
                ForEach(allPlayers, id: \.self) { name in
                    pillButton(label: name, isSelected: selectedPlayer == name) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedPlayer = name }
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
                .foregroundStyle(isSelected ? Color.black : theme.textSecondary)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Capsule().fill(isSelected ? Color.snapsGreen : theme.surface1))
        }
        .buttonStyle(SnapsButtonStyle())
    }

    // MARK: - Priority Stats (Score / FIR / GIR / Putts)

    // MARK: - Performance Hero (primary — golf stats)

    private var performanceHero: some View {
        let avgVsPar = scoringAvgVsPar
        let fir = fairwaysPct
        let gir = girPct
        let avgPutts = avgPuttsPerRound
        let threePutts = threePuttCount
        let firMiss = firMissSplit
        let girMiss = girMissBreakdown
        let scoreColor: Color = avgVsPar.map { $0 <= 0 ? Color.snapsGreen : Color.snapsGold } ?? theme.textPrimary

        return VStack(spacing: 12) {
            // Big score card
            VStack(spacing: 0) {
                // Score avg — the headline number
                VStack(spacing: 4) {
                    Text("SCORE AVG")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.textMuted)
                        .tracking(3)
                        .padding(.top, 20)

                    Text(avgVsPar.map { v in
                        let s = String(format: "%.1f", abs(v))
                        return v <= 0 ? "\(v > -0.05 ? "E" : "-\(s)")" : "+\(s)"
                    } ?? "—")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(scoreColor)

                    Text(avgVsPar != nil ? "per round vs par" : "no score data yet")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textMuted)
                        .padding(.bottom, 16)
                }

                // Divider
                Rectangle().fill(theme.border).frame(height: 1).padding(.horizontal, 20)

                // FIR | GIR | Putts row
                HStack(spacing: 0) {
                    perfStatCell(
                        value: fir.map { "\(Int($0))%" } ?? "—",
                        label: "FIR",
                        sub: firMiss.map { "← \(Int($0.leftPct))%  → \(Int($0.rightPct))%" },
                        color: fir.map { $0 >= 55 ? Color.snapsGreen : Color.snapsGold } ?? theme.textMuted
                    )
                    Rectangle().fill(theme.border).frame(width: 1, height: 52)
                    perfStatCell(
                        value: gir.map { "\(Int($0))%" } ?? "—",
                        label: "GIR",
                        sub: girMiss.map { "S\($0.short) L\($0.left) R\($0.right) Lng\($0.long)" },
                        color: gir.map { $0 >= 50 ? Color.snapsGreen : Color.snapsGold } ?? theme.textMuted
                    )
                    Rectangle().fill(theme.border).frame(width: 1, height: 52)
                    perfStatCell(
                        value: avgPutts.map { String(format: "%.1f", $0) } ?? "—",
                        label: "PUTTS",
                        sub: threePutts.map { "\($0) three-putt\($0 == 1 ? "" : "s")" },
                        color: avgPutts.map { $0 <= 30 ? Color.snapsGreen : ($0 <= 34 ? Color.snapsGold : Color.snapsDanger) } ?? theme.textMuted
                    )
                }
                .padding(.vertical, 14)
            }
            .background(theme.surface1, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(scoreColor.opacity(selectedPlayer != nil ? 0.25 : 0.08), lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }

    private func perfStatCell(value: String, label: String, sub: String?, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.textMuted)
                .tracking(1)
            if let s = sub {
                Text(s)
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Betting Section Divider

    private var bettingSectionDivider: some View {
        HStack(spacing: 10) {
            Rectangle().fill(theme.border).frame(height: 1)
            HStack(spacing: 5) {
                Text("💰")
                    .font(.system(size: 11))
                Text("BETTING")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(theme.textMuted)
                    .tracking(2)
            }
            Rectangle().fill(theme.border).frame(height: 1)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Betting Card (compact, secondary)

    private var bettingCard: some View {
        let net = playerStats.netEarnings
        let rounds = playerStats.roundsPlayed
        let winRate = rounds > 0 ? Int(Double(playerStats.roundsWon) / Double(rounds) * 100) : 0
        let best = playerStats.bestRound

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                bettingCell(value: earningsString(net), label: "NET", valueColor: earningsColor(net))
                Rectangle().fill(theme.border).frame(width: 1, height: 36)
                bettingCell(value: "\(rounds)", label: "ROUNDS", valueColor: theme.textPrimary)
                Rectangle().fill(theme.border).frame(width: 1, height: 36)
                bettingCell(value: selectedPlayer != nil ? "\(winRate)%" : "—", label: "WIN RATE", valueColor: theme.textPrimary)
                Rectangle().fill(theme.border).frame(width: 1, height: 36)
                bettingCell(value: earningsString(best), label: "BEST", valueColor: earningsColor(best))
            }
            .padding(.vertical, 16)
        }
        .background(theme.surface1, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.border, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private func bettingCell(value: String, label: String, valueColor: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(valueColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.textMuted)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Improvement Stats

    private var improvementStatsSection: some View {
        let dist = scoringDistribution
        let totalHoles = dist?.total ?? 0
        let hasGolfData = totalHoles > 0
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("IMPROVE YOUR GAME").padding(.horizontal, 20)

            if !hasGolfData {
                Text("Score data needed — use the 🎲 fill or play a full round")
                    .font(.system(size: 13)).foregroundStyle(theme.textMuted).padding(.horizontal, 20)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    improveStat(
                        icon: "gauge.medium", iconColor: Color.snapsGreen,
                        value: scoringAvgVsPar.map { v in
                            let s = String(format: "%.1f", abs(v)); return v <= 0 ? "-\(s)" : "+\(s)"
                        } ?? "—",
                        label: "Scoring Avg", sub: "per round vs par",
                        highlight: scoringAvgVsPar.map { $0 <= 0 } ?? false)

                    improveStat(
                        icon: "trophy.fill", iconColor: Color.snapsGold,
                        value: bestRoundVsPar.map { v in v == 0 ? "E" : v < 0 ? "\(v)" : "+\(v)" } ?? "—",
                        label: "Best Round", sub: "vs par (18 holes)",
                        highlight: bestRoundVsPar.map { $0 <= 0 } ?? false)

                    improveStat(
                        icon: "flag.fill",
                        iconColor: girPct.map { $0 >= 50 ? Color.snapsGreen : Color.snapsGold } ?? theme.textMuted,
                        value: girPct.map { "\(String(format: "%.1f", $0))%" } ?? "—",
                        label: "Greens in Reg.",
                        sub: girPct != nil ? "track GIR on scorecard" : "tap GIR on each hole",
                        highlight: girPct.map { $0 >= 50 } ?? false)

                    improveStat(
                        icon: "arrow.up.forward",
                        iconColor: fairwaysPct.map { $0 >= 50 ? Color.snapsGreen : Color.snapsGold } ?? theme.textMuted,
                        value: fairwaysPct.map { "\(String(format: "%.1f", $0))%" } ?? "—",
                        label: "Fairways Hit",
                        sub: fairwaysPct != nil ? "par 4 & 5 holes" : "tap FWY on each hole",
                        highlight: fairwaysPct.map { $0 >= 55 } ?? false)

                    let birdieCount = (dist?.eagles ?? 0) + (dist?.birdies ?? 0)
                    improveStat(
                        icon: "bird.fill", iconColor: Color.snapsGreen,
                        value: totalHoles > 0 ? "\(String(format: "%.1f", Double(birdieCount) / Double(totalHoles) * 100))%" : "—",
                        label: "Birdie Rate", sub: "\(birdieCount) of \(totalHoles) holes",
                        highlight: totalHoles > 0 && Double(birdieCount) / Double(totalHoles) > 0.1)

                    let doubleCount = dist?.doubles ?? 0
                    let doubleAvoidPct = totalHoles > 0 ? (1.0 - Double(doubleCount) / Double(totalHoles)) * 100 : 0.0
                    improveStat(
                        icon: "shield.fill",
                        iconColor: doubleAvoidPct >= 85 ? Color.snapsGreen : Color.snapsGold,
                        value: totalHoles > 0 ? "\(String(format: "%.1f", doubleAvoidPct))%" : "—",
                        label: "Double Avoidance", sub: "\(totalHoles - doubleCount) clean of \(totalHoles)",
                        highlight: doubleAvoidPct >= 90)

                    let parOrBetter = (dist?.eagles ?? 0) + (dist?.birdies ?? 0) + (dist?.pars ?? 0)
                    let parOrBetterPct = totalHoles > 0 ? Double(parOrBetter) / Double(totalHoles) * 100 : 0.0
                    improveStat(
                        icon: "checkmark.circle.fill", iconColor: Color.snapsGreen,
                        value: totalHoles > 0 ? "\(String(format: "%.1f", parOrBetterPct))%" : "—",
                        label: "Par or Better", sub: "\(parOrBetter) of \(totalHoles) holes",
                        highlight: parOrBetterPct >= 50)

                    let trend = scoringTrend
                    improveStat(
                        icon: trend.map { $0 > 0.5 ? "arrow.up.right.circle.fill" : ($0 < -0.5 ? "arrow.down.right.circle.fill" : "arrow.right.circle.fill") } ?? "circle.dashed",
                        iconColor: trend.map { $0 > 0.5 ? Color.snapsGreen : ($0 < -0.5 ? Color.snapsDanger : Color.snapsGold) } ?? theme.textMuted,
                        value: trend.map { v in
                            let s = String(format: "%.1f", abs(v))
                            if v > 0.5 { return "↗ \(s)" }
                            if v < -0.5 { return "↘ \(s)" }
                            return "→ Even"
                        } ?? "—",
                        label: "Trend", sub: trend != nil ? "last 3 vs earlier" : "need 4+ rounds",
                        highlight: trend.map { $0 > 0.5 } ?? false)

                    let pb2 = parBreakdown
                    if let p3 = pb2?.avg(for: 3) {
                        let diff = p3 - 3.0
                        improveStat(icon: "3.circle.fill", iconColor: diff <= 0 ? Color.snapsGreen : Color.snapsGold,
                            value: (diff >= 0 ? "+" : "") + String(format: "%.2f", diff),
                            label: "Par 3 Avg", sub: String(format: "%.2f", p3) + " strokes", highlight: diff <= 0)
                    } else {
                        improveStat(icon: "3.circle.fill", iconColor: theme.textMuted, value: "—", label: "Par 3 Avg", sub: "no data", highlight: false)
                    }

                    if let p4 = pb2?.avg(for: 4) {
                        let diff = p4 - 4.0
                        improveStat(icon: "4.circle.fill", iconColor: diff <= 0 ? Color.snapsGreen : Color.snapsGold,
                            value: (diff >= 0 ? "+" : "") + String(format: "%.2f", diff),
                            label: "Par 4 Avg", sub: String(format: "%.2f", p4) + " strokes", highlight: diff <= 0)
                    } else {
                        improveStat(icon: "4.circle.fill", iconColor: theme.textMuted, value: "—", label: "Par 4 Avg", sub: "no data", highlight: false)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func improveStat(icon: String, iconColor: Color, value: String, label: String, sub: String, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 16)).foregroundStyle(iconColor)
                Spacer()
                if highlight {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.snapsGreen)
                }
            }
            Text(value).font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.textPrimary).minimumScaleFactor(0.7).lineLimit(1)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.textPrimary)
                Text(sub).font(.system(size: 10)).foregroundStyle(theme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(highlight ? Color.snapsGreen.opacity(0.06) : theme.surface1)
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(highlight ? Color.snapsGreen.opacity(0.3) : theme.border, lineWidth: 1))
        )
    }

    // MARK: - Earnings Trend Chart

    private var earningsTrendChart: some View {
        let pts = earningPoints
        let minY = pts.map(\.cumulative).min() ?? 0
        let maxY = pts.map(\.cumulative).max() ?? 1

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("EARNINGS TREND").padding(.horizontal, 20)
            VStack {
                Chart {
                    ForEach(pts) { pt in
                        AreaMark(x: .value("Round", pt.index), y: .value("Earnings", pt.cumulative))
                            .foregroundStyle(LinearGradient(
                                colors: [Color.snapsGreen.opacity(0.25), Color.snapsGreen.opacity(0)],
                                startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                    }
                    ForEach(pts) { pt in
                        LineMark(x: .value("Round", pt.index), y: .value("Earnings", pt.cumulative))
                            .foregroundStyle(Color.snapsGreen)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)
                    }
                    RuleMark(y: .value("Break Even", 0))
                        .foregroundStyle(Color.white.opacity(0.2))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(earningsString(v)).font(.system(size: 9, weight: .medium))
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
            .background(RoundedRectangle(cornerRadius: 16).fill(theme.surface1)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.border, lineWidth: 1)))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Scoring Distribution

    private func scoringDistributionSection(dist: ScoringDistribution) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SCORING").padding(.horizontal, 20)
            VStack(spacing: 14) {
                scoringRow(emoji: "🦅", label: "Eagle+", count: dist.eagles, total: dist.total, color: Color.snapsGreen.opacity(0.8))
                scoringRow(emoji: "🐦", label: "Birdie", count: dist.birdies, total: dist.total, color: Color.snapsGreen)
                scoringRow(emoji: "⛳", label: "Par", count: dist.pars, total: dist.total, color: Color.white.opacity(0.6))
                scoringRow(emoji: "1️⃣", label: "Bogey", count: dist.bogeys, total: dist.total, color: Color.snapsGold)
                scoringRow(emoji: "2️⃣", label: "Double+", count: dist.doubles, total: dist.total, color: Color.snapsDanger)
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 16).fill(theme.surface1)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.border, lineWidth: 1)))
            .padding(.horizontal, 20)
        }
    }

    private func scoringRow(emoji: String, label: String, count: Int, total: Int, color: Color) -> some View {
        let pct = total > 0 ? Double(count) / Double(total) : 0
        return HStack(spacing: 10) {
            Text(emoji).font(.system(size: 16)).frame(width: 24)
            Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(theme.textSecondary)
                .frame(width: 70, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(theme.textMuted.opacity(0.3)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(color).frame(width: geo.size.width * CGFloat(pct), height: 6)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 20)
            Text("\(Int(pct * 100))%")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textSecondary).frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: - Par Breakdown

    private func parBreakdownSection(_ pb: ParBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("BY PAR TYPE").padding(.horizontal, 20)
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
            Text("PAR \(parValue)").font(.system(size: 10, weight: .bold)).foregroundStyle(theme.textMuted).tracking(2)
            if let avg = avg {
                let diff = avg - Double(parValue)
                Text(String(format: "%.1f", avg)).font(.system(size: 26, weight: .bold, design: .monospaced)).foregroundStyle(avgScoreColor(diff: diff))
                Text(diffString(diff)).font(.system(size: 11, weight: .semibold)).foregroundStyle(avgScoreColor(diff: diff))
            } else {
                Text("—").font(.system(size: 26, weight: .bold)).foregroundStyle(theme.textMuted)
                Text("no data").font(.system(size: 11)).foregroundStyle(theme.textMuted)
            }
            Text("avg on par \(parValue)").font(.system(size: 10)).foregroundStyle(theme.textMuted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 20)
        .background(RoundedRectangle(cornerRadius: 16).fill(theme.surface1)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.border, lineWidth: 1)))
    }

    // MARK: - Game Mode Breakdown

    private var gameModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("BY GAME MODE").padding(.horizontal, 20)
            VStack(spacing: 0) {
                ForEach(gameModeBreakdown) { item in
                    HStack(spacing: 12) {
                        Text(item.mode.emoji).font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.mode.displayName).font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.textPrimary)
                            Text("\(item.roundsPlayed)x played").font(.system(size: 12)).foregroundStyle(theme.textMuted)
                        }
                        Spacer()
                        if item.isPlayerFiltered {
                            Text(earningsString(item.netEarnings)).font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundStyle(earningsColor(item.netEarnings))
                        } else {
                            Text("$\(String(format: "%.0f", item.netEarnings))").font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundStyle(Color.snapsGold)
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    if item.id != gameModeBreakdown.last?.id {
                        Divider().background(theme.border).padding(.horizontal, 20)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(theme.surface1)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.border, lineWidth: 1)))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Head to Head

    private var headToHeadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("HEAD TO HEAD").padding(.horizontal, 20)
            VStack(spacing: 0) {
                ForEach(headToHead) { record in
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("vs \(record.opponentName)").font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.textPrimary)
                            Text("\(record.wins)W – \(record.losses)L – \(record.ties)T").font(.system(size: 12, weight: .medium)).foregroundStyle(theme.textMuted)
                        }
                        Spacer()
                        GeometryReader { _ in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4).fill(Color.snapsDanger.opacity(0.5)).frame(width: 60, height: 8)
                                RoundedRectangle(cornerRadius: 4).fill(Color.snapsGreen).frame(width: 60 * CGFloat(record.winRate), height: 8)
                            }
                        }
                        .frame(width: 60, height: 8)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    if record.id != headToHead.last?.id {
                        Divider().background(theme.border).padding(.horizontal, 20)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(theme.surface1)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.border, lineWidth: 1)))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Recent Rounds

    private var recentRoundsSection: some View {
        let recent = Array(filteredRounds.prefix(5))
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("RECENT ROUNDS").padding(.horizontal, 20)
            VStack(spacing: 0) {
                ForEach(recent, id: \.id) { round in
                    Button {
                        selectedRound = round
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(round.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(theme.textPrimary)
                                Text(round.date.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.textMuted)
                            }
                            Spacer()
                            if let player = selectedPlayer,
                               let result = round.results.first(where: { $0.name == player }) {
                                Text(earningsString(result.netAmount))
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundStyle(earningsColor(result.netAmount))
                            } else if let winner = round.winner {
                                HStack(spacing: 4) {
                                    Text("🏆").font(.system(size: 14))
                                    Text(winner.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.snapsGold)
                                }
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(theme.textMuted)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SnapsButtonStyle())
                    if round.id != recent.last?.id {
                        Divider().background(theme.border).padding(.horizontal, 20)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(theme.surface1)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.border, lineWidth: 1)))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.system(size: 11, weight: .bold)).foregroundStyle(theme.textSecondary).tracking(3)
    }

    private func earningsString(_ amount: Double) -> String {
        amount >= 0 ? "+$\(String(format: "%.0f", amount))" : "-$\(String(format: "%.0f", abs(amount)))"
    }

    private func earningsColor(_ amount: Double) -> Color { amount >= 0 ? Color.snapsGreen : Color.snapsDanger }

    private func avgScoreColor(diff: Double) -> Color {
        if diff < 0 { return Color.snapsGreen }
        if diff == 0 { return theme.textPrimary }
        return Color.snapsDanger
    }

    private func diffString(_ diff: Double) -> String {
        if diff > 0 { return "+\(String(format: "%.1f", diff))" }
        if diff < 0 { return "\(String(format: "%.1f", diff))" }
        return "E"
    }
}
