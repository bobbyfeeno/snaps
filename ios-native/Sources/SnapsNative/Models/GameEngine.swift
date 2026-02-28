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
}

struct DotsHoleState {
    let sandyPlayerIds: [String]
    let greeniePlayerId: String?
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
    betAmount: Double
) -> GameResult {
    var payouts: [Payout] = []
    var net = initNet(players)

    let legs: [(name: String, start: Int, end: Int)] = [
        ("Front 9", 0, 9), ("Back 9", 9, 18), ("Full 18", 0, 18)
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
            payouts.append(Payout(from: t.player.name, to: winner.name, amount: betAmount, game: "nassau"))
            net[t.player.name, default: 0] -= betAmount
            net[winner.name, default: 0] += betAmount
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

        for other in players where other.id != banker.id {
            guard let otherScore = scores[other.id]?[hole] else { continue }

            if bankerScore < otherScore {
                payouts.append(Payout(from: other.name, to: banker.name, amount: betAmount, game: "banker"))
                net[other.name, default: 0] -= betAmount
                net[banker.name, default: 0] += betAmount
            } else if otherScore < bankerScore {
                payouts.append(Payout(from: banker.name, to: other.name, amount: betAmount, game: "banker"))
                net[banker.name, default: 0] -= betAmount
                net[other.name, default: 0] += betAmount
            }
        }
    }

    return GameResult(mode: .banker, label: "Banker", payouts: payouts, net: net)
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
            result = calcNassau(players: players, scores: scores, betAmount: cfg.betAmount ?? 5)

        case .vegas:
            result = calcVegas(players: players, scores: scores, pars: extras.pars,
                               betPerPoint: cfg.betAmount ?? 1,
                               teamA: extras.vegasTeamA, teamB: extras.vegasTeamB)

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
        }

        gameResults.append(result)
        for name in players.map(\.name) {
            combinedNet[name, default: 0] += result.net[name] ?? 0
        }
    }

    return MultiGameResults(playerNames: players.map(\.name), games: gameResults, combinedNet: combinedNet)
}
