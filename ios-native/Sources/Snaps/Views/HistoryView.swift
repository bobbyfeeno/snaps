import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \RoundRecord.date, order: .reverse) private var rounds: [RoundRecord]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var groupedRounds: [String: [RoundRecord]] {
        Dictionary(grouping: rounds) { round in
            round.date.formatted(date: .abbreviated, time: .omitted)
        }
    }

    var sortedDates: [String] {
        groupedRounds.keys.sorted { a, b in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            let dateA = formatter.date(from: a) ?? Date.distantPast
            let dateB = formatter.date(from: b) ?? Date.distantPast
            return dateA > dateB
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("PAST ROUNDS")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)

                    Spacer()

                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                if rounds.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            .font(.system(size: 48))
                            .foregroundStyle(.gray.opacity(0.4))
                        Text("No rounds yet")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.gray)
                        Text("Complete a game to see it here")
                            .font(.system(size: 13))
                            .foregroundStyle(.gray.opacity(0.6))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20, pinnedViews: .sectionHeaders) {
                            ForEach(sortedDates, id: \.self) { dateStr in
                                Section {
                                    ForEach(groupedRounds[dateStr] ?? []) { round in
                                        RoundHistoryCard(round: round)
                                            .swipeActions {
                                                Button(role: .destructive) {
                                                    modelContext.delete(round)
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                    }
                                } header: {
                                    Text(dateStr)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.gray)
                                        .tracking(2)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.black)
                                }
                            }
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
        }
    }
}

struct RoundHistoryCard: View {
    let round: RoundRecord
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.3)) { expanded.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if let winner = round.winner {
                            HStack(spacing: 6) {
                                Text("🏆")
                                Text(winner.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }

                        Text(round.date, style: .time)
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("$\(String(format: "%.0f", round.totalPot)) pot")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Color.snapsGreen)

                        Text("\(round.players.count) players")
                            .font(.system(size: 11))
                            .foregroundStyle(.gray)
                    }

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.gray)
                        .padding(.leading, 8)
                }
                .padding(16)
            }

            if expanded {
                Divider().background(Color.white.opacity(0.08))

                VStack(spacing: 8) {
                    ForEach(round.results.sorted { $0.netAmount > $1.netAmount }) { result in
                        HStack {
                            Text(result.name)
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(result.netAmount >= 0 ? "+$\(String(format: "%.0f", result.netAmount))" : "-$\(String(format: "%.0f", abs(result.netAmount)))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(result.netAmount >= 0 ? Color.snapsGreen : Color.snapsDanger)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .background(Color.snapsSurface1, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}
