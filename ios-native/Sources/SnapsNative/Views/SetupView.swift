import SwiftUI
import SwiftData

struct SetupView: View {
    @Bindable var game: ActiveGame
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var savedPlayers: [Player]

    @State private var selectedPlayerIds: Set<String> = []
    @State private var selectedModes: Set<GameMode> = [.taxman]
    @State private var vegasTeamA: Set<String> = []
    @State private var vegasTeamB: Set<String> = []
    @State private var step = 0  // 0=players, 1=games, 2=vegas teams (if needed)
    @State private var showScoreCard = false

    var selectedPlayers: [Player] { savedPlayers.filter { selectedPlayerIds.contains($0.id) } }
    var needsVegas: Bool { selectedModes.contains(.vegas) }
    var totalSteps: Int { needsVegas ? 3 : 2 }

    var canProceed: Bool {
        switch step {
        case 0: return selectedPlayerIds.count >= 2
        case 1: return !selectedModes.isEmpty
        case 2: return vegasTeamA.count >= 1 && vegasTeamB.count >= 1
                    && vegasTeamA.isDisjoint(with: vegasTeamB)
        default: return false
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.gray)
                    }

                    Spacer()

                    Text(stepTitle)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white)
                        .tracking(2)

                    Spacer()

                    // Step dots
                    HStack(spacing: 6) {
                        ForEach(0..<totalSteps, id: \.self) { i in
                            Circle()
                                .fill(i == step ? Color(hex: "#39FF14") : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                // Step content
                switch step {
                case 0: playerPicker
                case 1: gamePicker
                case 2: vegasTeamPicker
                default: EmptyView()
                }

                Spacer()

                // CTA
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        if step > 0 {
                            Button {
                                withAnimation(.spring()) { step -= 1 }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                            }
                        }

                        Button {
                            if step < totalSteps - 1 {
                                // If going from game select to next: skip vegas step if not needed
                                withAnimation(.spring()) { step += 1 }
                            } else {
                                startGame()
                            }
                        } label: {
                            Text(step == totalSteps - 1 ? "Start Round →" : "Next →")
                                .font(.system(size: 17, weight: .black))
                                .foregroundStyle(canProceed ? .black : .white.opacity(0.3))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    canProceed ?
                                    LinearGradient(colors: [Color(hex: "#52FF20"), Color(hex: "#1fa005")], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                                    in: RoundedRectangle(cornerRadius: 16)
                                )
                                .shadow(color: canProceed ? Color(hex: "#39FF14").opacity(0.3) : .clear, radius: 12, y: 4)
                        }
                        .disabled(!canProceed)
                    }

                    if step == 0 && savedPlayers.isEmpty {
                        Text("Add players first in the Players tab")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                    if step == 2 {
                        Text("Each player must be on exactly one team")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showScoreCard) {
            ScoreCardView(game: game)
        }
        .onChange(of: selectedModes) { _, newModes in
            // Reset vegas teams when modes change
            if !newModes.contains(.vegas) {
                vegasTeamA = []
                vegasTeamB = []
            }
        }
    }

    var stepTitle: String {
        switch step {
        case 0: return "SELECT PLAYERS"
        case 1: return "GAME MODES"
        case 2: return "VEGAS TEAMS"
        default: return ""
        }
    }

    // MARK: - Player Picker

    var playerPicker: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if savedPlayers.isEmpty {
                    ContentUnavailableView("No Players", systemImage: "person.badge.plus",
                        description: Text("Add players in the Players tab to get started"))
                        .foregroundStyle(.gray)
                        .padding(.top, 60)
                } else {
                    ForEach(savedPlayers) { player in
                        let selected = selectedPlayerIds.contains(player.id)
                        Button {
                            if selected { selectedPlayerIds.remove(player.id) }
                            else { selectedPlayerIds.insert(player.id) }
                        } label: {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(selected ? Color(hex: "#39FF14").opacity(0.2) : Color.white.opacity(0.08))
                                        .frame(width: 44, height: 44)
                                    Text(String(player.name.prefix(2)).uppercased())
                                        .font(.system(size: 14, weight: .black))
                                        .foregroundStyle(selected ? Color(hex: "#39FF14") : .white)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(player.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("TaxMan: \(player.taxMan)")
                                        .font(.system(size: 12)).foregroundStyle(.gray)
                                }
                                Spacer()
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(selected ? Color(hex: "#39FF14") : .gray.opacity(0.4))
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(selected ? Color(hex: "#39FF14").opacity(0.08) : Color(hex: "#111111"))
                                    .overlay(RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(selected ? Color(hex: "#39FF14").opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1))
                            )
                        }
                        .buttonStyle(SpringButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 8)
        }
    }

    // MARK: - Game Picker

    var gamePicker: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(GameMode.allCases, id: \.self) { mode in
                    let selected = selectedModes.contains(mode)
                    Button {
                        if selected { selectedModes.remove(mode) } else { selectedModes.insert(mode) }
                    } label: {
                        HStack(spacing: 14) {
                            Text(mode.emoji).font(.system(size: 28))
                            Text(mode.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            if mode == .vegas {
                                Text("Teams required")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(hex: "#39FF14").opacity(0.7))
                                    .padding(.trailing, 4)
                            }
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(selected ? Color(hex: "#39FF14") : .gray.opacity(0.4))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selected ? Color(hex: "#39FF14").opacity(0.08) : Color(hex: "#111111"))
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(selected ? Color(hex: "#39FF14").opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1))
                        )
                    }
                    .buttonStyle(SpringButtonStyle())
                }
            }
            .padding(.horizontal, 20).padding(.top, 8)
        }
    }

    // MARK: - Vegas Team Picker

    var vegasTeamPicker: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Explanation card
                HStack(spacing: 12) {
                    Text("🎰").font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Vegas needs 2 teams")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        Text("Lower concatenated score wins each hole")
                            .font(.system(size: 12)).foregroundStyle(.gray)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#39FF14").opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: "#39FF14").opacity(0.2), lineWidth: 1))

                // Team A
                teamColumn(
                    label: "TEAM A",
                    color: Color(hex: "#39FF14"),
                    team: $vegasTeamA,
                    other: vegasTeamB
                )

                // Team B
                teamColumn(
                    label: "TEAM B",
                    color: Color(hex: "#3D95CE"),
                    team: $vegasTeamB,
                    other: vegasTeamA
                )

                // Unassigned warning
                let unassigned = selectedPlayers.filter { !vegasTeamA.contains($0.id) && !vegasTeamB.contains($0.id) }
                if !unassigned.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("\(unassigned.map { $0.name }.joined(separator: ", ")) not assigned")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 20).padding(.top, 8)
        }
    }

    func teamColumn(label: String, color: Color, team: Binding<Set<String>>, other: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(color)
                    .tracking(2)
                Spacer()
                Text("\(team.wrappedValue.count) player\(team.wrappedValue.count == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
            }

            ForEach(selectedPlayers) { player in
                let onThisTeam = team.wrappedValue.contains(player.id)
                let onOther = other.contains(player.id)

                Button {
                    if onThisTeam {
                        team.wrappedValue.remove(player.id)
                    } else if !onOther {
                        team.wrappedValue.insert(player.id)
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(onThisTeam ? color.opacity(0.2) : Color.white.opacity(0.06))
                                .frame(width: 36, height: 36)
                            Text(String(player.name.prefix(2)).uppercased())
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(onThisTeam ? color : onOther ? .gray.opacity(0.3) : .white)
                        }
                        Text(player.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(onThisTeam ? .white : onOther ? .gray.opacity(0.3) : .white)
                        Spacer()
                        if onThisTeam {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(color)
                        } else if onOther {
                            Text("other team")
                                .font(.system(size: 11))
                                .foregroundStyle(.gray.opacity(0.4))
                        } else {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.gray.opacity(0.4))
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(onThisTeam ? color.opacity(0.08) : Color(hex: "#111111"))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(onThisTeam ? color.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1))
                    )
                    .opacity(onOther ? 0.4 : 1.0)
                }
                .disabled(onOther)
                .buttonStyle(SpringButtonStyle())
            }
        }
        .padding(14)
        .background(Color(hex: "#0f0f0f"), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(color.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Start Game

    func startGame() {
        let players = selectedPlayers.map { PlayerSnapshot.from($0) }
        let games = selectedModes.map { GameEntry(mode: $0, config: GameConfig(taxAmount: 10, betAmount: 5)) }
        var setup = GameSetup(players: players, games: games)
        setup.vegasTeamA = Array(vegasTeamA)
        setup.vegasTeamB = Array(vegasTeamB)
        game.startGame(setup: setup)
        showScoreCard = true
    }
}
