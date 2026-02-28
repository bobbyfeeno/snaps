import Foundation
import SwiftData

// MARK: - Player
@Model
class Player {
    var id: String
    var name: String
    var taxMan: Int
    var venmoHandle: String
    var cashappHandle: String
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String, taxMan: Int = 90, venmoHandle: String = "", cashappHandle: String = "") {
        self.id = id
        self.name = name
        self.taxMan = taxMan
        self.venmoHandle = venmoHandle
        self.cashappHandle = cashappHandle
        self.createdAt = Date()
    }
}

// MARK: - Game Mode
enum GameMode: String, Codable, CaseIterable {
    case taxman, wolf, nassau, vegas, snake
    case bingoBangoBongo = "bingo-bango-bongo"
    case ctp, trouble, arnies, banker

    var displayName: String {
        switch self {
        case .taxman: return "Tax Man"
        case .wolf: return "Wolf"
        case .nassau: return "Nassau"
        case .vegas: return "Vegas"
        case .snake: return "Snake"
        case .bingoBangoBongo: return "Bingo Bango Bongo"
        case .ctp: return "Closest to Pin"
        case .trouble: return "Trouble"
        case .arnies: return "Arnies"
        case .banker: return "Banker"
        }
    }

    var emoji: String {
        switch self {
        case .taxman: return "💰"
        case .wolf: return "🐺"
        case .nassau: return "🏅"
        case .vegas: return "🎰"
        case .snake: return "🐍"
        case .bingoBangoBongo: return "🎯"
        case .ctp: return "⛳"
        case .trouble: return "😈"
        case .arnies: return "🦁"
        case .banker: return "🏦"
        }
    }
}

// MARK: - Supporting types
struct GameConfig: Codable {
    var taxAmount: Double?
    var betAmount: Double?
    init(taxAmount: Double? = nil, betAmount: Double? = nil) {
        self.taxAmount = taxAmount
        self.betAmount = betAmount
    }
}

struct GameEntry: Codable {
    var mode: GameMode
    var config: GameConfig
}

struct PlayerResult: Codable, Identifiable {
    var id: String
    var name: String
    var netAmount: Double
    var venmoHandle: String
    var cashappHandle: String
}

struct PlayerSnapshot: Codable, Identifiable {
    var id: String
    var name: String
    var taxMan: Int
    var venmoHandle: String
    var cashappHandle: String

    static func from(_ player: Player) -> PlayerSnapshot {
        PlayerSnapshot(id: player.id, name: player.name, taxMan: player.taxMan,
                       venmoHandle: player.venmoHandle, cashappHandle: player.cashappHandle)
    }
}

struct GameSetup {
    var players: [PlayerSnapshot]
    var games: [GameEntry]
    var vegasTeamA: [String] = []
    var vegasTeamB: [String] = []
}

// MARK: - Round Record
@Model
class RoundRecord {
    var id: String
    var date: Date
    var playerData: Data
    var parsData: Data
    var gamesData: Data
    var resultsData: Data

    init(id: String = UUID().uuidString, date: Date = Date(),
         players: [PlayerSnapshot], pars: [Int],
         games: [GameEntry], results: [PlayerResult]) {
        self.id = id
        self.date = date
        self.playerData = (try? JSONEncoder().encode(players)) ?? Data()
        self.parsData = (try? JSONEncoder().encode(pars)) ?? Data()
        self.gamesData = (try? JSONEncoder().encode(games)) ?? Data()
        self.resultsData = (try? JSONEncoder().encode(results)) ?? Data()
    }

    var players: [PlayerSnapshot] { (try? JSONDecoder().decode([PlayerSnapshot].self, from: playerData)) ?? [] }
    var pars: [Int] { (try? JSONDecoder().decode([Int].self, from: parsData)) ?? Array(repeating: 4, count: 18) }
    var results: [PlayerResult] { (try? JSONDecoder().decode([PlayerResult].self, from: resultsData)) ?? [] }
    var winner: PlayerResult? { results.max(by: { $0.netAmount < $1.netAmount }) }
    var totalPot: Double { results.filter { $0.netAmount > 0 }.reduce(0) { $0 + $1.netAmount } }
}

// MARK: - Active Game State
@Observable
class ActiveGame {
    var setup: GameSetup?
    var scores: [String: [Int?]] = [:]
    var pars: [Int] = Array(repeating: 4, count: 18)
    var currentHole: Int = 0
    var results: [PlayerResult] = []

    func startGame(setup: GameSetup) {
        self.setup = setup
        self.scores = Dictionary(uniqueKeysWithValues: setup.players.map {
            ($0.id, Array(repeating: nil, count: 18))
        })
    }

    func setScore(playerId: String, hole: Int, score: Int?) {
        scores[playerId]?[hole] = score
    }

    func getScore(playerId: String, hole: Int) -> Int? { scores[playerId]?[hole] ?? nil }
    func relToPar(playerId: String, hole: Int) -> Int? {
        guard let s = getScore(playerId: playerId, hole: hole) else { return nil }
        return s - pars[hole]
    }
    func totalScore(playerId: String) -> Int {
        scores[playerId]?.compactMap { $0 }.reduce(0, +) ?? 0
    }

    // Per-hole state for manual-tracked games
    var wolfHoles: [WolfHoleState?] = Array(repeating: nil, count: 18)
    var bbbHoles: [BBBHoleState?] = Array(repeating: nil, count: 18)
    var snakeHoles: [SnakeHoleState?] = Array(repeating: nil, count: 18)
    var ctpHoles: [CtpHoleState?] = Array(repeating: nil, count: 18)
    var troubleHoles: [TroubleHoleState?] = Array(repeating: nil, count: 18)
    var arniesHoles: [ArniesHoleState?] = Array(repeating: nil, count: 18)
    var bankerHoles: [BankerHoleState?] = Array(repeating: nil, count: 18)

    func activeGamModes() -> Set<GameMode> {
        Set(setup?.games.map(\.mode) ?? [])
    }

    func reset() {
        setup = nil; scores = [:]; currentHole = 0; results = []
        wolfHoles = Array(repeating: nil, count: 18)
        bbbHoles = Array(repeating: nil, count: 18)
        snakeHoles = Array(repeating: nil, count: 18)
        ctpHoles = Array(repeating: nil, count: 18)
        troubleHoles = Array(repeating: nil, count: 18)
        arniesHoles = Array(repeating: nil, count: 18)
        bankerHoles = Array(repeating: nil, count: 18)
    }
}
