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
                game.reset()
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
            HStack(spacing: 8) {
                Text("HOLE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.textSecondary)
                    .tracking(2)
                
                Text("\(hole + 1)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
            }

            Spacer()
            
            Text("PAR")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.textSecondary)
                .tracking(1)

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
        if rel == 0  { return theme.scorePar }
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
                // Profile photo
                Image(profileImageName(for: player.name))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.snapsGreen.opacity(0.5), lineWidth: 2))

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

            // Section 1: Tee Shot Tracker (for par 4/5 holes)
            // Section 1: Fairway (par 4/5 only)
            if par >= 4 {
                TeeShotTracker(dir: fwyDir) { newDir in
                    game.fairwayDirs[player.id]?[hole] = newDir
                }
            }
            
            // Section 2: Green (approach shot)
            GreenTracker(dir: girDir) { newDir in
                game.greenDirs[player.id]?[hole] = newDir
            }
            
            // Section 3: Putts
            PuttsTracker(count: puttCount) { newCount in
                game.putts[player.id]?[hole] = newCount
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Premium Tee Shot Tracker
struct TeeShotTracker: View {
    @Environment(\.colorScheme) private var colorScheme
    let dir: String?
    let onChange: (String?) -> Void
    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Deep rough background
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: isDark
                                ? [Color(hex: "#1B2E1B"), Color(hex: "#243524")]
                                : [Color(hex: "#3D6B3D"), Color(hex: "#4A7C4A")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                
                // Tapered fairway
                FairwayShape()
                    .fill(
                        LinearGradient(
                            colors: isDark
                                ? [Color(hex: "#3A6B3A"), Color(hex: "#4A8A4A"), Color(hex: "#5A9D5A"), Color(hex: "#4A8A4A")]
                                : [Color(hex: "#6BAF6B"), Color(hex: "#7EC47E"), Color(hex: "#8FD48F"), Color(hex: "#7EC47E")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .padding(.horizontal, 32)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                
                // Alternating mow lines
                FairwayShape()
                    .fill(
                        LinearGradient(
                            colors: Array(repeating: [Color.white.opacity(0.04), Color.clear], count: 6).flatMap { $0 },
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .padding(.horizontal, 32)
                    .padding(.top, 10)
                    .padding(.bottom, 40)

                // Tap zones
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            fairwayZone("OB\nLeft", value: "ob_left", w: w * 0.17, h: h - 36, danger: true)
                            fairwayZone("Left", value: "left", w: w * 0.17, h: h - 36, danger: false)
                            
                            // Center hit zone
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onChange(dir == "hit" ? nil : "hit")
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 64, height: 64)
                                        .shadow(color: dir == "hit" ? Color(hex: "#4CAF50").opacity(0.6) : .black.opacity(0.1), radius: dir == "hit" ? 16 : 6)
                                    
                                    Circle()
                                        .fill(Color.white.opacity(dir == "hit" ? 1 : 0.92))
                                        .frame(width: 58, height: 58)
                                    
                                    if dir == "hit" {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundStyle(Color(hex: "#2E7D32"))
                                    } else {
                                        Text("Hit")
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color(hex: "#3E7B3E"))
                                    }
                                }
                                .frame(width: w * 0.32, height: h - 36)
                            }
                            .buttonStyle(SnapsButtonStyle())
                            
                            fairwayZone("Right", value: "right", w: w * 0.17, h: h - 36, danger: false)
                            fairwayZone("OB\nRight", value: "ob_right", w: w * 0.17, h: h - 36, danger: true)
                        }
                        
                        // Short zone
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onChange(dir == "short" ? nil : "short")
                        } label: {
                            HStack(spacing: 6) {
                                Text("Short")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                if dir == "short" {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                }
                            }
                            .foregroundStyle(dir == "short" ? .white : .white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(
                                dir == "short"
                                    ? Color(hex: "#8D6E63").opacity(0.9)
                                    : Color(hex: "#2A3F2A").opacity(0.6),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(SnapsButtonStyle())
                    }
                }
                
                // Flag pin
                VStack(spacing: 0) {
                    FlagPin()
                        .frame(width: 16, height: 30)
                    Spacer()
                }
                .padding(.top, 2)
            }
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surface1)
        )
    }
    
    private func fairwayZone(_ label: String, value: String, w: CGFloat, h: CGFloat, danger: Bool) -> some View {
        let selected = dir == value
        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onChange(selected ? nil : value)
        } label: {
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(selected ? .white : .white.opacity(0.65))
                    .lineLimit(2)
                if selected {
                    Circle()
                        .fill(danger ? Color.red : Color.white)
                        .frame(width: 8, height: 8)
                        .shadow(color: (danger ? Color.red : Color.white).opacity(0.6), radius: 6)
                }
            }
            .frame(width: w, height: h)
            .background(
                selected
                    ? AnyShapeStyle(danger ? Color.red.opacity(0.25) : Color.white.opacity(0.12))
                    : AnyShapeStyle(Color.clear),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(SnapsButtonStyle())
    }
}

