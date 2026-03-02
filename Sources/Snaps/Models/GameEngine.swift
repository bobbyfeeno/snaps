import Foundation

// MARK: - Result types

struct Payout: Identifiable {
    let id = UUID()
    let from: String
    let to: String
    let amount: Double
    let game: String
}

struct GameResult {
    let mode: GameMode
    let label: String
    let payouts: [Payout]
    let net: [String: Double]
}

struct MultiGameResults {
    let playerNames: [String]
    let games: [GameResult]
    let combinedNet: [String: Double]
}

// MARK: - Hole state types (for games requiring manual tracking per hole)

struct WolfHoleState {
    let wolfPlayerId: String
    let partnerId: String?  // nil = lone wolf
}

struct BBBHoleState {
    let bingoPlayerId: String?  // first on green (par 3) or first player to reach green
    let bangoPlayerId: String?  // closest to pin once all on green
    let bongoPlayerId: String?  // first to hole out
}

struct SnakeHoleState {
    let threePutters: [String]  // player ids who 3-putted
}

struct CtpHoleState {
    let winnerId: String?
}

struct TroubleHoleState {
    let troubles: [String: [String]]  // playerId -> [troubleType]
}

struct ArniesHoleState {
    let qualifiedPlayerIds: [String]
}

struct BankerHoleState {
    let bankerId: String?
    var betAmount: Double?  // Banker sets per-hole; falls back to config default if nil
}

struct DotsHoleState {
    var sandyPlayerIds: [String]
    var greeniePlayerId: String?
}

struct SixesHoleState {
    // Sixes auto-calculates from scores, no manual state needed
}

struct NinesHoleState {
    // Nines auto-calculates from scores, no manual state needed
}

struct RabbitHoleState {
    // Rabbit auto-calculates from scores, no manual state needed
}

// MARK: - Helpers

private func initNet(_ players: [PlayerSnapshot]) -> [String: Double] {
    Dictionary(uniqueKeysWithValues: players.map { ($0.name, 0.0) })
}

private func sumScores(_ scores: [Int?], from: Int, to: Int) -> Int? {
    var sum = 0
    for i in from..<to {
        guard let s = scores[i] else { return nil }
        sum += s
    }
    return sum
}

// USGA hole difficulty ranks (1=hardest, 18=easiest), 0-indexed holes
private let holeHandicapStrokes = [1,10,2,11,3,12,4,13,5,14,6,15,7,16,8,17,9,18]

private func getHandicapAllowances(_ players: [PlayerSnapshot]) -> [String: Int] {
    let minHcp = players.map { $0.taxMan }.min() ?? 0  // using taxMan as handicap
    return Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0.taxMan - minHcp) })
}

private func getNetScore(gross: Int, allowance: Int, hole: Int) -> Int {
    let difficulty = holeHandicapStrokes[hole]
    let strokes = allowance >= difficulty ? 1 : 0
    return gross - strokes
}

// MARK: - Tax Man

func calcTaxMan(
    players: [PlayerSnapshot],
    scores: [String: [Int?]],
    taxAmount: Double
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)

    var winners: [PlayerSnapshot] = []
    var losers: [PlayerSnapshot] = []

    for player in players {
        guard let playerScores = scores[player.id],
              let total = sumScores(playerScores, from: 0, to: 18) else { continue }
        if total > 0 && total < player.taxMan {
            winners.append(player)
        } else {
            losers.append(player)
        }
    }

    for loser in losers {
        for winner in winners {
            payouts.append(Payout(from: loser.name, to: winner.name, amount: taxAmount, game: "taxman"))
            net[loser.name, default: 0] -= taxAmount
            net[winner.name, default: 0] += taxAmount
        }
    }

    return GameResult(mode: .taxman, label: "Tax Man", payouts: payouts, net: net)
}

// MARK: - Nassau

func calcNassau(
    players: [PlayerSnapshot],
    scores: [String: [Int?]],
    betFront: Double,
    betBack: Double,
    betOverall: Double,
    pressMatches: [PressMatch] = []
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)

    let legs: [(name: String, bet: Double, start: Int, end: Int)] = [
        ("Front 9", betFront, 0, 9),
        ("Back 9", betBack, 9, 18),
        ("Full 18", betOverall, 0, 18)
    ]

    for leg in legs {
        var totals: [(player: PlayerSnapshot, total: Int)] = []
        for player in players {
            guard let playerScores = scores[player.id],
                  let total = sumScores(playerScores, from: leg.start, to: leg.end) else { continue }
            totals.append((player, total))
        }
        guard totals.count >= 2 else { continue }

        let minScore = totals.map { $0.total }.min()!
        let legWinners = totals.filter { $0.total == minScore }
        guard legWinners.count == 1 else { continue }  // tie = push

        let winner = legWinners[0].player
        for t in totals where t.player.id != winner.id {
            payouts.append(Payout(from: t.player.name, to: winner.name, amount: leg.bet, game: "nassau"))
            net[t.player.name, default: 0] -= leg.bet
            net[winner.name, default: 0] += leg.bet
        }
    }

    // Process nassau presses
    let nassauPresses = pressMatches.filter { $0.game == "nassau" }
    for press in nassauPresses {
        var totals: [(player: PlayerSnapshot, total: Int)] = []
        for player in players {
            var sum = 0
            var complete = true
            for h in press.startHole...press.endHole {
                guard let s = scores[player.id]?[h] else { complete = false; break }
                sum += s
            }
            if complete { totals.append((player, sum)) }
        }
        guard totals.count >= 2 else { continue }
        let minScore = totals.map { $0.total }.min()!
        let pressWinners = totals.filter { $0.total == minScore }
        guard pressWinners.count == 1 else { continue }
        let winner = pressWinners[0].player
        for t in totals where t.player.id != winner.id {
            payouts.append(Payout(from: t.player.name, to: winner.name, amount: press.betAmount, game: "nassau-press"))
            net[t.player.name, default: 0] -= press.betAmount
            net[winner.name, default: 0] += press.betAmount
        }
    }

    return GameResult(mode: .nassau, label: "Nassau", payouts: payouts, net: net)
}

