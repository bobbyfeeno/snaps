import Foundation

// MARK: - Mock Repository
// Full dummy data implementation. Swap for SupabaseRepository later.

@MainActor
class MockRepository: SnapsRepository, ObservableObject {

    // Simulated current user
    private var _currentUser: UserProfile? = MockData.profiles[0]

    // In-memory stores
    private var sessions: [String: GameSession] = [:]
    private var liveScores: [String: LiveScores] = [:]
    private var history: [String: [RoundHistory]] = [:]

    init() {
        // Seed a sample active session
        let sample = MockData.sampleSession
        sessions[sample.id] = sample
        liveScores[sample.id] = MockData.sampleLiveScores(sessionId: sample.id)
        history[MockData.profiles[0].id] = MockData.roundHistory
    }

    // MARK: - Auth

    func signIn(email: String, password: String) async throws -> UserProfile {
        try await Task.sleep(nanoseconds: 600_000_000)
        _currentUser = MockData.profiles[0]
        return _currentUser!
    }

    func signUp(email: String, password: String, username: String, displayName: String) async throws -> UserProfile {
        try await Task.sleep(nanoseconds: 800_000_000)
        let profile = UserProfile(id: UUID().uuidString, username: username, displayName: displayName,
                                  venmoHandle: "", cashappHandle: "", handicap: 0, createdAt: Date())
        _currentUser = profile
        return profile
    }

    func signOut() async throws {
        _currentUser = nil
    }

    func currentUser() -> UserProfile? { _currentUser }

    // MARK: - Profile

    func getProfile(userId: String) async throws -> UserProfile {
        try await Task.sleep(nanoseconds: 200_000_000)
        return MockData.profiles.first(where: { $0.id == userId }) ?? MockData.profiles[0]
    }