// MARK: - Flag Pin
struct FlagPin: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Pole
            Rectangle()
                .fill(
                    LinearGradient(colors: [.white.opacity(0.95), .gray.opacity(0.5)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: 1.5)
                .frame(maxHeight: .infinity)
            
            // Flag triangle
            Triangle()
                .fill(Color.red)
                .frame(width: 10, height: 8)
                .offset(x: -1.5, y: 1)
        }
    }
}

// MARK: - Tapered Fairway Shape
struct FairwayShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topInset: CGFloat = rect.width * 0.2
        let bottomInset: CGFloat = rect.width * 0.02
        path.move(to: CGPoint(x: topInset, y: 0))
        path.addLine(to: CGPoint(x: rect.width - topInset, y: 0))
        path.addLine(to: CGPoint(x: rect.width - bottomInset, y: rect.height))
        path.addLine(to: CGPoint(x: bottomInset, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height / 2))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Premium Green Tracker (Approach Shot)
struct GreenTracker: View {
    @Environment(\.colorScheme) private var colorScheme
    let dir: String?
    let onChange: (String?) -> Void
    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Fringe/collar background
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: isDark
                                ? [Color(hex: "#1A2E1A"), Color(hex: "#223522")]
                                : [Color(hex: "#4A7A4A"), Color(hex: "#5A8A5A")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                
                // Green surface (oval)
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: isDark
                                ? [Color(hex: "#2E6B2E"), Color(hex: "#1E5A1E"), Color(hex: "#1A4A1A")]
                                : [Color(hex: "#5CB85C"), Color(hex: "#4A9E4A"), Color(hex: "#3D8A3D")],
                            center: .center, startRadius: 10, endRadius: 100
                        )
                    )
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                
                // Putting surface sheen
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.clear, Color.white.opacity(0.03)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)

                // Tap zones
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    
                    VStack(spacing: 0) {
                        // Long zone
                        greenZone("Long", value: "long", w: w, h: 28)
                        
                        HStack(spacing: 0) {
                            greenZone("Left", value: "left", w: w * 0.22, h: h - 56)
                            
                            // Center — GIR hit
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onChange(dir == "hit" ? nil : "hit")
                            } label: {
                                ZStack {
                                    // Pin hole
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 56, height: 56)
                                        .shadow(color: dir == "hit" ? Color(hex: "#4CAF50").opacity(0.5) : .black.opacity(0.1), radius: dir == "hit" ? 14 : 4)
                                    
                                    Circle()
                                        .fill(Color.white.opacity(dir == "hit" ? 1 : 0.9))
                                        .frame(width: 50, height: 50)
                                    
                                    if dir == "hit" {
                                        VStack(spacing: 1) {
                                            Image(systemName: "flag.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                            Text("GIR")
                                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                        }
                                        .foregroundStyle(Color(hex: "#2E7D32"))
                                    } else {
                                        VStack(spacing: 1) {
                                            Image(systemName: "flag")
                                                .font(.system(size: 16))
                                            Text("GIR")
                                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                        }
                                        .foregroundStyle(Color(hex: "#3E7B3E").opacity(0.8))
                                    }
                                }
                                .frame(width: w * 0.56, height: h - 56)
                            }
                            .buttonStyle(SnapsButtonStyle())
                            
                            greenZone("Right", value: "right", w: w * 0.22, h: h - 56)
                        }
                        
                        // Short zone
                        greenZone("Short", value: "short", w: w, h: 28)
                    }
                }
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surface1)
        )
    }
    
    private func greenZone(_ label: String, value: String, w: CGFloat, h: CGFloat) -> some View {
        let selected = dir == value
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onChange(selected ? nil : value)
        } label: {
            ZStack {
                if selected {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.15))
                }
                VStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(selected ? .white : .white.opacity(0.6))
                    if selected {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                            .shadow(color: .white.opacity(0.5), radius: 4)
                    }
                }
            }
            .frame(width: w, height: h)
        }
        .buttonStyle(SnapsButtonStyle())
    }
}

