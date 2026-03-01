import SwiftUI

// MARK: - LeaderboardView
struct LeaderboardView: View {
    @Environment(AppState.self) private var appState
    @State private var entries: [LeaderboardEntry] = []
    @State private var loading = true
    @State private var selectedStat: StatType = .winnings

    enum StatType: String, CaseIterable {
        case winnings = "💰 $"
        case rounds = "🏌️ Rounds"
        case winRate = "🏆 Win %"
        case bestScore = "⭐ Best"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Title
                HStack {
                    Text("SEASON LEADERBOARD")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                        .tracking(2)
                    Spacer()
                    Text("2026")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.snapsGreen)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Stat type picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(StatType.allCases, id: \.self) { stat in
                            Button {
                                withAnimation(.spring(duration: 0.3)) { selectedStat = stat }
                            } label: {
                                Text(stat.rawValue)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(selectedStat == stat ? .black : .white)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(
                                        selectedStat == stat ?
                                        Color.snapsGreen : Color.white.opacity(0.08),
                                        in: Capsule()
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 12)

                if loading {
                    Spacer()
                    ProgressView().tint(Color.snapsGreen)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { idx, entry in
                                LeaderboardRow(entry: entry, rank: idx + 1,
                                               statType: selectedStat,
                                               isCurrentUser: entry.userId == appState.currentUser?.id)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .task { await loadLeaderboard() }
    }

    var sortedEntries: [LeaderboardEntry] {
        entries.sorted {
            switch selectedStat {
            case .winnings: return $0.totalWinnings > $1.totalWinnings
            case .rounds:   return $0.roundsPlayed > $1.roundsPlayed
            case .winRate:  return $0.winRate > $1.winRate
            case .bestScore:
                let a = $0.bestScore ?? 999
                let b = $1.bestScore ?? 999
                return a < b
            }
        }
    }

    func loadLeaderboard() async {
        loading = true
        // Build from mock data — when Supabase is live, fetch all profiles' stats
        var result: [LeaderboardEntry] = []
        for profile in MockData.profiles {
            let stats = (try? await appState.repo.getStats(userId: profile.id)) ?? .empty
            result.append(LeaderboardEntry(
                id: profile.id, userId: profile.id,
                displayName: profile.displayName,
                roundsPlayed: stats.roundsPlayed,
                totalWinnings: stats.totalWinnings,
                winRate: stats.winRate,
                bestScore: stats.bestScore,
                favoriteGame: stats.favoriteGame
            ))
        }
        entries = result
        loading = false
    }
}

struct LeaderboardEntry: Identifiable {
    let id: String
    let userId: String
    let displayName: String
    let roundsPlayed: Int
    let totalWinnings: Double
    let winRate: Double
    let bestScore: Int?
    let favoriteGame: String?
}

// MARK: - Leaderboard Row
struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let rank: Int
    let statType: LeaderboardView.StatType
    let isCurrentUser: Bool

    var mainValue: String {
        switch statType {
        case .winnings:
            let v = entry.totalWinnings
            return v >= 0 ? "+$\(Int(v))" : "-$\(Int(abs(v)))"
        case .rounds:  return "\(entry.roundsPlayed)"
        case .winRate: return "\(Int(entry.winRate * 100))%"
        case .bestScore: return entry.bestScore.map { "\($0)" } ?? "—"
        }
    }

    var valueColor: Color {
        switch statType {
        case .winnings: return entry.totalWinnings >= 0 ? Color.snapsGreen : Color.snapsDanger
        case .winRate:  return entry.winRate > 0.5 ? Color.snapsGreen : .white
        default: return .white
        }
    }

    var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color.silverMedal
        case 3: return Color.bronzeMedal
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Rank
            ZStack {
                if rank <= 3 {
                    Circle()
                        .fill(rankColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                }
                Text(rank <= 3 ? ["🥇","🥈","🥉"][rank-1] : "#\(rank)")
                    .font(.system(size: rank <= 3 ? 20 : 14, weight: .black))
                    .foregroundStyle(rank <= 3 ? rankColor : .gray)
            }
            .frame(width: 36)

            // Avatar + name
            ZStack {
                Circle()
                    .fill(isCurrentUser ? Color.snapsGreen.opacity(0.2) : Color.white.opacity(0.08))
                    .frame(width: 40, height: 40)
                Text(String(entry.displayName.prefix(2)).uppercased())
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(isCurrentUser ? Color.snapsGreen : .white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    if isCurrentUser {
                        Text("YOU")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color.snapsGreen)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.snapsGreen.opacity(0.15), in: Capsule())
                    }
                }
                Text("\(entry.roundsPlayed) rounds")
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
            }

            Spacer()

            Text(mainValue)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(valueColor)
                .contentTransition(.numericText())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isCurrentUser ? Color.snapsGreen.opacity(0.06) : Color.snapsSurface1)
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isCurrentUser ? Color.snapsGreen.opacity(0.25) : Color.white.opacity(0.05), lineWidth: 1))
        )
        .shadow(color: rank == 1 ? .yellow.opacity(0.1) : .clear, radius: 8)
    }
}