// MARK: - Wolf

func calcWolf(
    players: [PlayerSnapshot],
    scores: [String: [Int?]],
    wolfHoles: [WolfHoleState?],
    betPerHole: Double
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)

    for hole in 0..<18 {
        guard let wolfState = wolfHoles[hole],
              let wolf = players.first(where: { $0.id == wolfState.wolfPlayerId }) else { continue }

        let allScored = players.allSatisfy { scores[$0.id]?[hole] != nil }
        guard allScored else { continue }

        let wolfScore = scores[wolf.id]![hole]!

        if wolfState.partnerId == nil {
            // Lone Wolf
            let others = players.filter { $0.id != wolf.id }
            let bestOther = others.compactMap { scores[$0.id]?[hole] }.compactMap { $0 }.min()!

            if wolfScore < bestOther {
                for other in others {
                    payouts.append(Payout(from: other.name, to: wolf.name, amount: betPerHole, game: "wolf"))
                    net[other.name, default: 0] -= betPerHole
                    net[wolf.name, default: 0] += betPerHole
                }
            } else if wolfScore > bestOther {
                for other in others {
                    payouts.append(Payout(from: wolf.name, to: other.name, amount: betPerHole * 2, game: "wolf"))
                    net[wolf.name, default: 0] -= betPerHole * 2
                    net[other.name, default: 0] += betPerHole * 2
                }
            }
        } else {
            // 2v2
            guard let partner = players.first(where: { $0.id == wolfState.partnerId }) else { continue }
            let wolfTeam = [wolf, partner]
            let otherTeam = players.filter { $0.id != wolf.id && $0.id != partner.id }

            let wolfTeamScore = wolfScore + (scores[partner.id]![hole]!)
            let otherTeamScore = otherTeam.reduce(0) { $0 + (scores[$1.id]![hole]!) }

            if wolfTeamScore < otherTeamScore {
                for w in wolfTeam {
                    for o in otherTeam {
                        payouts.append(Payout(from: o.name, to: w.name, amount: betPerHole, game: "wolf"))
                        net[o.name, default: 0] -= betPerHole
                        net[w.name, default: 0] += betPerHole
                    }
                }
            } else if wolfTeamScore > otherTeamScore {
                for o in otherTeam {
                    for w in wolfTeam {
                        payouts.append(Payout(from: w.name, to: o.name, amount: betPerHole, game: "wolf"))
                        net[w.name, default: 0] -= betPerHole
                        net[o.name, default: 0] += betPerHole
                    }
                }
            }
        }
    }

    return GameResult(mode: .wolf, label: "Wolf", payouts: payouts, net: net)
}

// MARK: - Bingo Bango Bongo

func calcBBB(
    players: [PlayerSnapshot],
    bbbHoles: [BBBHoleState?],
    betPerPoint: Double
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)
    var points: [String: Int] = Dictionary(uniqueKeysWithValues: players.map { ($0.id, 0) })

    for hole in 0..<18 {
        guard let state = bbbHoles[hole] else { continue }
        if let id = state.bingoPlayerId { points[id, default: 0] += 1 }
        if let id = state.bangoPlayerId { points[id, default: 0] += 1 }
        if let id = state.bongoPlayerId { points[id, default: 0] += 1 }
    }

    let maxPts = points.values.max() ?? 0
    guard maxPts > 0 else {
        return GameResult(mode: .bingoBangoBongo, label: "Bingo Bango Bongo", payouts: [], net: net)
    }

    let winners = players.filter { (points[$0.id] ?? 0) == maxPts }
    let losers  = players.filter { (points[$0.id] ?? 0) < maxPts }

    for loser in losers {
        for winner in winners {
            let diff = Double((points[winner.id] ?? 0) - (points[loser.id] ?? 0))
            let amount = diff * betPerPoint / Double(winners.count)
            payouts.append(Payout(from: loser.name, to: winner.name, amount: amount, game: "bingo-bango-bongo"))
            net[loser.name, default: 0] -= amount
            net[winner.name, default: 0] += amount
        }
    }

    return GameResult(mode: .bingoBangoBongo, label: "Bingo Bango Bongo", payouts: payouts, net: net)
}

// MARK: - Snake

func calcSnake(
    players: [PlayerSnapshot],
    snakeHoles: [SnakeHoleState?],
    snakeAmount: Double
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)
    var currentHolder: String? = nil

    for hole in 0..<18 {
        guard let state = snakeHoles[hole] else { continue }
        if !state.threePutters.isEmpty {
            currentHolder = state.threePutters.last
        }
    }

    if let holderId = currentHolder, let holder = players.first(where: { $0.id == holderId }) {
        for other in players where other.id != holder.id {
            payouts.append(Payout(from: holder.name, to: other.name, amount: snakeAmount, game: "snake"))
            net[holder.name, default: 0] -= snakeAmount
            net[other.name, default: 0] += snakeAmount
        }
    }

    return GameResult(mode: .snake, label: "Snake", payouts: payouts, net: net)
}

// MARK: - Vegas

private func vegasTeamNumber(_ s1: Int, _ s2: Int, par: Int, forceHigh: Bool = false) -> Int {
    let lo = min(s1, s2), hi = max(s1, s2)
    let hasDouble = s1 >= 10 || s2 >= 10
    if hasDouble { return hi * 10 + lo }  // double-digit always second
    let eitherParOrBetter = !forceHigh && (s1 <= par || s2 <= par)
    return eitherParOrBetter ? lo * 10 + hi : hi * 10 + lo
}