// MARK: - Premium Putts Tracker
struct PuttsTracker: View {
    @Environment(\.colorScheme) private var colorScheme
    let count: Int?
    let onChange: (Int?) -> Void
    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: 10) {
            // Putt circles
            HStack(spacing: 10) {
                ForEach(1...4, id: \.self) { num in
                    puttCircle(num)
                }
                puttCircle5Plus
            }
            
            // Status label
            Text(puttLabel)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(puttLabelColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surface1)
        )
    }
    
    private func puttCircle(_ num: Int) -> some View {
        let selected = count == num
        let color = puttColor(num)
        
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onChange(selected ? nil : num)
        } label: {
            ZStack {
                Circle()
                    .fill(selected ? color : theme.surface2)
                    .shadow(color: selected ? color.opacity(0.4) : .clear, radius: 8)
                
                if !selected {
                    Circle()
                        .strokeBorder(theme.border.opacity(0.5), lineWidth: 1)
                }
                
                Text("\(num)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? .white : theme.textMuted)
            }
            .frame(width: 48, height: 48)
        }
        .buttonStyle(SnapsButtonStyle())
    }
    
    private var puttCircle5Plus: some View {
        let selected = (count ?? 0) >= 5
        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onChange(selected ? nil : 5)
        } label: {
            ZStack {
                Circle()
                    .fill(selected ? Color.snapsDanger : theme.surface2)
                    .shadow(color: selected ? Color.snapsDanger.opacity(0.4) : .clear, radius: 8)
                
                if !selected {
                    Circle()
                        .strokeBorder(theme.border.opacity(0.5), lineWidth: 1)
                }
                
                Text("5+")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? .white : theme.textMuted)
            }
            .frame(width: 48, height: 48)
        }
        .buttonStyle(SnapsButtonStyle())
    }
    
    private func puttColor(_ num: Int) -> Color {
        switch num {
        case 1: return Color(hex: "#4CAF50")  // green — great
        case 2: return Color(hex: "#66BB6A")  // lighter green — solid
        case 3: return Color.snapsGold         // gold — meh
        default: return Color.snapsDanger      // red — bad
        }
    }
    
    private var puttLabel: String {
        guard let c = count else { return "Tap to set putts" }
        switch c {
        case 1: return "1 putt — birdie look 🎯"
        case 2: return "2 putts — solid"
        case 3: return "3 putts — work to do"
        default: return "\(c) putts"
        }
    }
    
    private var puttLabelColor: Color {
        guard let c = count else { return theme.textMuted }
        switch c {
        case 1: return Color(hex: "#4CAF50")
        case 2: return theme.textSecondary
        case 3: return Color.snapsGold
        default: return Color.snapsDanger
        }
    }
}

// MARK: - Legacy Fairway Direction Picker (keeping for grid view)
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
