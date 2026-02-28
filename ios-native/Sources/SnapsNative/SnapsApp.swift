import SwiftUI
import SwiftData

@main
struct SnapsApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Player.self, RoundRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(AppState.shared)
        }
        .modelContainer(sharedModelContainer)
    }
}

struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0
    @State private var showCreateGame = false
    @State private var showJoinGame = false
    @State private var createdSession: GameSession?

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)
                LeaderboardView()
                    .tag(1)
                ProfileView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Custom tab bar
            customTabBar
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showJoinGame) { JoinGameView() }
        .sheet(item: $createdSession) { session in LobbyView(session: session) }
    }

    var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(icon: "house.fill", label: "Home", tag: 0)
            tabButton(icon: "trophy.fill", label: "Leaders", tag: 1)
            
            // Create Game button (center)
            Button {
                showCreateGame = true
            } label: {
                VStack(spacing: 3) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color(hex: "#52FF20"), Color(hex: "#1a7005")],
                                                startPoint: .top, endPoint: .bottom))
                            .frame(width: 52, height: 52)
                            .shadow(color: Color(hex: "#39FF14").opacity(0.5), radius: 10, y: 3)
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.black)
                    }
                    Text("New Game").font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: "#39FF14"))
                }
            }
            .buttonStyle(SpringButtonStyle())
            .sheet(isPresented: $showCreateGame) {
                CreateGameView { session in
                    createdSession = session
                }
            }
            
            tabButton(icon: "person.fill", label: "Profile", tag: 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    func tabButton(icon: String, label: String, tag: Int) -> some View {
        Button { selectedTab = tag } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(selectedTab == tag ? Color(hex: "#39FF14") : .gray)
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(selectedTab == tag ? Color(hex: "#39FF14") : .gray)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Create Game View (wraps SetupView but creates a session instead)

struct CreateGameView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let onCreated: (GameSession) -> Void

    @State private var selectedModes: Set<GameMode> = [.taxman]
    @State private var vegasTeamA: Set<String> = []
    @State private var vegasTeamB: Set<String> = []
    @State private var step = 0
    @State private var loading = false

    var needsVegas: Bool { selectedModes.contains(.vegas) }
    var totalSteps: Int { needsVegas ? 2 : 1 }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundStyle(.gray)
                    }
                    Spacer()
                    Text(step == 0 ? "GAME MODES" : "VEGAS TEAMS")
                        .font(.system(size: 14, weight: .black)).foregroundStyle(.white).tracking(2)
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<totalSteps, id: \.self) { i in
                            Circle().fill(i == step ? Color(hex: "#39FF14") : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 16)

                if step == 0 {
                    // Game mode picker (reuse same grid logic)
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(GameMode.allCases, id: \.self) { mode in
                                let sel = selectedModes.contains(mode)
                                Button {
                                    if sel { selectedModes.remove(mode) } else { selectedModes.insert(mode) }
                                } label: {
                                    HStack(spacing: 14) {
                                        Text(mode.emoji).font(.system(size: 28))
                                        Text(mode.displayName).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                                        Spacer()
                                        Image(systemName: sel ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 22))
                                            .foregroundStyle(sel ? Color(hex: "#39FF14") : .gray.opacity(0.4))
                                    }
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(sel ? Color(hex: "#39FF14").opacity(0.08) : Color(hex: "#111111"))
                                            .overlay(RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(sel ? Color(hex: "#39FF14").opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1))
                                    )
                                }
                                .buttonStyle(SpringButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20).padding(.top, 8)
                    }
                }

                Spacer()

                Button {
                    if needsVegas && step == 0 { withAnimation(.spring()) { step = 1 } }
                    else { Task { await createGame() } }
                } label: {
                    Group {
                        if loading { ProgressView().tint(.black) }
                        else { Text(step == totalSteps - 1 ? "Create Game →" : "Next →")
                            .font(.system(size: 17, weight: .black)).foregroundStyle(.black) }
                    }
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(LinearGradient(colors: [Color(hex: "#52FF20"), Color(hex: "#1fa005")], startPoint: .top, endPoint: .bottom),
                                in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(SpringButtonStyle())
                .padding(.horizontal, 20).padding(.bottom, 40)
            }
        }
    }

    func createGame() async {
        loading = true
        let modes = selectedModes.map { mode -> SessionGameMode in
            SessionGameMode(mode: mode.rawValue, taxAmount: 10, betAmount: 5)
        }
        let session = try? await appState.repo.createSession(
            pars: Array(repeating: 4, count: 18),
            gameModes: modes,
            vegasTeamA: Array(vegasTeamA),
            vegasTeamB: Array(vegasTeamB)
        )
        loading = false
        if let s = session {
            dismiss()
            onCreated(s)
        }
    }
}
