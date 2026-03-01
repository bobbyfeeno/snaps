import Foundation

// MARK: - User Profile
struct UserProfile: Identifiable, Codable, Equatable {
    var id: String
    var username: String
    var displayName: String
    var avatarUrl: String?
    var venmoHandle: String
    var cashappHandle: String
    var handicap: Int
    var createdAt: Date

    static let empty = UserProfile(id: "", username: "", displayName: "",
                                   venmoHandle: "", cashappHandle: "", handicap: 0, createdAt: Date())
}

// MARK: - Game Session
struct GameSession: Identifiable, Codable {
    var id: String
    var joinCode: String
    var hostId: String
    var courseName: String?
    var pars: [Int]
    var gameModes: [SessionGameMode]
    var status: SessionStatus
    var vegasTeamA: [String]
    var vegasTeamB: [String]
    var players: [SessionPlayer]
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?

    enum SessionStatus: String, Codable {
        case waiting, active, complete
    }
}

struct SessionGameMode: Codable {
    var mode: String
    var taxAmount: Double?
    var betAmount: Double?
}

struct SessionPlayer: Identifiable, Codable, Equatable {
    var id: String       // user profile id
    var userId: String
    var displayName: String
    var taxman: Int
    var venmoHandle: String
    var cashappHandle: String
}

// MARK: - Live Scores (per session)
struct LiveScores: Codable {
    var sessionId: String
    var scoresByPlayer: [String: [Int?]]  // userId -> 18 hole scores
    var holeStates: [String: HoleStateData]  // "hole_0" -> state data
    var updatedAt: Date
}

struct HoleStateData: Codable {
    var wolfPlayerId: String?
    var wolfPartnerId: String?
    var bbbBingo: String?
    var bbbBango: String?
    var bbbBongo: String?
    var threePutters: [String]
    var ctpWinnerId: String?
    var troubles: [String: [String]]
    var arnies: [String]
    var bankerId: String?

    init() {
        threePutters = []; troubles = [:]; arnies = []
    }
}

// MARK: - Round History
struct RoundHistory: Identifiable, Codable {
    var id: String
    var sessionId: String?
    var courseName: String?
    var playedAt: Date
    var totalScore: Int
    var netWinnings: Double
    var gameModes: [String]
    var playerCount: Int
    var opponents: [String]  // display names
}

// MARK: - Player Stats
struct PlayerStats {
    var roundsPlayed: Int
    var totalWinnings: Double
    var bestScore: Int?
    var averageScore: Double
    var winRate: Double  // 0-1
    var biggestWin: Double
    var biggestLoss: Double
    var favoriteGame: String?

    static let empty = PlayerStats(roundsPlayed: 0, totalWinnings: 0, bestScore: nil,
                                   averageScore: 0, winRate: 0, biggestWin: 0, biggestLoss: 0, favoriteGame: nil)
}