func calcVegas(
    players: [PlayerSnapshot],
    scores: [String: [Int?]],
    pars: [Int],
    betPerPoint: Double,
    teamA: [String],
    teamB: [String],
    flipBird: Bool = false
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)

    let teamAPlayers = players.filter { teamA.contains($0.id) }
    let teamBPlayers = players.filter { teamB.contains($0.id) }
    guard !teamAPlayers.isEmpty && !teamBPlayers.isEmpty else {
        return GameResult(mode: .vegas, label: "Vegas", payouts: [], net: net)
    }

    var teamANetPoints = 0.0
    var teamBNetPoints = 0.0

    for hole in 0..<18 {
        let aScores = teamAPlayers.compactMap { scores[$0.id]?[hole] }.compactMap { $0 }
        let bScores = teamBPlayers.compactMap { scores[$0.id]?[hole] }.compactMap { $0 }
        guard aScores.count == teamAPlayers.count, bScores.count == teamBPlayers.count else { continue }

        let par = pars[hole]
        let aBirdie = aScores.contains { $0 <= par - 1 }
        let bBirdie = bScores.contains { $0 <= par - 1 }

        var numA = vegasTeamNumber(aScores[0], aScores.count > 1 ? aScores[1] : aScores[0], par: par)
        var numB = vegasTeamNumber(bScores[0], bScores.count > 1 ? bScores[1] : bScores[0], par: par)

        if flipBird {
            if aBirdie && !bBirdie {
                numB = vegasTeamNumber(bScores[0], bScores.count > 1 ? bScores[1] : bScores[0], par: par, forceHigh: true)
            } else if bBirdie && !aBirdie {
                numA = vegasTeamNumber(aScores[0], aScores.count > 1 ? aScores[1] : aScores[0], par: par, forceHigh: true)
            }
        }

        let diff = Double(abs(numA - numB))
        if numA < numB { teamANetPoints += diff } else if numB < numA { teamBNetPoints += diff }
    }

    let payout = (abs(teamANetPoints) * betPerPoint * 100).rounded() / 100
    if payout > 0 {
        let winners = teamANetPoints > 0 ? teamAPlayers : teamBPlayers
        let losers  = teamANetPoints > 0 ? teamBPlayers : teamAPlayers
        let share = payout / Double(max(winners.count, 1))

        for w in winners {
            for l in losers {
                payouts.append(Payout(from: l.name, to: w.name, amount: share, game: "vegas"))
            }
            net[w.name, default: 0] += share * Double(losers.count)
        }
        for l in losers {
            net[l.name, default: 0] -= share * Double(winners.count)
        }
    }

    return GameResult(mode: .vegas, label: "Vegas", payouts: payouts, net: net)
}

// MARK: - CTP (Closest to Pin)

func calcCtp(
    players: [PlayerSnapshot],
    pars: [Int],
    ctpHoles: [CtpHoleState?],
    betAmount: Double
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)

    for hole in 0..<18 {
        guard pars[hole] == 3,
              let state = ctpHoles[hole],
              let winnerId = state.winnerId,
              let winner = players.first(where: { $0.id == winnerId }) else { continue }

        for other in players where other.id != winner.id {
            payouts.append(Payout(from: other.name, to: winner.name, amount: betAmount, game: "ctp"))
            net[other.name, default: 0] -= betAmount
            net[winner.name, default: 0] += betAmount
        }
    }

    return GameResult(mode: .ctp, label: "Closest to Pin", payouts: payouts, net: net)
}

// MARK: - Trouble

func calcTrouble(
    players: [PlayerSnapshot],
    troubleHoles: [TroubleHoleState?],
    betAmount: Double
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)

    for hole in 0..<18 {
        guard let state = troubleHoles[hole] else { continue }
        for player in players {
            let count = state.troubles[player.id]?.count ?? 0
            for _ in 0..<count {
                for other in players where other.id != player.id {
                    payouts.append(Payout(from: player.name, to: other.name, amount: betAmount, game: "trouble"))
                    net[player.name, default: 0] -= betAmount
                    net[other.name, default: 0] += betAmount
                }
            }
        }
    }

    return GameResult(mode: .trouble, label: "Trouble", payouts: payouts, net: net)
}

// MARK: - Arnies

func calcArnies(
    players: [PlayerSnapshot],
    arniesHoles: [ArniesHoleState?],
    betAmount: Double
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)

    for hole in 0..<18 {
        guard let state = arniesHoles[hole] else { continue }
        for winnerId in state.qualifiedPlayerIds {
            guard let winner = players.first(where: { $0.id == winnerId }) else { continue }
            for other in players where other.id != winner.id {
                payouts.append(Payout(from: other.name, to: winner.name, amount: betAmount, game: "arnies"))
                net[other.name, default: 0] -= betAmount
                net[winner.name, default: 0] += betAmount
            }
        }
    }

    return GameResult(mode: .arnies, label: "Arnies", payouts: payouts, net: net)
}

// MARK: - Banker

