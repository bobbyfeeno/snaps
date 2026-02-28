import SwiftUI

/// Bottom sheet shown on scorecard for manual per-hole game tracking.
struct HoleTrackerView: View {
    @Bindable var game: ActiveGame
    let hole: Int
    let setup: GameSetup
    @State private var expandedGame: GameMode? = nil

    var activeModes: [GameMode] {
        setup.games.map { $0.mode }.filter { manualModes.contains($0) }
    }

    let manualModes: Set<GameMode> = [.wolf, .bingoBangoBongo, .snake, .ctp, .trouble, .arnies, .banker]

    var body: some View {
        if activeModes.isEmpty { EmptyView() }
        else {
            VStack(alignment: .leading, spacing: 10) {
                Text("GAME TRACKING")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.gray)
                    .tracking(2)
                    .padding(.horizontal, 4)

                ForEach(activeModes, id: \.self) { mode in
                    GameTrackerRow(game: game, mode: mode, hole: hole, setup: setup,
                                  isExpanded: expandedGame == mode) {
                        withAnimation(.spring(duration: 0.3)) {
                            expandedGame = expandedGame == mode ? nil : mode
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(hex: "#0e0e0e"), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

// MARK: - Single game tracker row

struct GameTrackerRow: View {
    @Bindable var game: ActiveGame
    let mode: GameMode
    let hole: Int
    let setup: GameSetup
    let isExpanded: Bool
    let onTap: () -> Void

    var statusLabel: String {
        switch mode {
        case .wolf:
            if let s = game.wolfHoles[hole] {
                let wolfName = setup.players.first(where: { $0.id == s.wolfPlayerId })?.name ?? "?"
                let partner = s.partnerId != nil ? (setup.players.first(where: { $0.id == s.partnerId })?.name ?? "?") : "Lone"
                return "\(wolfName) | \(partner)"
            }
            return "Set Wolf"
        case .bingoBangoBongo:
            if let s = game.bbbHoles[hole] {
                let b = setup.players.first(where: { $0.id == s.bingoPlayerId })?.name.split(separator: " ").first.map(String.init) ?? "—"
                let ba = setup.players.first(where: { $0.id == s.bangoPlayerId })?.name.split(separator: " ").first.map(String.init) ?? "—"
                let bo = setup.players.first(where: { $0.id == s.bongoPlayerId })?.name.split(separator: " ").first.map(String.init) ?? "—"
                return "\(b) · \(ba) · \(bo)"
            }
            return "Set Bingo/Bango/Bongo"
        case .snake:
            if let s = game.snakeHoles[hole], !s.threePutters.isEmpty {
                let names = s.threePutters.compactMap { id in setup.players.first(where: { $0.id == id })?.name.split(separator: " ").first.map(String.init) }
                return "🐍 " + names.joined(separator: ", ")
            }
            return "No 3-Putts"
        case .ctp:
            if let s = game.ctpHoles[hole], let id = s.winnerId {
                return "🎯 " + (setup.players.first(where: { $0.id == id })?.name ?? "?")
            }
            return game.pars[hole] == 3 ? "Set CTP Winner" : "Par \(game.pars[hole]) (skip)"
        case .trouble:
            if let s = game.troubleHoles[hole] {
                let count = s.troubles.values.flatMap { $0 }.count
                return count > 0 ? "\(count) trouble(s)" : "No Trouble"
            }
            return "No Trouble"
        case .arnies:
            if let s = game.arniesHoles[hole], !s.qualifiedPlayerIds.isEmpty {
                let names = s.qualifiedPlayerIds.compactMap { id in setup.players.first(where: { $0.id == id })?.name.split(separator: " ").first.map(String.init) }
                return "🦁 " + names.joined(separator: ", ")
            }
            return "No Arnies"
        case .banker:
            if let s = game.bankerHoles[hole], let id = s.bankerId {
                return "🏦 " + (setup.players.first(where: { $0.id == id })?.name ?? "?")
            }
            return "Set Banker"
        default:
            return ""
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack {
                    Text(mode.emoji + " " + mode.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(statusLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                        .padding(.leading, 4)
                }
                .padding(12)
            }

            if isExpanded {
                Divider().background(Color.white.opacity(0.06))
                trackerBody
                    .padding(12)
            }
        }
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    var trackerBody: some View {
        switch mode {
        case .wolf:  WolfTracker(game: game, hole: hole, setup: setup)
        case .bingoBangoBongo: BBBTracker(game: game, hole: hole, setup: setup)
        case .snake: SnakeTracker(game: game, hole: hole, setup: setup)
        case .ctp:   CtpTracker(game: game, hole: hole, setup: setup)
        case .trouble: TroubleTracker(game: game, hole: hole, setup: setup)
        case .arnies:  ArniesTracker(game: game, hole: hole, setup: setup)
        case .banker:  BankerTracker(game: game, hole: hole, setup: setup)
        default: EmptyView()
        }
    }
}

// MARK: - Wolf Tracker

struct WolfTracker: View {
    @Bindable var game: ActiveGame
    let hole: Int
    let setup: GameSetup

    var wolfId: String? { game.wolfHoles[hole]?.wolfPlayerId }
    var partnerId: String? { game.wolfHoles[hole]?.partnerId }
    var isLoneWolf: Bool { game.wolfHoles[hole] != nil && game.wolfHoles[hole]?.partnerId == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Wolf selector
            VStack(alignment: .leading, spacing: 6) {
                Text("🐺 Wolf").font(.system(size: 12, weight: .bold)).foregroundStyle(.gray)
                PlayerButtonGrid(players: setup.players, selectedId: wolfId) { id in
                    let current = game.wolfHoles[hole]
                    game.wolfHoles[hole] = WolfHoleState(wolfPlayerId: id, partnerId: current?.partnerId)
                }
            }

            if wolfId != nil {
                Divider().background(Color.white.opacity(0.06))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Partner (or Lone Wolf)").font(.system(size: 12, weight: .bold)).foregroundStyle(.gray)
                    // Lone wolf button
                    Button {
                        if let wId = wolfId {
                            game.wolfHoles[hole] = WolfHoleState(wolfPlayerId: wId, partnerId: nil)
                        }
                    } label: {
                        Text("Lone Wolf 🐺")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isLoneWolf ? Color(hex: "#39FF14") : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isLoneWolf ? Color(hex: "#39FF14").opacity(0.15) : Color.white.opacity(0.06),
                                        in: RoundedRectangle(cornerRadius: 8))
                    }
                    // Partner from other players
                    PlayerButtonGrid(players: setup.players.filter { $0.id != wolfId }, selectedId: partnerId) { id in
                        if let wId = wolfId {
                            game.wolfHoles[hole] = WolfHoleState(wolfPlayerId: wId, partnerId: id)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - BBB Tracker

struct BBBTracker: View {
    @Bindable var game: ActiveGame
    let hole: Int
    let setup: GameSetup

    var state: BBBHoleState? { game.bbbHoles[hole] }

    func setField(_ field: String, id: String?) {
        let s = state
        switch field {
        case "bingo": game.bbbHoles[hole] = BBBHoleState(bingoPlayerId: id, bangoPlayerId: s?.bangoPlayerId, bongoPlayerId: s?.bongoPlayerId)
        case "bango": game.bbbHoles[hole] = BBBHoleState(bingoPlayerId: s?.bingoPlayerId, bangoPlayerId: id, bongoPlayerId: s?.bongoPlayerId)
        case "bongo": game.bbbHoles[hole] = BBBHoleState(bingoPlayerId: s?.bingoPlayerId, bangoPlayerId: s?.bangoPlayerId, bongoPlayerId: id)
        default: break
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach([("Bingo 🟢", "bingo", state?.bingoPlayerId),
                     ("Bango 🎯", "bango", state?.bangoPlayerId),
                     ("Bongo ⛳", "bongo", state?.bongoPlayerId)], id: \.0) { label, field, selectedId in
                VStack(alignment: .leading, spacing: 6) {
                    Text(label).font(.system(size: 12, weight: .bold)).foregroundStyle(.gray)
                    PlayerButtonGrid(players: setup.players, selectedId: selectedId) { id in
                        setField(field, id: id == selectedId ? nil : id)
                    }
                }
            }
        }
    }
}

// MARK: - Snake Tracker

struct SnakeTracker: View {
    @Bindable var game: ActiveGame
    let hole: Int
    let setup: GameSetup

    var threePutters: [String] { game.snakeHoles[hole]?.threePutters ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("3-Putters (tap to toggle)").font(.system(size: 12, weight: .bold)).foregroundStyle(.gray)
            PlayerButtonGrid(players: setup.players, selectedIds: Set(threePutters)) { id in
                var current = threePutters
                if current.contains(id) { current.removeAll { $0 == id } }
                else { current.append(id) }
                game.snakeHoles[hole] = SnakeHoleState(threePutters: current)
            }
        }
    }
}

// MARK: - CTP Tracker

struct CtpTracker: View {
    @Bindable var game: ActiveGame
    let hole: Int
    let setup: GameSetup

    var body: some View {
        if game.pars[hole] != 3 {
            Text("CTP only applies on par 3s")
                .font(.system(size: 12)).foregroundStyle(.gray)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Closest to Pin").font(.system(size: 12, weight: .bold)).foregroundStyle(.gray)
                PlayerButtonGrid(players: setup.players, selectedId: game.ctpHoles[hole]?.winnerId) { id in
                    let current = game.ctpHoles[hole]?.winnerId
                    game.ctpHoles[hole] = CtpHoleState(winnerId: id == current ? nil : id)
                }
            }
        }
    }
}

// MARK: - Trouble Tracker

let troubleTypes = ["OB", "Water", "3-Putt", "Bunker", "Lost Ball"]

struct TroubleTracker: View {
    @Bindable var game: ActiveGame
    let hole: Int
    let setup: GameSetup

    var troubles: [String: [String]] { game.troubleHoles[hole]?.troubles ?? [:] }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(setup.players) { player in
                VStack(alignment: .leading, spacing: 6) {
                    Text(player.name).font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    HStack(spacing: 6) {
                        ForEach(troubleTypes, id: \.self) { type in
                            let active = troubles[player.id]?.contains(type) ?? false
                            Button {
                                var t = troubles
                                var playerTroubles = t[player.id] ?? []
                                if active { playerTroubles.removeAll { $0 == type } }
                                else { playerTroubles.append(type) }
                                t[player.id] = playerTroubles
                                game.troubleHoles[hole] = TroubleHoleState(troubles: t)
                            } label: {
                                Text(type)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(active ? .black : .white)
                                    .padding(.horizontal, 8).padding(.vertical, 5)
                                    .background(active ? Color(hex: "#ff4444") : Color.white.opacity(0.08),
                                                in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Arnies Tracker

struct ArniesTracker: View {
    @Bindable var game: ActiveGame
    let hole: Int
    let setup: GameSetup

    var qualified: [String] { game.arniesHoles[hole]?.qualifiedPlayerIds ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Qualified (made par from off-fairway)").font(.system(size: 12, weight: .bold)).foregroundStyle(.gray)
            PlayerButtonGrid(players: setup.players, selectedIds: Set(qualified)) { id in
                var current = qualified
                if current.contains(id) { current.removeAll { $0 == id } }
                else { current.append(id) }
                game.arniesHoles[hole] = ArniesHoleState(qualifiedPlayerIds: current)
            }
        }
    }
}

// MARK: - Banker Tracker

struct BankerTracker: View {
    @Bindable var game: ActiveGame
    let hole: Int
    let setup: GameSetup

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Banker this hole").font(.system(size: 12, weight: .bold)).foregroundStyle(.gray)
            PlayerButtonGrid(players: setup.players, selectedId: game.bankerHoles[hole]?.bankerId) { id in
                let current = game.bankerHoles[hole]?.bankerId
                game.bankerHoles[hole] = BankerHoleState(bankerId: id == current ? nil : id)
            }
        }
    }
}

// MARK: - Reusable player button grid (single select)

struct PlayerButtonGrid: View {
    let players: [PlayerSnapshot]
    var selectedId: String?
    var selectedIds: Set<String>?
    let onSelect: (String) -> Void

    init(players: [PlayerSnapshot], selectedId: String?, onSelect: @escaping (String) -> Void) {
        self.players = players; self.selectedId = selectedId; self.onSelect = onSelect
    }

    init(players: [PlayerSnapshot], selectedIds: Set<String>, onSelect: @escaping (String) -> Void) {
        self.players = players; self.selectedIds = selectedIds; self.onSelect = onSelect
    }

    func isSelected(_ id: String) -> Bool {
        if let ids = selectedIds { return ids.contains(id) }
        return selectedId == id
    }

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(players) { player in
                Button {
                    onSelect(player.id)
                } label: {
                    Text(player.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected(player.id) ? .black : .white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(isSelected(player.id) ? Color(hex: "#39FF14") : Color.white.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0, x: CGFloat = 0, rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                height += rowHeight + spacing; x = 0; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing; x = bounds.minX; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
