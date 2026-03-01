import SwiftUI
import UIKit

struct ScoreCardView: View {
    @Bindable var game: ActiveGame
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showResults = false
    @State private var showGrid = false

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }
    var setup: GameSetup { game.setup ?? GameSetup(players: [], games: []) }

    // MARK: - Live Standings

    var liveStandings: [(name: String, display: String, color: Color)] {
        guard let setup = game.setup else { return [] }

        // Calculate current net based on scores entered so far
        var extras = GameExtras(pars: game.pars)
        extras.wolf = game.wolfHoles
        extras.bbb = game.bbbHoles
        extras.snake = game.snakeHoles
        extras.ctp = game.ctpHoles
        extras.trouble = game.troubleHoles
        extras.arnies = game.arniesHoles
        extras.banker = game.bankerHoles
        extras.dots = game.dotsHoles
        extras.vegasTeamA = setup.vegasTeamA
        extras.vegasTeamB = setup.vegasTeamB
        extras.pressMatches = game.pressMatches

        let engineResult = calcAllGames(players: setup.players, games: setup.games, scores: game.scores, extras: extras)

        return setup.players.map { player in
            let net = engineResult.combinedNet[player.name] ?? 0
            let display = net > 0 ? "+$\(Int(net))" : net < 0 ? "-$\(Int(abs(net)))" : "$0"
            let color: Color = net > 0 ? Color.snapsGreen : net < 0 ? Color.snapsDanger : theme.textSecondary
            return (player.name, display, color)
        }.sorted { lhs, rhs in
            // Sort by color priority: green first
            let lhsPriority = lhs.color == Color.snapsGreen ? 1 : 0
            let rhsPriority = rhs.color == Color.snapsGreen ? 1 : 0
            return lhsPriority > rhsPriority
        }
    }

    // MARK: - Auto-Press Logic

    func checkAndFirePresses() {
        guard let setup = game.setup else { return }
        let hole = game.currentHole
        guard hole < 17 else { return }  // no press on hole 18

        // Nassau auto-press
        for nassauGame in setup.games where nassauGame.mode == .nassau {
            guard nassauGame.config.autoPress == true else { continue }
            let betAmount = nassauGame.config.betFront ?? nassauGame.config.betAmount ?? 5

            // Check front 9 (holes 0-8), back 9 (holes 9-17)
            let segments: [(start: Int, end: Int, name: String)] = [
                (0, 8, "front"), (9, 17, "back")
            ]
            for seg in segments {
                guard hole >= seg.start && hole <= seg.end else { continue }

                // Calculate current standings in this segment
                var totals: [(id: String, name: String, total: Int)] = []
                for player in setup.players {
                    var sum = 0; var complete = true
                    for h in seg.start...hole {
                        guard let s = game.scores[player.id]?[h] else { complete = false; break }
                        sum += s
                    }
                    if complete { totals.append((player.id, player.name, sum)) }
                }
                guard totals.count >= 2 else { continue }
                let minTotal = totals.map { $0.total }.min()!
                let leaders = totals.filter { $0.total == minTotal }
                guard leaders.count == 1 else { continue }

                for trailer in totals where trailer.total > minTotal {
                    let diff = trailer.total - minTotal
                    if diff == 2 {
                        let pressStartHole = hole + 1
                        // Only fire once (check if press already exists for this start hole)
                        let alreadyPressed = game.pressMatches.contains {
                            $0.game == "nassau" && $0.startHole == pressStartHole
                        }
                        if !alreadyPressed {
                            game.pressMatches.append(PressMatch(
                                startHole: pressStartHole,
                                endHole: seg.end,
                                game: "nassau",
                                betAmount: betAmount
                            ))
                            // Haptic feedback
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        }
                    }
                }
            }
        }

        // H2H auto-press
        for h2hGame in setup.games where h2hGame.mode == .headToHead {
            guard h2hGame.config.autoPress == true, h2hGame.config.matchMode == "match" else { continue }
            let betAmount = h2hGame.config.betAmount ?? 5

            let players = setup.players
            for i in 0..<players.count {
                for j in (i+1)..<players.count {
                    let a = players[i]; let b = players[j]
                    var aUp = 0
                    for h in 0...hole {
                        guard let aS = game.scores[a.id]?[h], let bS = game.scores[b.id]?[h] else { continue }
                        if aS < bS { aUp += 1 } else if bS < aS { aUp -= 1 }
                    }
                    let deficit = abs(aUp)
                    if deficit == 2 {
                        let pressStartHole = hole + 1
                        let tag = "h2h-\(a.id)-\(b.id)"
                        let alreadyPressed = game.pressMatches.contains {
                            $0.game == tag && $0.startHole == pressStartHole
                        }
                        if !alreadyPressed {
                            game.pressMatches.append(PressMatch(
                                startHole: pressStartHole,
                                endHole: 17,
                                game: tag,
                                betAmount: betAmount
                            ))
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        }
                    }
                }
            }
        }
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerBar

                // Hole cards (swipeable)
                TabView(selection: $game.currentHole) {
                    ForEach(0..<18, id: \.self) { hole in
                        HoleCard(game: game, hole: hole, setup: setup)
                            .tag(hole)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Footer
                footerBar
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showGrid) {
            ScorecardGridView(game: game, setup: setup)
        }
        .sheet(isPresented: $showResults) {
            ResultsView(game: game)
        }
        .onChange(of: game.setup == nil) { _, isNil in
            if isNil { dismiss() }
        }
    }

    // MARK: - Debug: Fill demo scores
    func fillDemoScores() {
        guard let setup = game.setup else { return }
        // Realistic offsets per player/hole — mix of birdies, pars, bogeys, dbl bogeys
        let offsets: [[Int]] = [
            [ 0,-1, 1, 0,-1, 0, 0, 1, 0,  0, 1,-1, 0, 1,-1, 0, 0, 1],
            [-1, 0, 0, 1, 0,-1, 1, 0, 1, -1, 0, 0, 1, 0, 0,-1, 1, 0],
            [ 1, 1, 0,-1, 0, 0,-1, 0, 1,  0,-1, 1, 0, 0, 1, 1,-1, 0],
            [ 0, 0,-1, 0, 1,-1, 0, 1, 0,  1, 0,-1, 0, 1, 0,-1, 0, 1],
        ]
        for (idx, player) in setup.players.enumerated() {
            let row = offsets[idx % offsets.count]
            for hole in 0..<18 {
                let par = game.pars[hole]
                game.setScore(playerId: player.id, hole: hole, score: max(1, par + row[hole]))
            }
        }
        game.currentHole = 17
    }

    var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(theme.surface2, in: Circle())
            }

            Spacer()

            // Hole indicator dots — active hole has snapsGreen
            HStack(spacing: 4) {
                ForEach(0..<18, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i == game.currentHole ? Color.snapsGreen : theme.border)
                        .frame(
                            width: i == game.currentHole ? 14 : 5,
                            height: i == game.currentHole ? 8 : 5
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: game.currentHole)
                }
            }

            Spacer()

            // Hole number + grid toggle + debug fill
            HStack(spacing: 8) {
                Text("H\(game.currentHole + 1)")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.snapsGreen)

                Button {
                    fillDemoScores()
                } label: {
                    Text("🎲")
                        .font(.system(size: 16))
                        .frame(width: 36, height: 36)
                        .background(theme.surface2, in: RoundedRectangle(cornerRadius: 8))
                }

                Button {
                    showGrid = true
                } label: {
                    Image(systemName: "tablecells")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(theme.surface2, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    var footerBar: some View {
        VStack(spacing: 12) {
            // Live money standings
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(liveStandings, id: \.name) { standing in
                        VStack(spacing: 2) {
                            Text(standing.name)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(theme.textSecondary)
                            Text(standing.display)
                                .font(.system(size: 15, weight: .black, design: .monospaced))
                                .foregroundStyle(standing.color)
                        }
                        .frame(minWidth: 52)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(theme.surface2, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 16)
            }

            // Calculate / Next hole
            HStack(spacing: 12) {
                if game.currentHole < 17 {
                    Button {
                        checkAndFirePresses()
                        withAnimation(.spring()) {
                            game.currentHole += 1
                        }
                    } label: {
                        HStack {
                            Text("Next Hole")
                                .font(.system(size: 16, weight: .bold))
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(theme.surface2, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(SnapsButtonStyle())
                }

                Button {
                    showResults = true
                } label: {
                    Text(game.currentHole == 17 ? "Calculate Payout →" : "End Early →")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.snapsGreen, in: RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.snapsGreen.opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(SnapsButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(theme.surface1)
    }
}

// MARK: - Hole Card
struct HoleCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var game: ActiveGame
    let hole: Int
    let setup: GameSetup

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Par selector
                parRow

                Divider().background(theme.border)

                // Player score rows
                ForEach(setup.players) { player in
                    PlayerScoreRow(game: game, player: player, hole: hole)
                }

                // Per-hole game tracking
                let modes = Set(setup.games.map { $0.mode })
                let manualModes: Set<GameMode> = [.wolf, .bingoBangoBongo, .snake, .ctp, .trouble, .arnies, .banker, .dots]
                if !modes.intersection(manualModes).isEmpty {
                    HoleTrackerView(game: game, hole: hole, setup: setup)
                }
            }
            .padding(20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(theme.surface1)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(theme.border, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.6), radius: 20)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    var parRow: some View {
        HStack {
            Text("PAR")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.textSecondary)
                .tracking(2)

            Spacer()

            HStack(spacing: 20) {
                Button {
                    if game.pars[hole] > 3 {
                        game.pars[hole] -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(theme.textMuted)
                }

                Text("\(game.pars[hole])")
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .frame(minWidth: 40)

                Button {
                    if game.pars[hole] < 5 {
                        game.pars[hole] += 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.snapsGreen.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Player Score Row
struct PlayerScoreRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var game: ActiveGame
    let player: PlayerSnapshot
    let hole: Int
    @State private var bounceScale: CGFloat = 1.0
    @State private var voice = VoiceScoreManager()

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }

    var score: Int? { game.getScore(playerId: player.id, hole: hole) }
    var relToPar: Int? { game.relToPar(playerId: player.id, hole: hole) }

    /// Foreground text color for the score number
    var scoreColor: Color {
        guard let rel = relToPar else { return theme.textPrimary }
        if rel <= -2 { return Color.scoreEagle }
        if rel == -1 { return Color.scoreBirdie }
        if rel == 0  { return Color.scorePar }
        if rel == 1  { return Color.scoreBogey }
        return Color.scoreDouble
    }

    /// Background tint inside the score circle
    var scoreBgColor: Color {
        guard let rel = relToPar else { return .clear }
        if rel <= -2 { return Color.scoreEagle.opacity(0.18) }
        if rel == -1 { return Color.scoreBirdie.opacity(0.15) }
        if rel == 0  { return .clear }
        if rel == 1  { return Color.scoreBogey.opacity(0.15) }
        return Color.scoreDouble.opacity(0.18)
    }

    var body: some View {
        let par = game.pars[hole]
        let fwyDir: String? = game.fairwayDirs[player.id]?[hole] ?? nil
        let girDir: String? = game.greenDirs[player.id]?[hole] ?? nil
        let puttCount: Int? = game.putts[player.id]?[hole] ?? nil

        VStack(spacing: 8) {
            // Row 1: Player name + Score stepper
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text("TM \(player.taxMan)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.snapsGreen)
                }

                Spacer()

                HStack(spacing: 10) {
                    VoiceScoreButton(par: game.pars[hole]) { s in
                        game.setScore(playerId: player.id, hole: hole, score: s)
                    }

                    Button {
                        let current = score ?? game.pars[hole]
                        if current > 1 {
                            withAnimation(.spring(duration: 0.2)) { bounceScale = 0.9 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.spring(duration: 0.2)) { bounceScale = 1.0 }
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            game.setScore(playerId: player.id, hole: hole, score: current - 1)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(score != nil ? theme.textSecondary : theme.textMuted)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Decrease score")
                    .accessibilityHint("Subtract one stroke")

                    ZStack {
                        Circle()
                            .fill(score != nil ? scoreBgColor : .clear)
                            .overlay(Circle().strokeBorder(
                                score != nil ? scoreColor.opacity(0.6) : theme.border, lineWidth: 2))
                            .frame(width: 52, height: 52)
                        if let s = score {
                            Text("\(s)")
                                .font(.snapsScoreNumber)
                                .foregroundStyle(scoreColor)
                                .shadow(color: scoreColor.opacity(0.5),
                                        radius: (relToPar != nil && relToPar != 0) ? 8 : 0)
                        } else {
                            Text("—")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(theme.textMuted)
                        }
                    }
                    .scaleEffect(bounceScale)

                    Button {
                        let current = score ?? (game.pars[hole] - 1)
                        withAnimation(.spring(duration: 0.2)) { bounceScale = 1.1 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(duration: 0.2)) { bounceScale = 1.0 }
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        game.setScore(playerId: player.id, hole: hole, score: current + 1)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.snapsGreen.opacity(score != nil ? 0.85 : 0.5))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Increase score")
                    .accessibilityHint("Add one stroke")
                }
            }

            // Row 2: FWY direction (par4/5) + Putts
            HStack(spacing: 10) {
                if par >= 4 {
                    FwyDirPicker(dir: fwyDir) { newDir in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        game.fairwayDirs[player.id]?[hole] = newDir
                    }
                }
                PuttsStepper(count: puttCount) { newCount in
                    game.putts[player.id]?[hole] = newCount
                }
                Spacer()
            }

            // Row 3: GIR direction
            GirDirPicker(dir: girDir) { newDir in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                game.greenDirs[player.id]?[hole] = newDir
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Fairway Direction Picker (3-state: hit / left / right)
struct FwyDirPicker: View {
    @Environment(\.colorScheme) private var colorScheme
    let dir: String?
    let onChange: (String?) -> Void

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }
    private let options: [(label: String, value: String)] = [
        ("← L", "left"), ("✓ FIR", "hit"), ("R →", "right")
    ]

    var body: some View {
        HStack(spacing: 0) {
            Text("FWY")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.textMuted)
                .padding(.trailing, 6)
            HStack(spacing: 2) {
                ForEach(options, id: \.value) { opt in
                    let selected = dir == opt.value
                    let isHit = opt.value == "hit"
                    Button {
                        onChange(selected ? nil : opt.value)
                    } label: {
                        Text(opt.label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(selected
                                ? (isHit ? Color.snapsGreen : Color.snapsDanger)
                                : theme.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                selected
                                    ? (isHit ? Color.snapsGreen.opacity(0.18) : Color.snapsDanger.opacity(0.15))
                                    : theme.surface2
                            )
                    }
                    .buttonStyle(SnapsButtonStyle())
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(theme.border, lineWidth: 1))
        }
    }
}

// MARK: - GIR Direction Picker (5-state: hit / short / long / left / right)
struct GirDirPicker: View {
    @Environment(\.colorScheme) private var colorScheme
    let dir: String?
    let onChange: (String?) -> Void

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }
    private let options: [(label: String, value: String)] = [
        ("Shrt", "short"), ("← L", "left"), ("✓ GIR", "hit"), ("R →", "right"), ("Long", "long")
    ]

    var body: some View {
        HStack(spacing: 0) {
            Text("GIR")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.textMuted)
                .padding(.trailing, 6)
            HStack(spacing: 2) {
                ForEach(options, id: \.value) { opt in
                    let selected = dir == opt.value
                    let isHit = opt.value == "hit"
                    Button {
                        onChange(selected ? nil : opt.value)
                    } label: {
                        Text(opt.label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(selected
                                ? (isHit ? Color.snapsGreen : Color.snapsDanger)
                                : theme.textMuted)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(
                                selected
                                    ? (isHit ? Color.snapsGreen.opacity(0.18) : Color.snapsDanger.opacity(0.15))
                                    : theme.surface2
                            )
                    }
                    .buttonStyle(SnapsButtonStyle())
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(theme.border, lineWidth: 1))
        }
    }
}

// MARK: - Putts Stepper
struct PuttsStepper: View {
    @Environment(\.colorScheme) private var colorScheme
    let count: Int?
    let onChange: (Int?) -> Void

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }
    var is3Putt: Bool { (count ?? 0) >= 3 }

    var body: some View {
        HStack(spacing: 6) {
            Text("PUTTS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.textMuted)

            HStack(spacing: 0) {
                Button {
                    let current = count ?? 2
                    if current > 1 { onChange(current - 1) }
                    else { onChange(nil) }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(theme.surface2)
                }
                .buttonStyle(SnapsButtonStyle())

                Text(count.map { "\($0)" } ?? "—")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(is3Putt ? Color.snapsDanger : theme.textPrimary)
                    .frame(width: 28, height: 28)
                    .background(is3Putt ? Color.snapsDanger.opacity(0.12) : theme.surface1)

                Button {
                    let current = count ?? 1
                    onChange(min(current + 1, 6))
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(theme.surface2)
                }
                .buttonStyle(SnapsButtonStyle())
            }
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(
                is3Putt ? Color.snapsDanger.opacity(0.4) : theme.border, lineWidth: 1))
        }
    }
}

// Legacy stub — replaced by FwyDirPicker / GirDirPicker / PuttsStepper
struct FwyGirToggle: View {
    let label: String
    let state: Bool?
    let onTap: () -> Void
    var body: some View { EmptyView() }
}