func calcBanker(
    players: [PlayerSnapshot],
    scores: [String: [Int?]],
    bankerHoles: [BankerHoleState?],
    betAmount: Double
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)

    for hole in 0..<18 {
        guard let state = bankerHoles[hole],
              let bankerId = state.bankerId,
              let banker = players.first(where: { $0.id == bankerId }),
              let bankerScore = scores[banker.id]?[hole] else { continue }

        let holeAmount = state.betAmount ?? betAmount  // per-hole overrides config default
        for other in players where other.id != banker.id {
            guard let otherScore = scores[other.id]?[hole] else { continue }

            if bankerScore < otherScore {
                payouts.append(Payout(from: other.name, to: banker.name, amount: holeAmount, game: "banker"))
                net[other.name, default: 0] -= holeAmount
                net[banker.name, default: 0] += holeAmount
            } else if otherScore < bankerScore {
                payouts.append(Payout(from: banker.name, to: other.name, amount: holeAmount, game: "banker"))
                net[banker.name, default: 0] -= holeAmount
                net[other.name, default: 0] += holeAmount
            }
        }
    }

    return GameResult(mode: .banker, label: "Banker", payouts: payouts, net: net)
}

// MARK: - Keep Score

func calcKeepScore(
    players: [PlayerSnapshot],
    scores: [String: [Int?]]
) -> GameResult {
    let net = initNet(players)
    // No payouts — pure scorecard tracking
    return GameResult(mode: .keepScore, label: "Keep Score", payouts: [], net: net)
}

// MARK: - Skins

func calcSkins(
    players: [PlayerSnapshot],
    scores: [String: [Int?]],
    betPerSkin: Double
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)
    var skinsWon: [String: Int] = Dictionary(uniqueKeysWithValues: players.map { ($0.id, 0) })
    var carryover = 0

    for hole in 0..<18 {
        var holeScores: [(player: PlayerSnapshot, score: Int)] = []
        for player in players {
            if let score = scores[player.id]?[hole] { holeScores.append((player, score)) }
        }
        if holeScores.count < 2 { carryover += 1; continue }

        let minScore = holeScores.map { $0.score }.min()!
        let winners = holeScores.filter { $0.score == minScore }
        if winners.count == 1 {
            skinsWon[winners[0].player.id, default: 0] += 1 + carryover
            carryover = 0
        } else {
            carryover += 1
        }
    }

    for winner in players {
        let skins = skinsWon[winner.id] ?? 0
        guard skins > 0 else { continue }
        for other in players where other.id != winner.id {
            let amount = Double(skins) * betPerSkin
            payouts.append(Payout(from: other.name, to: winner.name, amount: amount, game: "skins"))
            net[other.name, default: 0] -= amount
            net[winner.name, default: 0] += amount
        }
    }
    return GameResult(mode: .skins, label: "Skins", payouts: payouts, net: net)
}

// MARK: - Head to Head

func calcHeadToHead(
    players: [PlayerSnapshot],
    scores: [String: [Int?]],
    pars: [Int],
    matchMode: String,
    betAmount: Double,
    useHandicaps: Bool,
    pressMatches: [PressMatch] = []
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)
    let allowances = useHandicaps ? getHandicapAllowances(players) : [:]

    for i in 0..<players.count {
        for j in (i+1)..<players.count {
            let a = players[i]; let b = players[j]

            if matchMode == "match" {
                var aUp = 0
                for h in 0..<18 {
                    let aScore = scores[a.id]?[h]
                    let bScore = scores[b.id]?[h]
                    let aNet = useHandicaps ? getNetScore(gross: aScore ?? 0, allowance: allowances[a.id] ?? 0, hole: h) : (aScore ?? 0)
                    let bNet = useHandicaps ? getNetScore(gross: bScore ?? 0, allowance: allowances[b.id] ?? 0, hole: h) : (bScore ?? 0)
                    guard aScore != nil, bScore != nil else { continue }
                    if aNet < bNet { aUp += 1 } else if bNet < aNet { aUp -= 1 }
                }
                if aUp == 0 { continue }
                let winner = aUp > 0 ? a : b; let loser = aUp > 0 ? b : a
                payouts.append(Payout(from: loser.name, to: winner.name, amount: betAmount, game: "head-to-head"))
                net[loser.name, default: 0] -= betAmount
                net[winner.name, default: 0] += betAmount
            } else {
                // Stroke play
                var aTotal = 0; var bTotal = 0; var complete = true
                for h in 0..<18 {
                    guard let aS = scores[a.id]?[h], let bS = scores[b.id]?[h] else { complete = false; break }
                    aTotal += useHandicaps ? getNetScore(gross: aS, allowance: allowances[a.id] ?? 0, hole: h) : aS
                    bTotal += useHandicaps ? getNetScore(gross: bS, allowance: allowances[b.id] ?? 0, hole: h) : bS
                }
                guard complete, aTotal != bTotal else { continue }
                let diff = abs(aTotal - bTotal)
                let amount = (Double(diff) * betAmount * 100).rounded() / 100
                let winner = aTotal < bTotal ? a : b; let loser = aTotal < bTotal ? b : a
                payouts.append(Payout(from: loser.name, to: winner.name, amount: amount, game: "head-to-head"))
                net[loser.name, default: 0] -= amount
                net[winner.name, default: 0] += amount
            }
        }
    }

    // Process H2H presses
    let h2hPresses = pressMatches.filter { $0.game.hasPrefix("h2h-") }
    for press in h2hPresses {
        // Extract player IDs from tag "h2h-{idA}-{idB}"
        let parts = press.game.split(separator: "-")
        guard parts.count >= 3 else { continue }
        let idA = String(parts[1])
        let idB = String(parts[2...].joined(separator: "-"))
        guard let a = players.first(where: { $0.id == idA }),
              let b = players.first(where: { $0.id == idB }) else { continue }

        var aUp = 0
        for h in press.startHole...press.endHole {
            guard let aS = scores[a.id]?[h], let bS = scores[b.id]?[h] else { continue }
            let aNet = useHandicaps ? getNetScore(gross: aS, allowance: allowances[a.id] ?? 0, hole: h) : aS
            let bNet = useHandicaps ? getNetScore(gross: bS, allowance: allowances[b.id] ?? 0, hole: h) : bS
            if aNet < bNet { aUp += 1 } else if bNet < aNet { aUp -= 1 }
        }
        if aUp == 0 { continue }
        let winner = aUp > 0 ? a : b; let loser = aUp > 0 ? b : a
        payouts.append(Payout(from: loser.name, to: winner.name, amount: press.betAmount, game: "h2h-press"))
        net[loser.name, default: 0] -= press.betAmount
        net[winner.name, default: 0] += press.betAmount
    }

    return GameResult(mode: .headToHead, label: "Head to Head", payouts: payouts, net: net)
}