    func updateProfile(_ profile: UserProfile) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        if var idx = MockData.profiles.firstIndex(where: { $0.id == profile.id }) {
            // In mock we can't mutate static data, just succeed
        }
        _currentUser = profile
    }

    func searchUsers(query: String) async throws -> [UserProfile] {
        try await Task.sleep(nanoseconds: 300_000_000)
        return MockData.profiles.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) ||
            $0.username.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Game Sessions

    func createSession(pars: [Int], gameModes: [SessionGameMode], vegasTeamA: [String], vegasTeamB: [String]) async throws -> GameSession {
        try await Task.sleep(nanoseconds: 500_000_000)
        guard let user = _currentUser else { throw MockError.notAuthenticated }
        let code = String(UUID().uuidString.prefix(6)).uppercased()
        var session = GameSession(
            id: UUID().uuidString, joinCode: code, hostId: user.id,
            courseName: nil, pars: pars, gameModes: gameModes, status: .waiting,
            vegasTeamA: vegasTeamA, vegasTeamB: vegasTeamB,
            players: [SessionPlayer(id: UUID().uuidString, userId: user.id,
                                    displayName: user.displayName, taxman: 90,
                                    venmoHandle: user.venmoHandle, cashappHandle: user.cashappHandle)],
            createdAt: Date()
        )
        sessions[session.id] = session
        liveScores[session.id] = LiveScores(sessionId: session.id, scoresByPlayer: [user.id: Array(repeating: nil, count: 18)], holeStates: [:], updatedAt: Date())
        return session
    }

    func joinSession(joinCode: String) async throws -> GameSession {
        try await Task.sleep(nanoseconds: 600_000_000)
        guard let user = _currentUser else { throw MockError.notAuthenticated }
        guard var session = sessions.values.first(where: { $0.joinCode == joinCode.uppercased() })
              ?? sessions.values.first  // fallback to sample for demo
        else { throw MockError.sessionNotFound }

        if !session.players.contains(where: { $0.userId == user.id }) {
            let sp = SessionPlayer(id: UUID().uuidString, userId: user.id,
                                   displayName: user.displayName, taxman: 90,
                                   venmoHandle: user.venmoHandle, cashappHandle: user.cashappHandle)
            session.players.append(sp)
            sessions[session.id] = session
            liveScores[session.id]?.scoresByPlayer[user.id] = Array(repeating: nil, count: 18)
        }
        return session
    }

    func leaveSession(sessionId: String) async throws {
        guard let user = _currentUser else { return }
        sessions[sessionId]?.players.removeAll { $0.userId == user.id }
    }

    func getSession(id: String) async throws -> GameSession {
        try await Task.sleep(nanoseconds: 100_000_000)
        guard let s = sessions[id] else { throw MockError.sessionNotFound }
        return s
    }

    func startSession(id: String) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        sessions[id]?.status = .active
        sessions[id]?.startedAt = Date()
    }

    func completeSession(id: String) async throws {
        sessions[id]?.status = .complete
        sessions[id]?.completedAt = Date()
    }

    // MARK: - Live Scores

    func submitScores(sessionId: String, scores: [Int?]) async throws {
        guard let user = _currentUser else { return }
        liveScores[sessionId]?.scoresByPlayer[user.id] = scores
        liveScores[sessionId]?.updatedAt = Date()
    }

    func submitTrackingData(sessionId: String, fairwayDirs: [String?], greenDirs: [String?], putts: [Int?]) async throws {
        // Mock: no-op, data stays local
    }

    func submitHoleState(sessionId: String, hole: Int, state: HoleStateData) async throws {
        liveScores[sessionId]?.holeStates["hole_\(hole)"] = state
    }

    func getLiveScores(sessionId: String) async throws -> LiveScores {
        try await Task.sleep(nanoseconds: 100_000_000)
        return liveScores[sessionId] ?? LiveScores(sessionId: sessionId, scoresByPlayer: [:], holeStates: [:], updatedAt: Date())
    }

    // MARK: - History & Stats

    func getRoundHistory(userId: String) async throws -> [RoundHistory] {
        try await Task.sleep(nanoseconds: 300_000_000)
        return history[userId] ?? MockData.roundHistory
    }

    func getStats(userId: String) async throws -> PlayerStats {
        try await Task.sleep(nanoseconds: 200_000_000)
        let rounds = history[userId] ?? MockData.roundHistory
        let winnings = rounds.map { $0.netWinnings }
        let totalWinnings = winnings.reduce(0, +)
        let wins = winnings.filter { $0 > 0 }.count
        return PlayerStats(
            roundsPlayed: rounds.count,
            totalWinnings: totalWinnings,
            bestScore: rounds.map { $0.totalScore }.min(),
            averageScore: rounds.isEmpty ? 0 : Double(rounds.map { $0.totalScore }.reduce(0, +)) / Double(rounds.count),
            winRate: rounds.isEmpty ? 0 : Double(wins) / Double(rounds.count),
            biggestWin: winnings.max() ?? 0,
            biggestLoss: winnings.min() ?? 0,
            favoriteGame: "Tax Man"
        )
    }

    func saveRound(sessionId: String, totalScore: Int, netWinnings: Double) async throws {
        guard let user = _currentUser else { return }
        let round = RoundHistory(id: UUID().uuidString, sessionId: sessionId,
                                 courseName: sessions[sessionId]?.courseName,
                                 playedAt: Date(), totalScore: totalScore,
                                 netWinnings: netWinnings, gameModes: ["taxman"],
                                 playerCount: sessions[sessionId]?.players.count ?? 2,
                                 opponents: [])
        history[user.id, default: []].insert(round, at: 0)
    }
}

enum MockError: Error, LocalizedError {
    case notAuthenticated, sessionNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not signed in"
        case .sessionNotFound: return "Game not found — check your join code"
        }
    }
}

// MARK: - Mock Data

struct MockData {
    static let profiles: [UserProfile] = [
        UserProfile(id: "user-bobby", username: "bobbyfeeno", displayName: "Bobby",
                    venmoHandle: "bobbyfeeno", cashappHandle: "$bobbyfeeno", handicap: 12, createdAt: .distantPast),
        UserProfile(id: "user-bobby", username: "bobby", displayName: "Bobby",
                    venmoHandle: "bobbygolf", cashappHandle: "$bobbygolf", handicap: 8, createdAt: .distantPast),
        UserProfile(id: "user-tyler", username: "tyler", displayName: "Tyler",
                    venmoHandle: "tyler99", cashappHandle: "$tyler99", handicap: 15, createdAt: .distantPast),
        UserProfile(id: "user-mike", username: "mike", displayName: "Mike",
                    venmoHandle: "mikegolf", cashappHandle: "$mikegolf", handicap: 20, createdAt: .distantPast),
    ]

