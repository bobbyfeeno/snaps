import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var history: [RoundHistory] = []
    @State private var stats: PlayerStats = .empty
    @State private var isEditing = false
    @State private var loading = true

    var user: UserProfile { appState.currentUser ?? .empty }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header card
                    profileHeader

                    // Stats row
                    statsRow

                    // History
                    historySection
                }
                .padding(.bottom, 40)
            }
        }
        .task { await loadData() }
        .sheet(isPresented: $isEditing) { EditProfileView() }
    }

    // MARK: - Profile Header

    var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.snapsGreen, Color(hex: "#1a7005")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 88, height: 88)
                    .shadow(color: Color.snapsGreen.opacity(0.4), radius: 16)
                Text(String(user.displayName.prefix(2)).uppercased())
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(.black)
            }

            VStack(spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
                Text("@\(user.username)")
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
                if user.handicap > 0 {
                    Text("HCP \(user.handicap)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.snapsGreen)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.snapsGreen.opacity(0.12), in: Capsule())
                }
            }

            // Payment handles
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

            Button {
                isEditing = true
            } label: {
                Label("Edit Profile", systemImage: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.snapsSurface1, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Stats Row

    var statsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                statCard("Rounds", value: "\(stats.roundsPlayed)", icon: "flag.fill", color: .white)
                statCard("Winnings", value: stats.totalWinnings >= 0 ? "+$\(Int(stats.totalWinnings))" : "-$\(Int(abs(stats.totalWinnings)))",
                         icon: "dollarsign.circle.fill",
                         color: stats.totalWinnings >= 0 ? Color.snapsGreen : Color.snapsDanger)
                statCard("Win Rate", value: "\(Int(stats.winRate * 100))%", icon: "trophy.fill", color: .yellow)
                statCard("Best Score", value: stats.bestScore.map { "\($0)" } ?? "—", icon: "star.fill", color: .orange)
                statCard("Avg Score", value: stats.roundsPlayed > 0 ? "\(Int(stats.averageScore))" : "—",
                         icon: "chart.bar.fill", color: .purple)
            }
            .padding(.horizontal, 20)
        }
    }

    func statCard(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.gray)
        }
        .frame(width: 90)
        .padding(.vertical, 16)
        .background(Color.snapsSurface1, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - History

    var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ROUND HISTORY")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.gray)
                .tracking(2)
                .padding(.horizontal, 20)

            if loading {
                ProgressView()
                    .tint(Color.snapsGreen)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if history.isEmpty {
                Text("No rounds yet — go play!")
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(history) { round in
                    RoundHistoryRow(round: round)
                }
            }
        }
    }

    func paymentBadge(_ prefix: String, handle: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(prefix)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(color, in: Circle())
            Text(handle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.gray)
        }
    }

    func loadData() async {
        loading = true
        guard let uid = appState.currentUser?.id else { loading = false; return }
        history = (try? await appState.repo.getRoundHistory(userId: uid)) ?? []
        stats = (try? await appState.repo.getStats(userId: uid)) ?? .empty
        loading = false
    }
}

struct RoundHistoryRow: View {
    let round: RoundHistory

    var body: some View {
        HStack(spacing: 14) {
            // Win/loss indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(round.netWinnings >= 0 ? Color.snapsGreen : Color.snapsDanger)
                .frame(width: 4)
                .frame(height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(round.courseName ?? "Unknown Course")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(round.playedAt, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(round.netWinnings >= 0 ? "+$\(Int(round.netWinnings))" : "-$\(Int(abs(round.netWinnings)))")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(round.netWinnings >= 0 ? Color.snapsGreen : Color.snapsDanger)
                Text("Score: \(round.totalScore)")
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.snapsSurface1, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.05), lineWidth: 1))
        .padding(.horizontal, 20)
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var venmo = ""
    @State private var cashapp = ""
    @State private var handicap = 0
    @State private var saving = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") { dismiss() }.foregroundStyle(.gray)
                    Spacer()
                    Text("EDIT PROFILE").font(.system(size: 14, weight: .black)).foregroundStyle(.white).tracking(2)
                    Spacer()
                    Button {
                        Task { await save() }
                    } label: {
                        if saving { ProgressView().tint(Color.snapsGreen) }
                        else { Text("Save").foregroundStyle(Color.snapsGreen) }
                    }
                    .disabled(saving)
                }
                .padding(.horizontal, 20).padding(.vertical, 16)

                Form {
                    Section("DISPLAY") {
                        TextField("Display Name", text: $displayName)
                        Stepper("Handicap: \(handicap)", value: $handicap, in: 0...54)
                    }
                    Section("PAYMENT HANDLES") {
                        TextField("Venmo @username", text: $venmo).textInputAutocapitalization(.never)
                        TextField("Cash App $cashtag", text: $cashapp).textInputAutocapitalization(.never)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .onAppear {
            let u = appState.currentUser ?? .empty
            displayName = u.displayName; venmo = u.venmoHandle
            cashapp = u.cashappHandle; handicap = u.handicap
        }
    }

    func save() async {
        saving = true
        guard var u = appState.currentUser else { saving = false; return }
        u.displayName = displayName; u.venmoHandle = venmo
        u.cashappHandle = cashapp; u.handicap = handicap
        try? await appState.repo.updateProfile(u)
        appState.currentUser = u
        saving = false
        dismiss()
    }
}