// MARK: - Best Ball

func calcBestBall(
    players: [PlayerSnapshot],
    scores: [String: [Int?]],
    betAmount: Double,
    matchMode: String,
    teamA: [String],
    teamB: [String]
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)
    let teamAPlayers = players.filter { teamA.contains($0.id) }
    let teamBPlayers = players.filter { teamB.contains($0.id) }
    guard !teamAPlayers.isEmpty, !teamBPlayers.isEmpty else {
        return GameResult(mode: .bestBall, label: "Best Ball", payouts: [], net: net)
    }

    if matchMode == "stroke" {
        var totalA = 0; var totalB = 0
        for hole in 0..<18 {
            let aScores = teamAPlayers.compactMap { scores[$0.id]?[hole] }
            let bScores = teamBPlayers.compactMap { scores[$0.id]?[hole] }
            guard !aScores.isEmpty, !bScores.isEmpty else { continue }
            totalA += aScores.min()!; totalB += bScores.min()!
        }
        if totalA == totalB { return GameResult(mode: .bestBall, label: "Best Ball", payouts: [], net: net) }
        let diff = abs(totalA - totalB)
        let payout = (Double(diff) * betAmount * 100).rounded() / 100
        let winners = totalA < totalB ? teamAPlayers : teamBPlayers
        let losers  = totalA < totalB ? teamBPlayers : teamAPlayers
        let share = (payout / Double(max(winners.count, 1)) * 100).rounded() / 100
        for w in winners { for l in losers {
            payouts.append(Payout(from: l.name, to: w.name, amount: share, game: "best-ball"))
            net[l.name, default: 0] -= share
            net[w.name, default: 0] += share * Double(losers.count)
        }}
        for l in losers { net[l.name, default: 0] -= share * Double(winners.count) }
    } else {
        var holesA = 0; var holesB = 0
        for hole in 0..<18 {
            let aScores = teamAPlayers.compactMap { scores[$0.id]?[hole] }
            let bScores = teamBPlayers.compactMap { scores[$0.id]?[hole] }
            guard !aScores.isEmpty, !bScores.isEmpty else { continue }
            let bestA = aScores.min()!; let bestB = bScores.min()!
            if bestA < bestB { holesA += 1 } else if bestB < bestA { holesB += 1 }
        }
        if holesA == holesB { return GameResult(mode: .bestBall, label: "Best Ball", payouts: [], net: net) }
        let diff = abs(holesA - holesB)
        let payout = (Double(diff) * betAmount * 100).rounded() / 100
        let winners = holesA > holesB ? teamAPlayers : teamBPlayers
        let losers  = holesA > holesB ? teamBPlayers : teamAPlayers
        let share = (payout / Double(max(winners.count, 1)) * 100).rounded() / 100
        for w in winners { for l in losers {
            payouts.append(Payout(from: l.name, to: w.name, amount: share, game: "best-ball"))
        }}
        for w in winners { net[w.name, default: 0] += share * Double(losers.count) }
        for l in losers  { net[l.name, default: 0] -= share * Double(winners.count) }
    }
    return GameResult(mode: .bestBall, label: "Best Ball", payouts: payouts, net: net)
}

// MARK: - Stableford

private func stablefordPts(score: Int, par: Int) -> Int {
    let diff = score - par
    if diff <= -3 { return 5 }
    if diff == -2 { return 4 }
    if diff == -1 { return 3 }
    if diff == 0  { return 2 }
    if diff == 1  { return 1 }
    return 0
}

func calcStableford(
    players: [PlayerSnapshot],
    scores: [String: [Int?]],
    pars: [Int],
    betAmount: Double
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)
    let playerPoints = players.map { player -> (player: PlayerSnapshot, points: Int) in
        var pts = 0
        for h in 0..<18 {
            if let s = scores[player.id]?[h] { pts += stablefordPts(score: s, par: pars[h]) }
        }
        return (player, pts)
    }
    let maxPts = playerPoints.map { $0.points }.max() ?? 0
    guard maxPts > 0 else { return GameResult(mode: .stableford, label: "Stableford", payouts: [], net: net) }
    let winners = playerPoints.filter { $0.points == maxPts }
    let losers  = playerPoints.filter { $0.points < maxPts }
    for loser in losers {
        for winner in winners {
            let diff = winner.points - loser.points
            let amount = (Double(diff) * betAmount * 100).rounded() / 100
            payouts.append(Payout(from: loser.player.name, to: winner.player.name, amount: amount, game: "stableford"))
            net[loser.player.name, default: 0]  -= amount
            net[winner.player.name, default: 0] += amount
        }
    }
    return GameResult(mode: .stableford, label: "Stableford", payouts: payouts, net: net)
}

// MARK: - Rabbit