    static var sampleSession: GameSession {
        GameSession(
            id: "session-demo",
            joinCode: "SNAPS1",
            hostId: "user-bobby",
            courseName: "Shadow Hawk Golf Club",
            pars: [4,4,3,5,4,4,3,5,4, 4,3,5,4,4,3,5,4,4],
            gameModes: [
                SessionGameMode(mode: "taxman", taxAmount: 10, betAmount: nil),
                SessionGameMode(mode: "nassau", taxAmount: nil, betAmount: 5),
            ],
            status: .active,
            vegasTeamA: [], vegasTeamB: [],
            players: [
                SessionPlayer(id: "sp1", userId: "user-bobby", displayName: "Bobby", taxman: 90, venmoHandle: "bobbyfeeno", cashappHandle: "$bobbyfeeno"),
                SessionPlayer(id: "sp2", userId: "user-bobby", displayName: "Bobby", taxman: 88, venmoHandle: "bobbygolf", cashappHandle: "$bobbygolf"),
                SessionPlayer(id: "sp3", userId: "user-tyler", displayName: "Tyler", taxman: 92, venmoHandle: "tyler99", cashappHandle: "$tyler99"),
            ],
            createdAt: Date().addingTimeInterval(-3600),
            startedAt: Date().addingTimeInterval(-3000)
        )
    }

    static func sampleLiveScores(sessionId: String) -> LiveScores {
        LiveScores(
            sessionId: sessionId,
            scoresByPlayer: [
                "user-bobby": [4,5,3,5,4,nil,nil,nil,nil, nil,nil,nil,nil,nil,nil,nil,nil,nil],
                "user-bobby": [4,4,4,5,3,nil,nil,nil,nil, nil,nil,nil,nil,nil,nil,nil,nil,nil],
                "user-tyler": [5,4,3,6,4,nil,nil,nil,nil, nil,nil,nil,nil,nil,nil,nil,nil,nil],
            ],
            holeStates: [:],
            updatedAt: Date()
        )
    }

    static let roundHistory: [RoundHistory] = [
        RoundHistory(id: "r1", sessionId: "s1", courseName: "Shadow Hawk GC", playedAt: Date().addingTimeInterval(-86400),
                     totalScore: 87, netWinnings: 45, gameModes: ["taxman","nassau"], playerCount: 4,
                     opponents: ["Bobby","Tyler","Mike"]),
        RoundHistory(id: "r2", sessionId: "s2", courseName: "Augusta Pines", playedAt: Date().addingTimeInterval(-86400*5),
                     totalScore: 91, netWinnings: -20, gameModes: ["wolf","taxman"], playerCount: 4,
                     opponents: ["Bobby","Tyler","Mike"]),
        RoundHistory(id: "r3", sessionId: "s3", courseName: "Sweetwater CC", playedAt: Date().addingTimeInterval(-86400*12),
                     totalScore: 84, netWinnings: 80, gameModes: ["vegas","nassau"], playerCount: 4,
                     opponents: ["Bobby","Tyler","Mike"]),
        RoundHistory(id: "r4", sessionId: "s4", courseName: "Tour 18", playedAt: Date().addingTimeInterval(-86400*20),
                     totalScore: 89, netWinnings: -15, gameModes: ["taxman"], playerCount: 3,
                     opponents: ["Bobby","Tyler"]),
        RoundHistory(id: "r5", sessionId: "s5", courseName: "Shadow Hawk GC", playedAt: Date().addingTimeInterval(-86400*30),
                     totalScore: 85, netWinnings: 60, gameModes: ["taxman","snake"], playerCount: 4,
                     opponents: ["Bobby","Tyler","Mike"]),
    ]
}
