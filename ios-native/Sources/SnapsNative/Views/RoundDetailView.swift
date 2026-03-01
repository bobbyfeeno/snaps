import SwiftUI

// MARK: - RoundDetailView
// Read-only scorecard for a completed round pulled from RoundRecord (SwiftData)

struct RoundDetailView: View {
    let round: RoundRecord
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }

    var players: [PlayerSnapshot] { round.players }
    var pars: [Int] { round.pars }
    var scores: [String: [Int?]] { round.scores }
    var results: [PlayerResult] { round.results.sorted { $0.netAmount > $1.netAmount } }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 16) {
                        resultsSummary
                        scorecardGrid
                        if hasStatData { statSection }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(theme.surface2, in: Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text("ROUND RECAP")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(theme.textPrimary)
                    .tracking(2)
                Text(round.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            // Spacer to balance the button
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Results Summary

    private var resultsSummary: some View {
        VStack(spacing: 10) {
            // Winner callout
            if let winner = results.first, winner.netAmount > 0 {
                HStack(spacing: 10) {
                    Text("🏆")
                        .font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(winner.name)
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(theme.textPrimary)
                        Text("Won the round")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    Text("+$\(Int(winner.netAmount))")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.snapsGreen)
                }
                .padding(16)
                .background(Color.snapsGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.snapsGreen.opacity(0.2), lineWidth: 1))
            }

            // All player results
            HStack(spacing: 8) {
                ForEach(results, id: \.name) { result in
                    VStack(spacing: 4) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(result.netAmount > 0 ? Color.snapsGreen.opacity(0.18) : theme.surface2)
                                .frame(width: 38, height: 38)
                            Text(String(result.name.prefix(2)).uppercased())
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(result.netAmount > 0 ? Color.snapsGreen : theme.textSecondary)
                        }
                        Text(result.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)
                        Text(result.netAmount >= 0 ? "+$\(Int(result.netAmount))" : "-$\(Int(abs(result.netAmount)))")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(result.netAmount >= 0 ? Color.snapsGreen : Color.snapsDanger)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(14)
            .background(theme.surface1, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.border, lineWidth: 1))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Scorecard Grid

    private var scorecardGrid: some View {
        VStack(spacing: 0) {
            nineBlock(label: "OUT", start: 0, end: 9)
            Divider().background(theme.border).padding(.vertical, 6)
            nineBlock(label: "IN", start: 9, end: 18)
            Divider().background(theme.border).padding(.vertical, 6)
            totalsRow
        }
        .background(theme.surface1, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.border, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func nineBlock(label: String, start: Int, end: Int) -> some View {
        VStack(spacing: 0) {
            holeHeaderRow(start: start, end: end, label: label)
            parRow(start: start, end: end)
            ForEach(players, id: \.id) { player in
                playerScoreRow(player: player, start: start, end: end)
            }
        }
    }

    private func holeHeaderRow(start: Int, end: Int, label: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(theme.textMuted)
                .tracking(2)
                .frame(width: 64, alignment: .leading)
                .padding(.horizontal, 10)

            ForEach(start..<end, id: \.self) { i in
                Text("\(i + 1)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textMuted)
                    .frame(maxWidth: .infinity)
            }

            Text("—")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.textMuted)
                .frame(width: 32)
        }
        .frame(height: 28)
        .background(theme.surface2)
    }

    private func parRow(start: Int, end: Int) -> some View {
        HStack(spacing: 0) {
            Text("PAR")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.textMuted)
                .frame(width: 64, alignment: .leading)
                .padding(.horizontal, 10)

            ForEach(start..<end, id: \.self) { i in
                Text("\(pars[i])")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }

            let nineTotal = pars[start..<end].reduce(0, +)
            Text("\(nineTotal)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 32)
        }
        .frame(height: 30)
    }

    private func playerScoreRow(player: PlayerSnapshot, start: Int, end: Int) -> some View {
        let playerScores = scores[player.id] ?? Array(repeating: nil, count: 18)
        let nineScores = (start..<end).compactMap { playerScores[$0] }
        let nineTotal = nineScores.isEmpty ? nil : nineScores.reduce(0, +)
        let ninePar = pars[start..<end].reduce(0, +)

        return HStack(spacing: 0) {
            // Player name
            Text(player.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 64, alignment: .leading)
                .padding(.horizontal, 10)

            // Hole scores
            ForEach(start..<end, id: \.self) { i in
                scoreCell(score: playerScores[i], par: pars[i])
            }

            // Nine total
            if let total = nineTotal {
                let diff = total - ninePar
                Text("\(total)")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(diff < 0 ? Color.scoreBirdie : diff == 0 ? Color.scorePar : diff == 1 ? Color.scoreBogey : Color.scoreDouble)
                    .frame(width: 32)
            } else {
                Text("—")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textMuted)
                    .frame(width: 32)
            }
        }
        .frame(height: 34)
    }

    private func scoreCell(score: Int?, par: Int) -> some View {
        Group {
            if let s = score {
                let rel = s - par
                ZStack {
                    scoreBadge(rel: rel)
                    Text("\(s)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(scoreTextColor(rel: rel))
                }
            } else {
                Text("·")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func scoreBadge(rel: Int) -> some View {
        if rel <= -2 {
            // Eagle: double circle
            ZStack {
                Circle().strokeBorder(Color.scoreEagle, lineWidth: 1.5).frame(width: 22, height: 22)
                Circle().strokeBorder(Color.scoreEagle, lineWidth: 1).frame(width: 16, height: 16)
            }
        } else if rel == -1 {
            // Birdie: circle
            Circle().strokeBorder(Color.scoreBirdie, lineWidth: 1.5).frame(width: 22, height: 22)
        } else if rel == 1 {
            // Bogey: square
            RoundedRectangle(cornerRadius: 3).strokeBorder(Color.scoreBogey, lineWidth: 1.5).frame(width: 22, height: 22)
        } else if rel >= 2 {
            // Double+: double square
            ZStack {
                RoundedRectangle(cornerRadius: 3).strokeBorder(Color.scoreDouble, lineWidth: 1.5).frame(width: 22, height: 22)
                RoundedRectangle(cornerRadius: 2).strokeBorder(Color.scoreDouble, lineWidth: 1).frame(width: 16, height: 16)
            }
        }
    }

    private func scoreTextColor(rel: Int) -> Color {
        if rel <= -2 { return Color.scoreEagle }
        if rel == -1 { return Color.scoreBirdie }
        if rel == 0 { return Color.scorePar }
        if rel == 1 { return Color.scoreBogey }
        return Color.scoreDouble
    }

    private var totalsRow: some View {
        let allPlayersOut = players.map { player -> (String, [Int]) in
            let s = scores[player.id] ?? Array(repeating: nil, count: 18)
            return (player.id, (0..<9).compactMap { s[$0] })
        }
        let allPlayersIn = players.map { player -> (String, [Int]) in
            let s = scores[player.id] ?? Array(repeating: nil, count: 18)
            return (player.id, (9..<18).compactMap { s[$0] })
        }
        let outPar = pars[0..<9].reduce(0, +)
        let inPar = pars[9..<18].reduce(0, +)
        let totalPar = outPar + inPar

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("TOTAL")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(theme.textMuted)
                    .tracking(2)
                    .frame(width: 64, alignment: .leading)
                    .padding(.horizontal, 10)
                Text("OUT")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textMuted)
                    .frame(maxWidth: .infinity)
                Text("IN")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textMuted)
                    .frame(maxWidth: .infinity)
                Text("TOT")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 44)
            }
            .frame(height: 26)
            .background(theme.surface2)

            // Par row in totals
            HStack(spacing: 0) {
                Text("PAR")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.textMuted)
                    .frame(width: 64, alignment: .leading)
                    .padding(.horizontal, 10)
                Text("\(outPar)").font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.textSecondary).frame(maxWidth: .infinity)
                Text("\(inPar)").font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.textSecondary).frame(maxWidth: .infinity)
                Text("\(totalPar)").font(.system(size: 11, weight: .bold)).foregroundStyle(theme.textSecondary).frame(width: 44)
            }
            .frame(height: 30)

            ForEach(players, id: \.id) { player in
                let out = allPlayersOut.first(where: { $0.0 == player.id })?.1 ?? []
                let inn = allPlayersIn.first(where: { $0.0 == player.id })?.1 ?? []
                let total = out + inn
                let outTotal = out.isEmpty ? nil : out.reduce(0, +)
                let inTotal = inn.isEmpty ? nil : inn.reduce(0, +)
                let grandTotal = total.isEmpty ? nil : total.reduce(0, +)

                HStack(spacing: 0) {
                    Text(player.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(width: 64, alignment: .leading)
                        .padding(.horizontal, 10)

                    totalCell(score: outTotal, par: outPar, isGrand: false)
                    totalCell(score: inTotal, par: inPar, isGrand: false)
                    totalCell(score: grandTotal, par: totalPar, isGrand: true)
                }
                .frame(height: 36)
            }
        }
    }

    private func totalCell(score: Int?, par: Int, isGrand: Bool) -> some View {
        Group {
            if let s = score {
                let diff = s - par
                Text("\(s)")
                    .font(.system(size: isGrand ? 14 : 12, weight: isGrand ? .black : .bold, design: .monospaced))
                    .foregroundStyle(diff < 0 ? Color.snapsGreen : diff == 0 ? theme.textPrimary : Color.snapsDanger)
            } else {
                Text("—")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textMuted)
            }
        }
        .modifier(TotalCellFrame(isGrand: isGrand))
    }

    // MARK: - Stat Section (FWY / GIR / Putts if tracked)

    private var hasStatData: Bool {
        let pid = players.first?.id ?? ""
        let hasFwy = round.fairwayDirs[pid]?.contains(where: { $0 != nil }) ?? false
        let hasGir = round.greenDirs[pid]?.contains(where: { $0 != nil }) ?? false
        let hasPutts = round.putts[pid]?.contains(where: { $0 != nil }) ?? false
        return hasFwy || hasGir || hasPutts
    }

    private var statSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRACKING")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.textMuted)
                .tracking(3)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(players, id: \.id) { player in
                    playerStatRow(player: player)
                    if player.id != players.last?.id {
                        Divider().background(theme.border).padding(.horizontal, 16)
                    }
                }
            }
            .background(theme.surface1, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.border, lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    private func playerStatRow(player: PlayerSnapshot) -> some View {
        let fwyDirs = round.fairwayDirs[player.id] ?? Array(repeating: nil, count: 18)
        let girDirs = round.greenDirs[player.id] ?? Array(repeating: nil, count: 18)
        let puttsArr = round.putts[player.id] ?? Array(repeating: nil, count: 18)

        let fwyHit = fwyDirs.compactMap { $0 }.filter { $0 == "hit" }.count
        let fwyTotal = fwyDirs.compactMap { $0 }.count

        let girHit = girDirs.compactMap { $0 }.filter { $0 == "hit" }.count
        let girTotal = girDirs.compactMap { $0 }.count

        let puttValues = puttsArr.compactMap { $0 }
        let totalPutts = puttValues.reduce(0, +)
        let threePutts = puttValues.filter { $0 >= 3 }.count

        return HStack(spacing: 0) {
            // Name
            Text(player.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 80, alignment: .leading)
                .padding(.horizontal, 14)

            // FWY
            statChip(
                label: "FIR",
                value: fwyTotal > 0 ? "\(fwyHit)/\(fwyTotal)" : "—",
                color: fwyTotal > 0 ? (Double(fwyHit) / Double(fwyTotal) >= 0.55 ? Color.snapsGreen : Color.snapsGold) : theme.textMuted
            )

            // GIR
            statChip(
                label: "GIR",
                value: girTotal > 0 ? "\(girHit)/\(girTotal)" : "—",
                color: girTotal > 0 ? (Double(girHit) / Double(girTotal) >= 0.5 ? Color.snapsGreen : Color.snapsGold) : theme.textMuted
            )

            // Putts
            statChip(
                label: "PUTTS",
                value: puttValues.isEmpty ? "—" : "\(totalPutts)\(threePutts > 0 ? " (\(threePutts)×3)" : "")",
                color: puttValues.isEmpty ? theme.textMuted : threePutts == 0 ? Color.snapsGreen : Color.snapsDanger
            )
        }
        .padding(.vertical, 12)
    }

    private func statChip(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.textMuted)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }
}


private struct TotalCellFrame: ViewModifier {
    let isGrand: Bool
    func body(content: Content) -> some View {
        if isGrand {
            content.frame(width: 44)
        } else {
            content.frame(maxWidth: .infinity)
        }
    }
}