func calcRabbit(
    players: [PlayerSnapshot],
    scores: [String: [Int?]],
    rabbitAmount: Double
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)
    var rabbitHolder: String? = nil

    for hole in 0..<18 {
        var holeScores: [(player: PlayerSnapshot, score: Int)] = []
        for player in players {
            if let score = scores[player.id]?[hole] { holeScores.append((player, score)) }
        }
        if holeScores.count < 2 { continue }
        let minScore = holeScores.map { $0.score }.min()!
        let holeWinners = holeScores.filter { $0.score == minScore }
        if holeWinners.count == 1 { rabbitHolder = holeWinners[0].player.id }
        // Tie: rabbit stays with current holder
    }

    if let holderId = rabbitHolder, let holder = players.first(where: { $0.id == holderId }) {
        for other in players where other.id != holder.id {
            payouts.append(Payout(from: other.name, to: holder.name, amount: rabbitAmount, game: "rabbit"))
            net[other.name, default: 0]  -= rabbitAmount
            net[holder.name, default: 0] += rabbitAmount
        }
    }
    return GameResult(mode: .rabbit, label: "Rabbit", payouts: payouts, net: net)
}

// MARK: - Dots / Junk

func calcDots(
    players: [PlayerSnapshot],
    scores: [String: [Int?]],
    pars: [Int],
    dotsHoles: [DotsHoleState?],
    betPerDot: Double
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)
    var dotsEarned: [String: Int] = Dictionary(uniqueKeysWithValues: players.map { ($0.id, 0) })

    for hole in 0..<18 {
        let par = pars[hole]
        let state = dotsHoles[hole]
        for player in players {
            guard let s = scores[player.id]?[hole] else { continue }
            let diff = s - par
            if diff <= -2 { dotsEarned[player.id, default: 0] += 2 }       // eagle
            else if diff == -1 { dotsEarned[player.id, default: 0] += 1 }  // birdie
            if let state = state, state.sandyPlayerIds.contains(player.id) {
                dotsEarned[player.id, default: 0] += 1
            }
        }
        // Greenie: par 3 only
        if par == 3, let state = state, let greenieId = state.greeniePlayerId {
            if let s = scores[greenieId]?[hole], s <= par {
                dotsEarned[greenieId, default: 0] += 1
            }
        }
    }

    for winner in players {
        let d = dotsEarned[winner.id] ?? 0
        guard d > 0 else { continue }
        for other in players where other.id != winner.id {
            let amount = (Double(d) * betPerDot * 100).rounded() / 100
            payouts.append(Payout(from: other.name, to: winner.name, amount: amount, game: "dots"))
            net[other.name, default: 0]  -= amount
            net[winner.name, default: 0] += amount
        }
    }
    return GameResult(mode: .dots, label: "Dots/Junk", payouts: payouts, net: net)
}

// MARK: - Sixes

func calcSixes(
    players: [PlayerSnapshot],
    scores: [String: [Int?]],
    betPerSegment: Double
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)
    guard players.count >= 4 else {
        return GameResult(mode: .sixes, label: "Sixes", payouts: [], net: net)
    }
    let p0 = players[0]; let p1 = players[1]; let p2 = players[2]; let p3 = players[3]
    let segments: [(start: Int, end: Int, teamA: [PlayerSnapshot], teamB: [PlayerSnapshot])] = [
        (0,  5,  [p0, p1], [p2, p3]),
        (6,  11, [p0, p2], [p1, p3]),
        (12, 17, [p0, p3], [p1, p2]),
    ]
    for seg in segments {
        var winsA = 0; var winsB = 0
        for hole in seg.start...seg.end {
            let aS = seg.teamA.compactMap { scores[$0.id]?[hole] }
            let bS = seg.teamB.compactMap { scores[$0.id]?[hole] }
            guard !aS.isEmpty, !bS.isEmpty else { continue }
            let bestA = aS.min()!; let bestB = bS.min()!
            if bestA < bestB { winsA += 1 } else if bestB < bestA { winsB += 1 }
        }
        if winsA == winsB { continue }
        let winners = winsA > winsB ? seg.teamA : seg.teamB
        let losers  = winsA > winsB ? seg.teamB : seg.teamA
        for winner in winners { for loser in losers {
            payouts.append(Payout(from: loser.name, to: winner.name, amount: betPerSegment, game: "sixes"))
            net[loser.name, default: 0]  -= betPerSegment
            net[winner.name, default: 0] += betPerSegment
        }}
    }
    return GameResult(mode: .sixes, label: "Sixes", payouts: payouts, net: net)
}

// MARK: - Nines

func calcNines(
    players: [PlayerSnapshot],
    scores: [String: [Int?]],
    betPerPoint: Double
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)
    var totalPoints: [String: Double] = Dictionary(uniqueKeysWithValues: players.map { ($0.id, 0.0) })

    for hole in 0..<18 {
        var holeScores: [(player: PlayerSnapshot, score: Int)] = []
        for player in players {
            if let s = scores[player.id]?[hole] { holeScores.append((player, s)) }
        }
        if holeScores.count < 2 { continue }
        holeScores.sort { $0.score < $1.score }

        // Build groups by score
        var groups: [(score: Int, players: [PlayerSnapshot])] = []
        for h in holeScores {
            if let last = groups.last, last.score == h.score {
                groups[groups.count - 1].players.append(h.player)
            } else {
                groups.append((h.score, [h.player]))
            }
        }

        let buckets = [5, 3, 1]
        var bucketIdx = 0
        for group in groups {
            let consumed = group.players.count
            let pool = buckets[bucketIdx..<min(bucketIdx + consumed, buckets.count)].reduce(0, +)
            let share = Double(pool) / Double(consumed)
            for p in group.players { totalPoints[p.id, default: 0] += share }
            bucketIdx += consumed
        }
    }

    for i in 0..<players.count {
        for j in (i+1)..<players.count {
            let a = players[i]; let b = players[j]
            let diff = abs((totalPoints[a.id] ?? 0) - (totalPoints[b.id] ?? 0))
            if diff == 0 { continue }
            let amount = (diff * betPerPoint * 100).rounded() / 100
            let winner = (totalPoints[a.id] ?? 0) > (totalPoints[b.id] ?? 0) ? a : b
            let loser  = (totalPoints[a.id] ?? 0) > (totalPoints[b.id] ?? 0) ? b : a
            payouts.append(Payout(from: loser.name, to: winner.name, amount: amount, game: "nines"))
            net[loser.name, default: 0]  -= amount
            net[winner.name, default: 0] += amount
        }
    }
    return GameResult(mode: .nines, label: "Nines", payouts: payouts, net: net)
}

