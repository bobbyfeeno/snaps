import SwiftUI

// MARK: - Lobby View (host creates game, players join and wait)

struct LobbyView: View {
    @Environment(AppState.self) private var appState
    let session: GameSession
    @State private var currentSession: GameSession
    @State private var polling = false
    @State private var showScoreCard = false
    @State private var game = ActiveGame()
    @Environment(\.dismiss) private var dismiss

    init(session: GameSession) {
        self.session = session
        _currentSession = State(initialValue: session)
    }

    var isHost: Bool { currentSession.hostId == appState.currentUser?.id }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        Task { try? await appState.repo.leaveSession(sessionId: currentSession.id); dismiss() }
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundStyle(.gray)
                    }
                    Spacer()
                    Text("LOBBY")
                        .font(.system(size: 16, weight: .black)).foregroundStyle(.white).tracking(2)
                    Spacer()
                    // Placeholder for alignment
                    Image(systemName: "xmark.circle.fill").font(.system(size: 24)).opacity(0)
                }
                .padding(.horizontal, 20).padding(.vertical, 16)

                ScrollView {
                    VStack(spacing: 20) {
                        // Join code card
                        joinCodeCard

                        // Game info
                        gameInfoCard

                        // Players list
                        playersCard

                        if isHost {
                            // Start button
                            Button {
                                Task { await startRound() }
                            } label: {
                                HStack {
                                    Image(systemName: "flag.fill")
                                    Text("Start Round")
                                }
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                                .background(
                                    LinearGradient(colors: [Color(hex: "#52FF20"), Color(hex: "#1fa005")], startPoint: .top, endPoint: .bottom),
                                    in: RoundedRectangle(cornerRadius: 16)
                                )
                                .shadow(color: Color(hex: "#39FF14").opacity(0.4), radius: 12, y: 4)
                            }
                            .buttonStyle(SpringButtonStyle())
                            .padding(.horizontal, 20)
                            .disabled(currentSession.players.count < 2)
                        } else {
                            // Waiting for host
                            HStack(spacing: 10) {
                                ProgressView().tint(Color(hex: "#39FF14"))
                                Text("Waiting for host to start...")
                                    .font(.system(size: 14)).foregroundStyle(.gray)
                            }
                            .padding()
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .task { await pollSession() }
        .fullScreenCover(isPresented: $showScoreCard) {
            ScoreCardView(game: game)
        }
    }

    // MARK: - Cards

    var joinCodeCard: some View {
        VStack(spacing: 8) {
            Text("INVITE CODE")
                .font(.system(size: 11, weight: .bold)).foregroundStyle(.gray).tracking(3)

            Text(currentSession.joinCode)
                .font(.system(size: 48, weight: .black, design: .monospaced))
                .foregroundStyle(Color(hex: "#39FF14"))
                .shadow(color: Color(hex: "#39FF14").opacity(0.5), radius: 12)

            Button {
                UIPasteboard.general.string = currentSession.joinCode
            } label: {
                Label("Copy Code", systemImage: "doc.on.doc")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            Text("Friends open Snaps → Join Game → enter this code")
                .font(.system(size: 11)).foregroundStyle(.gray).multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#39FF14").opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(hex: "#39FF14").opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    var gameInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GAME INFO").font(.system(size: 11, weight: .bold)).foregroundStyle(.gray).tracking(2)

            if let course = currentSession.courseName {
                infoRow("⛳", label: "Course", value: course)
            }
            infoRow("🎮", label: "Games", value: currentSession.gameModes.map {
                $0.mode.capitalized.replacingOccurrences(of: "-", with: " ")
            }.joined(separator: ", "))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#111111"), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    var playersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PLAYERS").font(.system(size: 11, weight: .bold)).foregroundStyle(.gray).tracking(2)
                Spacer()
                Text("\(currentSession.players.count) joined")
                    .font(.system(size: 12)).foregroundStyle(Color(hex: "#39FF14"))
            }

            ForEach(currentSession.players) { player in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(player.userId == currentSession.hostId ?
                                  Color(hex: "#39FF14").opacity(0.2) : Color.white.opacity(0.08))
                            .frame(width: 40, height: 40)
                        Text(String(player.displayName.prefix(2)).uppercased())
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(player.userId == currentSession.hostId ?
                                             Color(hex: "#39FF14") : .white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(player.displayName)
                                .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                            if player.userId == currentSession.hostId {
                                Text("HOST")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(Color(hex: "#39FF14"))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color(hex: "#39FF14").opacity(0.15), in: Capsule())
                            }
                        }
                        Text("TM \(player.taxman)")
                            .font(.system(size: 11)).foregroundStyle(.gray)
                    }
                    Spacer()
                    // Online indicator
                    Circle()
                        .fill(Color(hex: "#39FF14"))
                        .frame(width: 8, height: 8)
                        .shadow(color: Color(hex: "#39FF14"), radius: 4)
                }
            }
        }
        .padding(16)
        .background(Color(hex: "#111111"), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    func infoRow(_ emoji: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(emoji)
            Text(label).font(.system(size: 13)).foregroundStyle(.gray)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Actions

    func pollSession() async {
        // Poll every 3s to simulate real-time (Supabase will use subscriptions)
        while !Task.isCancelled {
            if let updated = try? await appState.repo.getSession(id: currentSession.id) {
                currentSession = updated
                if updated.status == .active {
                    setupAndStartGame()
                    return
                }
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }
    }

    func startRound() async {
        try? await appState.repo.startSession(id: currentSession.id)
        currentSession.status = .active
        setupAndStartGame()
    }

    func setupAndStartGame() {
        let players = currentSession.players.map { sp in
            PlayerSnapshot(id: sp.userId, name: sp.displayName, taxMan: sp.taxman,
                           venmoHandle: sp.venmoHandle, cashappHandle: sp.cashappHandle)
        }
        let gameModes = currentSession.gameModes.compactMap { sgm -> GameEntry? in
            guard let mode = GameMode(rawValue: sgm.mode) else { return nil }
            return GameEntry(mode: mode, config: GameConfig(taxAmount: sgm.taxAmount, betAmount: sgm.betAmount))
        }
        var setup = GameSetup(players: players, games: gameModes)
        setup.vegasTeamA = currentSession.vegasTeamA
        setup.vegasTeamB = currentSession.vegasTeamB
        game.pars = currentSession.pars
        game.startGame(setup: setup)
        showScoreCard = true
    }
}

// MARK: - Join Game View

struct JoinGameView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var loading = false
    @State private var error: String?
    @State private var joinedSession: GameSession?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundStyle(.gray)
                    }
                    Spacer()
                    Text("JOIN GAME").font(.system(size: 14, weight: .black)).foregroundStyle(.white).tracking(2)
                    Spacer()
                    Color.clear.frame(width: 24, height: 24)
                }
                .padding(.horizontal, 20).padding(.top, 16)

                Spacer()

                VStack(spacing: 24) {
                    Text("🎮").font(.system(size: 56))

                    Text("Enter the 6-digit code\nfrom your friend")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    // Code input
                    TextField("SNAP01", text: $code)
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(hex: "#39FF14"))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .onChange(of: code) { _, v in code = String(v.prefix(6)).uppercased() }
                        .padding(20)
                        .background(Color(hex: "#111111"), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(
                            code.count == 6 ? Color(hex: "#39FF14").opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1))

                    if let err = error {
                        Text(err)
                            .font(.system(size: 13)).foregroundStyle(Color(hex: "#ff4444"))
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await joinGame() }
                    } label: {
                        Group {
                            if loading {
                                ProgressView().tint(.black)
                            } else {
                                Text("Join Game →")
                                    .font(.system(size: 18, weight: .black)).foregroundStyle(.black)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(
                            code.count == 6 ?
                            LinearGradient(colors: [Color(hex: "#52FF20"), Color(hex: "#1fa005")], startPoint: .top, endPoint: .bottom) :
                            LinearGradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.15)], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .disabled(code.count != 6 || loading)
                    .buttonStyle(SpringButtonStyle())
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
        .sheet(item: $joinedSession) { session in
            LobbyView(session: session)
        }
    }

    func joinGame() async {
        loading = true; error = nil
        do {
            let session = try await appState.repo.joinSession(joinCode: code)
            joinedSession = session
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
