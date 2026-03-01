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
    case keepScore = "keep-score"
    case headToHead = "head-to-head"
    case taxman
    case nassau
    case skins
    case wolf
    case bingoBangoBongo = "bingo-bango-bongo"
    case snake
    case vegas
    case bestBall = "best-ball"
    case stableford
    case rabbit
    case dots
    case sixes
    case nines
    case scotch
    case ctp
    case acesDeuces = "aces-deuces"
    case quota
    case trouble
    case arnies
    case banker

    var displayName: String {
        switch self {
        case .keepScore: return "Keep Score"
        case .headToHead: return "Head to Head"
        case .taxman: return "Tax Man"
        case .nassau: return "Nassau"
        case .skins: return "Skins"
        case .wolf: return "Wolf"
        case .bingoBangoBongo: return "Bingo Bango Bongo"
        case .snake: return "Snake"
        case .vegas: return "Vegas"
        case .bestBall: return "Best Ball"
        case .stableford: return "Stableford"
        case .rabbit: return "Rabbit"
        case .dots: return "Dots/Junk"
        case .sixes: return "Sixes"
        case .nines: return "Nines"
        case .scotch: return "Scotch"
        case .ctp: return "Closest to Pin"
        case .acesDeuces: return "Aces & Deuces"
        case .quota: return "Quota"
        case .trouble: return "Trouble"
        case .arnies: return "Arnies"
        case .banker: return "Banker"
        }
    }

    var emoji: String {
        switch self {
        case .keepScore: return "📋"
        case .headToHead: return "🏆"
        case .taxman: return "💰"
        case .nassau: return "🏅"
        case .skins: return "🎯"
        case .wolf: return "🐺"
        case .bingoBangoBongo: return "🎯"
        case .snake: return "🐍"
        case .vegas: return "🎰"
        case .bestBall: return "⚔️"
        case .stableford: return "📊"
        case .rabbit: return "🐰"
        case .dots: return "⭐"
        case .sixes: return "6️⃣"
        case .nines: return "9️⃣"
        case .scotch: return "🥃"
        case .ctp: return "⛳"
        case .acesDeuces: return "🎲"
        case .quota: return "📈"
        case .trouble: return "😈"
        case .arnies: return "🦁"
        case .banker: return "🏦"
        }
    }
}

// MARK: - Supporting types
struct GameConfig: Codable {
    // existing
    var taxAmount: Double?
    var betAmount: Double?
    // new fields
    var betPerSkin: Double?        // skins
    var betPerPoint: Double?       // stableford, nines, scotch, quota
    var betPerHole: Double?        // aces-deuces, wolf
    var rabbitAmount: Double?      // rabbit
    var betPerDot: Double?         // dots
    var betPerSegment: Double?     // sixes
    var teamA: [String]?           // best-ball, scotch (player ids)
    var teamB: [String]?           // best-ball, scotch
    var matchMode: String?         // head-to-head: "match" or "stroke"
    var useHandicaps: Bool?        // head-to-head, nassau
    var quotas: [String: Int]?     // quota: playerId -> quota value
    // nassau separate bets
    var betFront: Double?          // nassau front 9
    var betBack: Double?           // nassau back 9
    var betOverall: Double?        // nassau full 18
    // vegas options
    var flipBird: Bool?            // vegas flip the bird
    // press options
    var autoPress: Bool?           // auto-press at 2-down (nassau, h2h)
    // hammer modifier
    var hammerEnabled: Bool?       // shared hammer toggle

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

// MARK: - Press Match (for auto-press)
struct PressMatch: Codable {
    var startHole: Int
    var endHole: Int = 17
    var game: String  // "nassau" or "h2h-{idA}-{idB}"
    var betAmount: Double
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
    var scoresData: Data = Data()
    var fairwayDirsData: Data = Data()   // [String: [String?]] — "hit"/"left"/"right"/nil
    var greenDirsData: Data = Data()     // [String: [String?]] — "hit"/"short"/"long"/"left"/"right"/nil
    var puttsData: Data = Data()         // [String: [Int?]]

    init(id: String = UUID().uuidString, date: Date = Date(),
         players: [PlayerSnapshot], pars: [Int],
         games: [GameEntry], results: [PlayerResult],
         scores: [String: [Int?]] = [:],
         fairwayDirs: [String: [String?]] = [:],
         greenDirs: [String: [String?]] = [:],
         putts: [String: [Int?]] = [:]) {
        self.id = id
        self.date = date
        self.playerData = (try? JSONEncoder().encode(players)) ?? Data()
        self.parsData = (try? JSONEncoder().encode(pars)) ?? Data()
        self.gamesData = (try? JSONEncoder().encode(games)) ?? Data()
        self.resultsData = (try? JSONEncoder().encode(results)) ?? Data()
        self.scoresData = (try? JSONEncoder().encode(scores)) ?? Data()
        self.fairwayDirsData = (try? JSONEncoder().encode(fairwayDirs)) ?? Data()
        self.greenDirsData = (try? JSONEncoder().encode(greenDirs)) ?? Data()
        self.puttsData = (try? JSONEncoder().encode(putts)) ?? Data()
    }

    var players: [PlayerSnapshot] { (try? JSONDecoder().decode([PlayerSnapshot].self, from: playerData)) ?? [] }
    var pars: [Int] { (try? JSONDecoder().decode([Int].self, from: parsData)) ?? Array(repeating: 4, count: 18) }
    var results: [PlayerResult] { (try? JSONDecoder().decode([PlayerResult].self, from: resultsData)) ?? [] }
    var winner: PlayerResult? { results.max(by: { $0.netAmount < $1.netAmount }) }
    var totalPot: Double { results.filter { $0.netAmount > 0 }.reduce(0) { $0 + $1.netAmount } }
    var scores: [String: [Int?]] { (try? JSONDecoder().decode([String: [Int?]].self, from: scoresData)) ?? [:] }
    var fairwayDirs: [String: [String?]] { (try? JSONDecoder().decode([String: [String?]].self, from: fairwayDirsData)) ?? [:] }
    var greenDirs: [String: [String?]] { (try? JSONDecoder().decode([String: [String?]].self, from: greenDirsData)) ?? [:] }
    var putts: [String: [Int?]] { (try? JSONDecoder().decode([String: [Int?]].self, from: puttsData)) ?? [:] }
    var games: [GameEntry] { (try? JSONDecoder().decode([GameEntry].self, from: gamesData)) ?? [] }
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
        self.fairwayDirs = Dictionary(uniqueKeysWithValues: setup.players.map {
            ($0.id, Array(repeating: nil, count: 18))
        })
        self.greenDirs = Dictionary(uniqueKeysWithValues: setup.players.map {
            ($0.id, Array(repeating: nil, count: 18))
        })
        self.putts = Dictionary(uniqueKeysWithValues: setup.players.map {
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
    var dotsHoles: [DotsHoleState?] = Array(repeating: nil, count: 18)

    // Auto-press matches
    var pressMatches: [PressMatch] = []

    // Fairway, GIR, and Putts tracking (keyed by player ID, 18-hole arrays)
    var fairwayDirs: [String: [String?]] = [:]  // nil=par3/unset | "hit" | "left" | "right"
    var greenDirs: [String: [String?]] = [:]    // nil=unset | "hit" | "short" | "long" | "left" | "right"
    var putts: [String: [Int?]] = [:]           // putts per hole (1-6)

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
        dotsHoles = Array(repeating: nil, count: 18)
        pressMatches = []
        fairwayDirs = [:]
        greenDirs = [:]
        putts = [:]
    }
}
