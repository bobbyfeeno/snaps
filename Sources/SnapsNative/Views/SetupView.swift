import SwiftUI
import SwiftData

struct SetupView: View {
    @Bindable var game: ActiveGame
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var savedPlayers: [Player]
    var appState: AppState = .shared

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }

    @State private var selectedPlayerIds: Set<String> = []
    @State private var selectedModes: Set<GameMode> = [.keepScore]
    @State private var vegasTeamA: Set<String> = []
    @State private var vegasTeamB: Set<String> = []
    @State private var step = 0  // 0=games, 1=players, 2=config, 3+=team pickers
    @State private var showScoreCard = false
    @State private var showAddPlayer = false
    @State private var gameSearch: String = ""
    @State private var showRules = false

    // MARK: - Per-Game Config State

    // Tax Man
    @State private var taxAmount: Double = 10

    // Head to Head
    @State private var h2hBet: Double = 5
    @State private var h2hMode: String = "match"
    @State private var h2hPress: Bool = false
    @State private var h2hUseHandicaps: Bool = false

    // Nassau
    @State private var nassauFront: Double = 5
    @State private var nassauBack: Double = 5
    @State private var nassauOverall: Double = 5
    @State private var nassauUseHandicaps: Bool = false
    @State private var nassauPress: Bool = false

    // Skins
    @State private var skinsBet: Double = 5

    // Wolf
    @State private var wolfBet: Double = 2

    // Bingo Bango Bongo
    @State private var bbbBet: Double = 2

    // Snake
    @State private var snakeBet: Double = 10

    // Vegas
    @State private var vegasBet: Double = 1
    @State private var vegasFlipBird: Bool = false

    // Best Ball
    @State private var bestBallBet: Double = 5
    @State private var bestBallMode: String = "stroke"
    @State private var bestBallTeamA: Set<String> = []
    @State private var bestBallTeamB: Set<String> = []

    // Stableford
    @State private var stablefordBet: Double = 1

    // Rabbit
    @State private var rabbitBet: Double = 10

    // Dots / Junk
    @State private var dotsBet: Double = 2
    @State private var dotsEagle: Bool = true
    @State private var dotsBirdie: Bool = true
    @State private var dotsSandy: Bool = true
    @State private var dotsGreenie: Bool = true

    // Sixes
    @State private var sixesBet: Double = 5

    // Nines
    @State private var ninesBet: Double = 1

    // Scotch
    @State private var scotchBet: Double = 1
    @State private var scotchTeamA: Set<String> = []
    @State private var scotchTeamB: Set<String> = []

    // Closest to Pin
    @State private var ctpBet: Double = 5

    // Aces & Deuces
    @State private var acesDeucesBet: Double = 2

    // Quota
    @State private var quotaBet: Double = 1

    // Trouble
    @State private var troubleBet: Double = 2

    // Arnies
    @State private var arniesBet: Double = 5

    // Banker
    @State private var bankerBet: Double = 5

    // Hammer Modifier (shared)
    @State private var hammerEnabled: Bool = false

    // MARK: - Computed Properties

    var selectedPlayers: [Player] { savedPlayers.filter { selectedPlayerIds.contains($0.id) } }

    /// Logged-in user's display name (lowercase for comparison)
    var currentUserName: String { appState.currentUser?.displayName.lowercased() ?? "" }

    /// Players sorted so the logged-in user is always first
    var sortedPlayers: [Player] {
        savedPlayers.sorted { a, b in
            let aIsMe = a.name.lowercased() == currentUserName
            let bIsMe = b.name.lowercased() == currentUserName
            if aIsMe != bIsMe { return aIsMe }
            return a.createdAt < b.createdAt
        }
    }

    var needsTeamStep: Bool {
        selectedModes.contains(.vegas) ||
        selectedModes.contains(.bestBall) ||
        selectedModes.contains(.scotch)
    }

    var totalSteps: Int {
        var count = 3  // players, games, config
        if selectedModes.contains(.vegas) { count += 1 }
        if selectedModes.contains(.bestBall) { count += 1 }
        if selectedModes.contains(.scotch) { count += 1 }
        return count
    }

    var canProceed: Bool {
        switch step {
        case 0: return !selectedModes.isEmpty
        case 1:
            // Allow solo play if only Keep Score is selected
            if selectedModes == [.keepScore] {
                return selectedPlayerIds.count >= 1
            }
            return selectedPlayerIds.count >= 2
        case 2: return true  // config step always valid
        default:
            // Team picker steps
            let teamStep = step - 3
            let teamModes = getTeamModes()
            if teamStep < teamModes.count {
                switch teamModes[teamStep] {
                case .vegas:
                    return vegasTeamA.count >= 1 && vegasTeamB.count >= 1 && vegasTeamA.isDisjoint(with: vegasTeamB)
                case .bestBall:
                    return bestBallTeamA.count >= 1 && bestBallTeamB.count >= 1 && bestBallTeamA.isDisjoint(with: bestBallTeamB)
                case .scotch:
                    return scotchTeamA.count >= 2 && scotchTeamB.count >= 2 && scotchTeamA.isDisjoint(with: scotchTeamB)
                default:
                    return true
                }
            }
            return false
        }
    }

    func getTeamModes() -> [GameMode] {
        var modes: [GameMode] = []
        if selectedModes.contains(.vegas) { modes.append(.vegas) }
        if selectedModes.contains(.bestBall) { modes.append(.bestBall) }
        if selectedModes.contains(.scotch) { modes.append(.scotch) }
        return modes
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(theme.textSecondary)
                    }

                    Spacer()

                    Text(stepTitle)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(theme.textPrimary)
                        .tracking(2)

                    Spacer()

                    // Step dots — active = snapsGreen
                    HStack(spacing: 6) {
                        ForEach(0..<totalSteps, id: \.self) { i in
                            Circle()
                                .fill(i == step ? Color.snapsGreen : theme.border)
                                .frame(width: 8, height: 8)
                                .animation(.spring(response: 0.3), value: step)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                // Step content
                switch step {
                case 0: gamePicker
                case 1: playerPicker
                case 2: configPanels
                default: teamPickerForStep(step - 3)
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
                                    .foregroundStyle(theme.textPrimary)
                                    .frame(width: 56, height: 56)
                                    .background(theme.surface2, in: RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(theme.border, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(SnapsButtonStyle())
                        }

                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            if step < totalSteps - 1 {
                                withAnimation(.spring()) { step += 1 }
                            } else {
                                startGame()
                            }
                        } label: {
                            Text(step == totalSteps - 1 ? "Start Round →" : "Next →")
                                .font(.system(size: 17, weight: .black))
                                .foregroundStyle(canProceed ? .black : theme.textMuted)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    canProceed ? Color.snapsGreen : theme.surface2,
                                    in: RoundedRectangle(cornerRadius: 16)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(canProceed ? .clear : theme.border, lineWidth: 1)
                                )
                                .shadow(color: canProceed ? Color.snapsGreen.opacity(0.3) : .clear, radius: 12, y: 4)
                        }
                        .disabled(!canProceed)
                        .buttonStyle(SnapsButtonStyle())
                        .accessibilityLabel(step == totalSteps - 1 ? "Start the round" : "Continue to next step")
                    }

                    if step == 1 && selectedPlayerIds.isEmpty {
                        Text("Select at least one player to continue")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textSecondary)
                    }
                    if step >= 3 {
                        Text("Each player must be on exactly one team")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showScoreCard) {
            ScoreCardView(game: game)
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToYouTab)) { _ in
            dismiss()
        }
        .fullScreenCover(isPresented: $showRules) {
            RulesView()
        }
        .onChange(of: selectedModes) { _, newModes in
            if !newModes.contains(.vegas) {
                vegasTeamA = []
                vegasTeamB = []
            }
            if !newModes.contains(.bestBall) {
                bestBallTeamA = []
                bestBallTeamB = []
            }
            if !newModes.contains(.scotch) {
                scotchTeamA = []
                scotchTeamB = []
            }
        }
    }

    var stepTitle: String {
        switch step {
        case 0: return "PICK YOUR GAMES"
        case 1: return "ADD PLAYERS"
        case 2: return "CONFIGURE BETS"
        default:
            let teamStep = step - 3
            let teamModes = getTeamModes()
            if teamStep < teamModes.count {
                switch teamModes[teamStep] {
                case .vegas: return "VEGAS TEAMS"
                case .bestBall: return "BEST BALL TEAMS"
                case .scotch: return "SCOTCH TEAMS"
                default: return "TEAMS"
                }
            }
            return ""
        }
    }

    // MARK: - Player Picker

    var playerPicker: some View {
        ScrollView {
            LazyVStack(spacing: 10) {

                // ── Add New Player ────────────────────────────────
                Button { showAddPlayer = true } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.snapsGreen.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.snapsGreen)
                        }
                        Text("Add New Player")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.snapsGreen)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.snapsGreen.opacity(0.6))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.snapsGreen.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.snapsGreen.opacity(0.3), lineWidth: 1))
                    )
                }
                .buttonStyle(SnapsButtonStyle())

                // ── Saved Crew ────────────────────────────────────
                if !sortedPlayers.isEmpty {
                    sectionHeader("YOUR CREW")
                    ForEach(sortedPlayers) { player in
                        let selected = selectedPlayerIds.contains(player.id)
                        let isMe = player.name.lowercased() == currentUserName
                        Button {
                            if selected { selectedPlayerIds.remove(player.id) }
                            else { selectedPlayerIds.insert(player.id) }
                        } label: {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(selected ? Color.snapsGreen.opacity(0.2) : theme.surface2)
                                        .frame(width: 44, height: 44)
                                    Text(String(player.name.prefix(2)).uppercased())
                                        .font(.system(size: 14, weight: .black))
                                        .foregroundStyle(selected ? Color.snapsGreen : theme.textPrimary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(player.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(theme.textPrimary)
                                        if isMe {
                                            Text("YOU")
                                                .font(.system(size: 9, weight: .black))
                                                .foregroundStyle(.black)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(Color.snapsGreen, in: RoundedRectangle(cornerRadius: 4))
                                        }
                                    }
                                    Text("Handicap \(player.taxMan)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(theme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(selected ? Color.snapsGreen : theme.textMuted)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(selected ? Color.snapsGreen.opacity(0.08) : theme.surface1)
                                    .overlay(RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(
                                            selected ? Color.snapsGreen.opacity(0.4) : theme.border,
                                            lineWidth: 1))
                            )
                        }
                        .buttonStyle(SnapsButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .onAppear {
            autoSelectCurrentUser()
        }
        .sheet(isPresented: $showAddPlayer) {
            QuickAddPlayerSheet { name, taxMan in
                let player = Player(name: name, taxMan: taxMan)
                modelContext.insert(player)
                try? modelContext.save()
                selectedPlayerIds.insert(player.id)
            }
        }
    }

    // MARK: - Auto-select logged-in user

    func autoSelectCurrentUser() {
        guard let profile = appState.currentUser else { return }
        let displayName = profile.displayName

        // Find existing player matching this user's display name
        if let existing = savedPlayers.first(where: { $0.name.lowercased() == displayName.lowercased() }) {
            selectedPlayerIds.insert(existing.id)
        } else {
            // Create a Player record for the logged-in user and auto-select
            let me = Player(name: displayName)
            modelContext.insert(me)
            try? modelContext.save()
            selectedPlayerIds.insert(me.id)
        }
    }

    // MARK: - Game Picker

    var filteredModes: [GameMode] {
        let q = gameSearch.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return GameMode.allCases }
        return GameMode.allCases.filter {
            $0.displayName.lowercased().contains(q) || $0.emoji.contains(q)
        }
    }

    var gamePicker: some View {
        VStack(spacing: 0) {
            // Search bar + Rules link (OUTSIDE ScrollView for reliable taps)
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(gameSearch.isEmpty ? theme.textMuted : Color.snapsGreen)
                    TextField("Search games...", text: $gameSearch)
                        .font(.system(size: 15))
                        .foregroundStyle(theme.textPrimary)
                        .autocorrectionDisabled()
                    if !gameSearch.isEmpty {
                        Button { gameSearch = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(theme.textMuted)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.surface1)
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(gameSearch.isEmpty ? theme.border : Color.snapsGreen.opacity(0.5), lineWidth: 1))
                )

                // All Game Rules link
                HStack {
                    Spacer()
                    Button {
                        showRules = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "book.pages")
                                .font(.system(size: 12, weight: .semibold))
                            Text("All Game Rules")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(Color.snapsGreen)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.snapsGreen.opacity(0.1), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.snapsGreen.opacity(0.3), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // Scrollable game list
            ScrollView {
                LazyVStack(spacing: 10) {
                    if filteredModes.isEmpty {
                    VStack(spacing: 8) {
                        Text("🏌️")
                            .font(.system(size: 36))
                        Text("No games matching \"\(gameSearch)\"")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .padding(.top, 30)
                } else {
                    sectionHeader(gameSearch.isEmpty ? "GAME MODES" : "\(filteredModes.count) RESULTS")
                }

                ForEach(filteredModes, id: \.self) { mode in
                    let selected = selectedModes.contains(mode)
                    Button {
                        if selected { selectedModes.remove(mode) } else { selectedModes.insert(mode) }
                    } label: {
                        HStack(spacing: 14) {
                            Text(mode.emoji).font(.system(size: 28))
                            Text(mode.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            if mode == .vegas || mode == .bestBall || mode == .scotch {
                                Text("TEAMS")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.snapsGreen.opacity(0.7))
                                    .tracking(1)
                                    .padding(.trailing, 4)
                            }
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(selected ? Color.snapsGreen : theme.textMuted)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selected ? Color.snapsGreen.opacity(0.08) : theme.surface1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(
                                            selected ? Color.snapsGreen.opacity(0.4) : theme.border,
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(SnapsButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            }
        }
    }

    // MARK: - Config Panels

    var configPanels: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                sectionHeader("CONFIGURE BETS")

                ForEach(GameMode.allCases, id: \.self) { mode in
                    if selectedModes.contains(mode) {
                        configPanel(for: mode)
                    }
                }

                // Hammer modifier card (show if Vegas or match-based games selected)
                if shouldShowHammer {
                    configCard(title: "Hammer Modifier", emoji: "🔨") {
                        toggleRow("Enable Hammer", value: $hammerEnabled)
                        infoText("Double the stakes mid-hole. ×1 → ×2 → ×4 → ×8")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    var shouldShowHammer: Bool {
        selectedModes.contains(.vegas) ||
        selectedModes.contains(.headToHead) ||
        selectedModes.contains(.nassau) ||
        selectedModes.contains(.bestBall)
    }

    @ViewBuilder
    func configPanel(for mode: GameMode) -> some View {
        switch mode {
        case .keepScore:
            configCard(title: "Keep Score", emoji: "📋") {
                infoText("Score tracking only — no bets")
            }

        case .headToHead:
            configCard(title: "Head to Head", emoji: "🏆") {
                betRow("Bet Amount", value: $h2hBet)
                modePicker(selection: $h2hMode, options: [("match", "Match Play"), ("stroke", "Stroke Play")])
                if h2hMode == "match" {
                    toggleRow("Auto-Press at 2 Down", value: $h2hPress)
                }
                toggleRow("Use Handicaps", value: $h2hUseHandicaps)
            }

        case .taxman:
            configCard(title: "Tax Man", emoji: "💰") {
                betRow("Bet Amount", value: $taxAmount)
                infoText("Players who beat their TaxMan number collect; others pay")
            }

        case .nassau:
            configCard(title: "Nassau", emoji: "🏅") {
                betRow("Front 9", value: $nassauFront)
                betRow("Back 9", value: $nassauBack)
                betRow("Full 18", value: $nassauOverall)
                toggleRow("Auto-Press at 2 Down", value: $nassauPress)
                toggleRow("Use Handicaps", value: $nassauUseHandicaps)
            }

        case .skins:
            configCard(title: "Skins", emoji: "🎯") {
                betRow("Bet Per Skin", value: $skinsBet)
            }

        case .wolf:
            configCard(title: "Wolf", emoji: "🐺") {
                betRow("Bet Per Hole", value: $wolfBet)
            }

        case .bingoBangoBongo:
            configCard(title: "Bingo Bango Bongo", emoji: "🎯") {
                betRow("Bet Per Point", value: $bbbBet)
            }

        case .snake:
            configCard(title: "Snake", emoji: "🐍") {
                betRow("Snake Amount", value: $snakeBet)
            }

        case .vegas:
            configCard(title: "Vegas", emoji: "🎰") {
                betRow("Bet Per Point", value: $vegasBet)
                toggleRow("Flip the Bird 🐦", value: $vegasFlipBird)
            }

        case .bestBall:
            configCard(title: "Best Ball", emoji: "⚔️") {
                betRow("Bet Amount", value: $bestBallBet)
                modePicker(selection: $bestBallMode, options: [("stroke", "Stroke Play"), ("match", "Match Play")])
            }

        case .stableford:
            configCard(title: "Stableford", emoji: "📊") {
                betRow("Bet Per Point", value: $stablefordBet)
            }

        case .rabbit:
            configCard(title: "Rabbit", emoji: "🐰") {
                betRow("Rabbit Amount", value: $rabbitBet)
            }

        case .dots:
            configCard(title: "Dots / Junk", emoji: "⭐") {
                betRow("Bet Per Dot", value: $dotsBet)
                toggleRow("Eagle", value: $dotsEagle)
                toggleRow("Birdie", value: $dotsBirdie)
                toggleRow("Sandy", value: $dotsSandy)
                toggleRow("Greenie", value: $dotsGreenie)
            }

        case .sixes:
            configCard(title: "Sixes", emoji: "6️⃣") {
                betRow("Bet Per Segment", value: $sixesBet)
                infoText("4 players required · partners rotate every 6 holes")
            }

        case .nines:
            configCard(title: "Nines", emoji: "9️⃣") {
                betRow("Bet Per Point", value: $ninesBet)
                infoText("3 players · 9 pts distributed each hole (5-3-1)")
            }

        case .scotch:
            configCard(title: "Scotch", emoji: "🥃") {
                betRow("Bet Per Point", value: $scotchBet)
            }

        case .ctp:
            configCard(title: "Closest to Pin", emoji: "⛳") {
                betRow("Bet Amount", value: $ctpBet)
            }

        case .acesDeuces:
            configCard(title: "Aces & Deuces", emoji: "🎲") {
                betRow("Bet Per Hole", value: $acesDeucesBet)
            }

        case .quota:
            configCard(title: "Quota", emoji: "📈") {
                betRow("Bet Per Point", value: $quotaBet)
                infoText("Quota = 36 minus handicap. Edit in player profiles.")
            }

        case .trouble:
            configCard(title: "Trouble", emoji: "😈") {
                betRow("Bet Per Occurrence", value: $troubleBet)
            }

        case .arnies:
            configCard(title: "Arnies", emoji: "🦁") {
                betRow("Bet Amount", value: $arniesBet)
            }

        case .banker:
            configCard(title: "Banker", emoji: "🏦") {
                betRow("Default Bet", value: $bankerBet)
                infoText("Banker can override per hole during the round")
            }
        }
    }

    // MARK: - Config Card Helpers

    func configCard(title: String, emoji: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(emoji).font(.system(size: 20))
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
            }
            content()
        }
        .padding(16)
        .background(theme.surface1, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.border, lineWidth: 1))
    }

    func betRow(_ label: String, value: Binding<Double>, step: Double = 1, range: ClosedRange<Double> = 1...500) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            HStack(spacing: 0) {
                Button {
                    if value.wrappedValue > range.lowerBound { value.wrappedValue -= step }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(theme.surface2, in: RoundedRectangle(cornerRadius: 8))
                }
                Text("$\(Int(value.wrappedValue))")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.snapsGreen)
                    .frame(width: 60, alignment: .center)
                Button {
                    if value.wrappedValue < range.upperBound { value.wrappedValue += step }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(theme.surface2, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    func toggleRow(_ label: String, value: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Toggle("", isOn: value)
                .tint(Color.snapsGreen)
                .labelsHidden()
        }
    }

    func infoText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(theme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func modePicker(selection: Binding<String>, options: [(value: String, label: String)]) -> some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                Button {
                    selection.wrappedValue = option.value
                } label: {
                    Text(option.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selection.wrappedValue == option.value ? .black : theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            selection.wrappedValue == option.value ? Color.snapsGreen : theme.surface2,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
            }
        }
        .padding(4)
        .background(theme.surface2, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Team Picker for Step

    @ViewBuilder
    func teamPickerForStep(_ index: Int) -> some View {
        let teamModes = getTeamModes()
        if index < teamModes.count {
            switch teamModes[index] {
            case .vegas: vegasTeamPicker
            case .bestBall: bestBallTeamPicker
            case .scotch: scotchTeamPicker
            default: EmptyView()
            }
        } else {
            EmptyView()
        }
    }

    // MARK: - Vegas Team Picker

    var vegasTeamPicker: some View {
        teamTogglePicker(
            emoji: "🎰", title: "VEGAS TEAMS",
            description: "Lower concatenated score wins each hole",
            teamA: $vegasTeamA, teamB: $vegasTeamB,
            minPerTeam: 1
        )
    }

    // MARK: - Best Ball Team Picker

    var bestBallTeamPicker: some View {
        teamTogglePicker(
            emoji: "⚔️", title: "BEST BALL TEAMS",
            description: "Best score from each team counts per hole",
            teamA: $bestBallTeamA, teamB: $bestBallTeamB,
            minPerTeam: 1
        )
    }

    // MARK: - Scotch Team Picker

    var scotchTeamPicker: some View {
        teamTogglePicker(
            emoji: "🥃", title: "SCOTCH TEAMS",
            description: "Low ball (2pts) + low total (3pts) per hole",
            teamA: $scotchTeamA, teamB: $scotchTeamB,
            minPerTeam: 2
        )
    }

    // MARK: - Shared Team Toggle Picker

    func teamTogglePicker(
        emoji: String,
        title: String,
        description: String,
        teamA: Binding<Set<String>>,
        teamB: Binding<Set<String>>,
        minPerTeam: Int
    ) -> some View {
        let colorA = Color.snapsGreen
        let colorB = Color.snapsVenmo        // blue for Team B

        return ScrollView {
            VStack(spacing: 16) {
                // Info card
                HStack(spacing: 12) {
                    Text(emoji).font(.system(size: 26))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(theme.textPrimary)
                            .tracking(1)
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(theme.surface1, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.border, lineWidth: 1))

                // Team A / B header labels
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(colorA).frame(width: 8, height: 8)
                        Text("TEAM A").font(.system(size: 10, weight: .black)).foregroundStyle(colorA).tracking(1)
                    }
                    Text("·").foregroundStyle(theme.textMuted).padding(.horizontal, 6)
                    HStack(spacing: 4) {
                        Circle().fill(colorB).frame(width: 8, height: 8)
                        Text("TEAM B").font(.system(size: 10, weight: .black)).foregroundStyle(colorB).tracking(1)
                    }
                }

                // Player rows
                VStack(spacing: 8) {
                    ForEach(selectedPlayers) { player in
                        playerTeamRow(player: player, teamA: teamA, teamB: teamB, colorA: colorA, colorB: colorB)
                    }
                }

                // Team summary
                HStack(spacing: 0) {
                    teamSummaryColumn(
                        label: "TEAM A", color: colorA,
                        names: selectedPlayers.filter { teamA.wrappedValue.contains($0.id) }.map(\.name)
                    )
                    Rectangle().fill(theme.border).frame(width: 1)
                    teamSummaryColumn(
                        label: "TEAM B", color: colorB,
                        names: selectedPlayers.filter { teamB.wrappedValue.contains($0.id) }.map(\.name)
                    )
                }
                .background(theme.surface1, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.border, lineWidth: 1))

                // Unassigned warning
                let unassigned = selectedPlayers.filter {
                    !teamA.wrappedValue.contains($0.id) && !teamB.wrappedValue.contains($0.id)
                }
                if !unassigned.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("\(unassigned.map(\.name).joined(separator: ", ")) need a team")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    func playerTeamRow(
        player: Player,
        teamA: Binding<Set<String>>,
        teamB: Binding<Set<String>>,
        colorA: Color,
        colorB: Color
    ) -> some View {
        let onA = teamA.wrappedValue.contains(player.id)
        let onB = teamB.wrappedValue.contains(player.id)
        let accentColor: Color = onA ? colorA : onB ? colorB : theme.border

        return HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(onA ? colorA.opacity(0.18) : onB ? colorB.opacity(0.18) : theme.surface2)
                    .frame(width: 40, height: 40)
                Text(String(player.name.prefix(2)).uppercased())
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(onA ? colorA : onB ? colorB : theme.textSecondary)
            }

            Text(player.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.textPrimary)

            Spacer()

            // A / B toggle
            HStack(spacing: 4) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        if onA { teamA.wrappedValue.remove(player.id) }
                        else { teamA.wrappedValue.insert(player.id); teamB.wrappedValue.remove(player.id) }
                    }
                } label: {
                    Text("A")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(onA ? .black : theme.textMuted)
                        .frame(width: 38, height: 34)
                        .background(onA ? colorA : theme.surface2, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(SnapsButtonStyle())

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        if onB { teamB.wrappedValue.remove(player.id) }
                        else { teamB.wrappedValue.insert(player.id); teamA.wrappedValue.remove(player.id) }
                    }
                } label: {
                    Text("B")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(onB ? .black : theme.textMuted)
                        .frame(width: 38, height: 34)
                        .background(onB ? colorB : theme.surface2, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(SnapsButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(theme.surface1, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(accentColor.opacity(onA || onB ? 0.35 : 0.0), lineWidth: 1))
    }

    func teamSummaryColumn(label: String, color: Color, names: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(color)
                .tracking(2)
            if names.isEmpty {
                Text("No players yet")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textMuted)
            } else {
                ForEach(names, id: \.self) { name in
                    HStack(spacing: 6) {
                        Circle().fill(color).frame(width: 5, height: 5)
                        Text(name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }

    // MARK: - Section Header Helper

    func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(theme.textMuted)
            .tracking(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
    }

    // MARK: - Start Game

    func startGame() {
        let players = selectedPlayers.map { PlayerSnapshot.from($0) }

        var games: [GameEntry] = []
        for mode in GameMode.allCases where selectedModes.contains(mode) {
            var cfg = GameConfig()
            switch mode {
            case .keepScore:
                break  // no config

            case .headToHead:
                cfg.betAmount = h2hBet
                cfg.matchMode = h2hMode
                cfg.useHandicaps = h2hUseHandicaps
                cfg.autoPress = h2hPress

            case .taxman:
                cfg.taxAmount = taxAmount

            case .nassau:
                cfg.betFront = nassauFront
                cfg.betBack = nassauBack
                cfg.betOverall = nassauOverall
                cfg.useHandicaps = nassauUseHandicaps
                cfg.autoPress = nassauPress

            case .skins:
                cfg.betPerSkin = skinsBet

            case .wolf:
                cfg.betPerHole = wolfBet

            case .bingoBangoBongo:
                cfg.betAmount = bbbBet

            case .snake:
                cfg.betAmount = snakeBet

            case .vegas:
                cfg.betPerPoint = vegasBet
                cfg.flipBird = vegasFlipBird
                cfg.hammerEnabled = hammerEnabled

            case .bestBall:
                cfg.betAmount = bestBallBet
                cfg.matchMode = bestBallMode
                cfg.teamA = Array(bestBallTeamA)
                cfg.teamB = Array(bestBallTeamB)

            case .stableford:
                cfg.betAmount = stablefordBet

            case .rabbit:
                cfg.rabbitAmount = rabbitBet

            case .dots:
                cfg.betPerDot = dotsBet

            case .sixes:
                cfg.betPerSegment = sixesBet

            case .nines:
                cfg.betPerPoint = ninesBet

            case .scotch:
                cfg.betPerPoint = scotchBet
                cfg.teamA = Array(scotchTeamA)
                cfg.teamB = Array(scotchTeamB)

            case .ctp:
                cfg.betAmount = ctpBet

            case .acesDeuces:
                cfg.betPerHole = acesDeucesBet

            case .quota:
                cfg.betPerPoint = quotaBet

            case .trouble:
                cfg.betAmount = troubleBet

            case .arnies:
                cfg.betAmount = arniesBet

            case .banker:
                cfg.betAmount = bankerBet
            }
            games.append(GameEntry(mode: mode, config: cfg))
        }

        var setup = GameSetup(players: players, games: games)
        setup.vegasTeamA = Array(vegasTeamA)
        setup.vegasTeamB = Array(vegasTeamB)
        game.startGame(setup: setup)
        showScoreCard = true
    }
}