// MARK: - Scotch

func calcScotch(
    players: [PlayerSnapshot],
    scores: [String: [Int?]],
    betPerPoint: Double,
    teamA: [String],
    teamB: [String]
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)
    let teamAPlayers = players.filter { teamA.contains($0.id) }
    let teamBPlayers = players.filter { teamB.contains($0.id) }
    guard teamAPlayers.count >= 2, teamBPlayers.count >= 2 else {
        return GameResult(mode: .scotch, label: "Scotch", payouts: [], net: net)
    }

    var pointsA = 0; var pointsB = 0
    for hole in 0..<18 {
        let aS = teamAPlayers.compactMap { scores[$0.id]?[hole] }
        let bS = teamBPlayers.compactMap { scores[$0.id]?[hole] }
        guard aS.count >= 2, bS.count >= 2 else { continue }
        let lowA = aS.min()!; let lowB = bS.min()!
        let totA = aS.reduce(0, +); let totB = bS.reduce(0, +)
        // Low ball: 2pts
        if lowA < lowB { pointsA += 2 } else if lowB < lowA { pointsB += 2 }
        // Low total: 3pts
        if totA < totB { pointsA += 3 } else if totB < totA { pointsB += 3 }
    }

    let diff = abs(pointsA - pointsB)
    let payout = (Double(diff) * betPerPoint * 100).rounded() / 100
    if payout > 0 {
        let winners = pointsA > pointsB ? teamAPlayers : teamBPlayers
        let losers  = pointsA > pointsB ? teamBPlayers : teamAPlayers
        let share = (payout / Double(max(winners.count, 1)) * 100).rounded() / 100
        for w in winners { for l in losers {
            payouts.append(Payout(from: l.name, to: w.name, amount: share, game: "scotch"))
            net[l.name, default: 0] -= share
            net[w.name, default: 0] += share * Double(losers.count)
        }}
        for l in losers { net[l.name, default: 0] -= share * Double(winners.count) }
    }
    return GameResult(mode: .scotch, label: "Scotch", payouts: payouts, net: net)
}

// MARK: - Aces & Deuces

func calcAcesDeuces(
    players: [PlayerSnapshot],
    scores: [String: [Int?]],
    betPerHole: Double
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)

    for hole in 0..<18 {
        var holeScores: [(player: PlayerSnapshot, score: Int)] = []
        for player in players {
            if let s = scores[player.id]?[hole] { holeScores.append((player, s)) }
        }
        if holeScores.count < 2 { continue }
        let allScores = holeScores.map { $0.score }
        let minScore = allScores.min()!; let maxScore = allScores.max()!
        if minScore == maxScore { continue } // everyone tied: push

        let aces    = holeScores.filter { $0.score == minScore }.map { $0.player }
        let deuces  = holeScores.filter { $0.score == maxScore }.map { $0.player }
        let middles = holeScores.filter { $0.score != minScore && $0.score != maxScore }.map { $0.player }

        // Ace collects betPerHole from every other player
        let othersForAce = deuces + middles
        for ace in aces {
            for other in othersForAce {
                payouts.append(Payout(from: other.name, to: ace.name, amount: betPerHole, game: "aces-deuces"))
                net[other.name, default: 0] -= betPerHole
                net[ace.name, default: 0]   += betPerHole
            }
        }
        // Deuce pays betPerHole to every other player
        let othersForDeuce = aces + middles
        for deuce in deuces {
            for other in othersForDeuce {
                payouts.append(Payout(from: deuce.name, to: other.name, amount: betPerHole, game: "aces-deuces"))
                net[deuce.name, default: 0] -= betPerHole
                net[other.name, default: 0] += betPerHole
            }
        }
    }
    return GameResult(mode: .acesDeuces, label: "Aces & Deuces", payouts: payouts, net: net)
}

// MARK: - Quota

func calcQuota(
    players: [PlayerSnapshot],
    scores: [String: [Int?]],
    pars: [Int],
    quotas: [String: Int],
    betPerPoint: Double
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)
    var deviations: [String: Int] = [:]

    for player in players {
        var pts = 0
        for h in 0..<18 {
            if let s = scores[player.id]?[h] { pts += stablefordPts(score: s, par: pars[h]) }
        }
        let quota = quotas[player.id] ?? 18
        deviations[player.id] = pts - quota
    }

    for i in 0..<players.count {
        for j in (i+1)..<players.count {
            let a = players[i]; let b = players[j]
            let diff = (deviations[a.id] ?? 0) - (deviations[b.id] ?? 0)
            if diff == 0 { continue }
            let amount = (Double(abs(diff)) * betPerPoint * 100).rounded() / 100
            let winner = diff > 0 ? a : b; let loser = diff > 0 ? b : a
            payouts.append(Payout(from: loser.name, to: winner.name, amount: amount, game: "quota"))
            net[loser.name, default: 0]  -= amount
            net[winner.name, default: 0] += amount
        }
    }
    return GameResult(mode: .quota, label: "Quota", payouts: payouts, net: net)
}

// MARK: - Master: Calculate all games

