import SwiftUI
import SwiftData

extension Notification.Name {
    static let switchToYouTab = Notification.Name("switchToYouTab")
}

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
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var isLoggedIn: Bool = false
    @AppStorage("isDarkMode") private var isDarkMode = true

    var body: some View {
        ZStack {
            if isLoggedIn {
                mainTabView
                    .transition(.opacity)
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .animation(.easeInOut(duration: 0.3), value: isLoggedIn)
        .onAppear {
            DemoData.seedIfNeeded(context: modelContext)
            Task {
                if let repo = appState.repo as? SupabaseRepository {
                    // 1. Try to restore existing session
                    await repo.restoreSession()

                    if repo.currentUser() != nil {
                        appState.currentUser = repo.currentUser()
                        withAnimation { isLoggedIn = true }
                    } else {
                        // 2. Beta: auto-login with test account
                        do {
                            let profile = try await repo.signIn(
                                email: "neocognita@gmail.com",
                                password: "Flaming0andKoval"
                            )
                            appState.currentUser = profile
                            withAnimation { isLoggedIn = true }
                        } catch {
                            // Auto-login failed — show login screen normally
                        }
                    }
                }
            }
        }
    }

    var mainTabView: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)
                YouView()
                    .tag(1)
                TourView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .onReceive(NotificationCenter.default.publisher(for: .switchToYouTab)) { _ in
                withAnimation(.spring(response: 0.3)) {
                    selectedTab = 1
                }
            }

            // Custom tab bar
            customTabBar
        }
    }

    var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(icon: "house.fill", label: "Home", tag: 0)
            tabButton(icon: "person.fill", label: "You", tag: 1)
            tabButton(icon: "chart.xyaxis.line", label: "Pro Data", tag: 2)
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
                    .foregroundStyle(selectedTab == tag ? Color.snapsGreen : .gray)
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(selectedTab == tag ? Color.snapsGreen : .gray)
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
                            Circle().fill(i == step ? Color.snapsGreen : Color.gray.opacity(0.3))
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
                                            .foregroundStyle(sel ? Color.snapsGreen : .gray.opacity(0.4))
                                    }
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(sel ? Color.snapsGreen.opacity(0.08) : Color.snapsSurface1)
                                            .overlay(RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(sel ? Color.snapsGreen.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1))
                                    )
                                }
                                .buttonStyle(SnapsButtonStyle())
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
                    .background(LinearGradient(colors: [Color.snapsGreen, Color(hex: "#16803B")], startPoint: .top, endPoint: .bottom),
                                in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(SnapsButtonStyle())
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