struct GameExtras {
    var pars: [Int] = Array(repeating: 4, count: 18)
    var wolf: [WolfHoleState?] = Array(repeating: nil, count: 18)
    var bbb: [BBBHoleState?] = Array(repeating: nil, count: 18)
    var snake: [SnakeHoleState?] = Array(repeating: nil, count: 18)
    var ctp: [CtpHoleState?] = Array(repeating: nil, count: 18)
    var trouble: [TroubleHoleState?] = Array(repeating: nil, count: 18)
    var arnies: [ArniesHoleState?] = Array(repeating: nil, count: 18)
    var banker: [BankerHoleState?] = Array(repeating: nil, count: 18)
    var vegasTeamA: [String] = []
    var vegasTeamB: [String] = []
    var dots: [DotsHoleState?] = Array(repeating: nil, count: 18)
    var pressMatches: [PressMatch] = []
    var hammerMultipliers: [Int] = Array(repeating: 1, count: 18)
}

func calcAllGames(
    players: [PlayerSnapshot],
    games: [GameEntry],
    scores: [String: [Int?]],
    extras: GameExtras
) -> MultiGameResults {
    var gameResults: [GameResult] = []
    var combinedNet: [String: Double] = Dictionary(uniqueKeysWithValues: players.map { ($0.name, 0.0) })

    for game in games {
        let result: GameResult
        let cfg = game.config

        switch game.mode {
        case .taxman:
            result = calcTaxMan(players: players, scores: scores, taxAmount: cfg.taxAmount ?? 10)

        case .wolf:
            result = calcWolf(players: players, scores: scores, wolfHoles: extras.wolf, betPerHole: cfg.betAmount ?? 1)

        case .nassau:
            result = calcNassau(players: players, scores: scores,
                                betFront: cfg.betFront ?? cfg.betAmount ?? 5,
                                betBack: cfg.betBack ?? cfg.betAmount ?? 5,
                                betOverall: cfg.betOverall ?? cfg.betAmount ?? 5,
                                pressMatches: extras.pressMatches)

        case .vegas:
            result = calcVegas(players: players, scores: scores, pars: extras.pars,
                               betPerPoint: cfg.betPerPoint ?? cfg.betAmount ?? 1,
                               teamA: extras.vegasTeamA, teamB: extras.vegasTeamB,
                               flipBird: cfg.flipBird ?? false)

        case .snake:
            result = calcSnake(players: players, snakeHoles: extras.snake, snakeAmount: cfg.betAmount ?? 5)

        case .bingoBangoBongo:
            result = calcBBB(players: players, bbbHoles: extras.bbb, betPerPoint: cfg.betAmount ?? 1)

        case .ctp:
            result = calcCtp(players: players, pars: extras.pars, ctpHoles: extras.ctp, betAmount: cfg.betAmount ?? 5)

        case .trouble:
            result = calcTrouble(players: players, troubleHoles: extras.trouble, betAmount: cfg.betAmount ?? 1)

        case .arnies:
            result = calcArnies(players: players, arniesHoles: extras.arnies, betAmount: cfg.betAmount ?? 5)

        case .banker:
            result = calcBanker(players: players, scores: scores, bankerHoles: extras.banker, betAmount: cfg.betAmount ?? 5)

        case .keepScore:
            result = calcKeepScore(players: players, scores: scores)

        case .skins:
            result = calcSkins(players: players, scores: scores, betPerSkin: cfg.betPerSkin ?? 5)

        case .headToHead:
            result = calcHeadToHead(
                players: players, scores: scores, pars: extras.pars,
                matchMode: cfg.matchMode ?? "match",
                betAmount: cfg.betAmount ?? 5,
                useHandicaps: cfg.useHandicaps ?? false,
                pressMatches: extras.pressMatches
            )

        case .bestBall:
            result = calcBestBall(
                players: players, scores: scores,
                betAmount: cfg.betAmount ?? 5,
                matchMode: cfg.matchMode ?? "stroke",
                teamA: cfg.teamA ?? [],
                teamB: cfg.teamB ?? []
            )

        case .stableford:
            result = calcStableford(players: players, scores: scores, pars: extras.pars, betAmount: cfg.betAmount ?? 1)

        case .rabbit:
            result = calcRabbit(players: players, scores: scores, rabbitAmount: cfg.rabbitAmount ?? 5)

        case .dots:
            result = calcDots(players: players, scores: scores, pars: extras.pars, dotsHoles: extras.dots, betPerDot: cfg.betPerDot ?? 1)

        case .sixes:
            result = calcSixes(players: players, scores: scores, betPerSegment: cfg.betPerSegment ?? 5)

        case .nines:
            result = calcNines(players: players, scores: scores, betPerPoint: cfg.betPerPoint ?? 1)

        case .scotch:
            result = calcScotch(
                players: players, scores: scores,
                betPerPoint: cfg.betPerPoint ?? 1,
                teamA: cfg.teamA ?? [],
                teamB: cfg.teamB ?? []
            )

        case .acesDeuces:
            result = calcAcesDeuces(players: players, scores: scores, betPerHole: cfg.betPerHole ?? 2)

        case .quota:
            // Default quota = 36 - handicap (stored in taxMan field as handicap proxy)
            let quotas = Dictionary(uniqueKeysWithValues: players.map { ($0.id, 36 - $0.taxMan) })
            result = calcQuota(players: players, scores: scores, pars: extras.pars, quotas: quotas, betPerPoint: cfg.betPerPoint ?? 1)
        }

        gameResults.append(result)
        for name in players.map(\.name) {
            combinedNet[name, default: 0] += result.net[name] ?? 0
        }
    }

    return MultiGameResults(playerNames: players.map(\.name), games: gameResults, combinedNet: combinedNet)
}
