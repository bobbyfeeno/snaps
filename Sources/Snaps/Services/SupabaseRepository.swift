import Foundation
import Supabase

// MARK: - SupabaseRepository
// Drop-in replacement for MockRepository.
// Swap in AppState.swift: repo = SupabaseRepository()

@MainActor
final class SupabaseRepository: SnapsRepository {

    // ── Client ────────────────────────────────────────────────────────
    // Values injected from Info.plist (SUPABASE_URL + SUPABASE_ANON_KEY)
    static let client: SupabaseClient = {
        let url    = Bundle.main.infoDictionary?["SUPABASE_URL"]    as? String ?? ""
        let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
        guard !url.isEmpty, !anonKey.isEmpty else {
            fatalError("⛔ Missing SUPABASE_URL or SUPABASE_ANON_KEY in Info.plist")
        }
        return SupabaseClient(supabaseURL: URL(string: url)!, supabaseKey: anonKey)
    }()

    private var client: SupabaseClient { Self.client }
    private var _currentUser: UserProfile?

    // ── Auth ──────────────────────────────────────────────────────────

    func signIn(email: String, password: String) async throws -> UserProfile {
        let session = try await client.auth.signIn(email: email, password: password)
        let userId = session.user.id.uuidString
        let meta = session.user.userMetadata
        let displayName = meta["display_name"]?.stringValue
            ?? email.components(separatedBy: "@").first
            ?? "Player"
        let username = meta["username"]?.stringValue ?? displayName.lowercased()

        // Fetch profile, or upsert one if missing
        let profile: UserProfile
        if let fetched = try? await getProfile(userId: userId) {
            profile = fetched
        } else {
            let profileInsert: [String: String] = [
                "id": userId, "username": username, "display_name": displayName
            ]
            try? await client.from("profiles").upsert(profileInsert, onConflict: "id").execute()
            profile = UserProfile(id: userId, username: username, displayName: displayName,
                                  avatarUrl: nil, venmoHandle: "", cashappHandle: "",
                                  handicap: 0, createdAt: Date())
        }
        _currentUser = profile
        return profile
    }

    func signUp(email: String, password: String, username: String, displayName: String) async throws -> UserProfile {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["username": .string(username), "display_name": .string(displayName)]
        )
        let userId = response.user.id.uuidString

        // Explicitly create profile — no longer relying on DB trigger
        let profileInsert: [String: String] = [
            "id": userId,
            "username": username.isEmpty ? email.components(separatedBy: "@").first ?? userId : username,
            "display_name": displayName.isEmpty ? username : displayName
        ]
        try? await client.from("profiles").upsert(profileInsert, onConflict: "id").execute()

        let profile = UserProfile(id: userId, username: username, displayName: displayName,
                                  avatarUrl: nil, venmoHandle: "", cashappHandle: "",
                                  handicap: 0, createdAt: Date())
        _currentUser = profile
        return profile
    }

    func signOut() async throws {
        try await client.auth.signOut()
        _currentUser = nil
    }

    func currentUser() -> UserProfile? { _currentUser }

    // Restore session on cold launch
    func restoreSession() async {
        guard let session = try? await client.auth.session else { return }
        _currentUser = try? await getProfile(userId: session.user.id.uuidString)
    }

    // ── Profile ───────────────────────────────────────────────────────

    func getProfile(userId: String) async throws -> UserProfile {
        let row: ProfileRow = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        return row.toProfile()
    }

    func updateProfile(_ profile: UserProfile) async throws {
        let patch = ProfilePatch(
            displayName: profile.displayName,
            avatarUrl: profile.avatarUrl,
            venmoHandle: profile.venmoHandle,
            cashappHandle: profile.cashappHandle,
            handicap: profile.handicap
        )
        try await client
            .from("profiles")
            .update(patch)
            .eq("id", value: profile.id)
            .execute()
        _currentUser = profile
    }

    func searchUsers(query: String) async throws -> [UserProfile] {
        let rows: [ProfileRow] = try await client
            .from("profiles")
            .select()
            .or("username.ilike.%\(query)%,display_name.ilike.%\(query)%")
            .limit(20)
            .execute()
            .value
        return rows.map { $0.toProfile() }
    }

    // ── Game Sessions ─────────────────────────────────────────────────

    func createSession(pars: [Int], gameModes: [SessionGameMode], vegasTeamA: [String], vegasTeamB: [String]) async throws -> GameSession {
        guard let user = _currentUser else { throw SnapsError.notAuthenticated }

        let code = generateJoinCode()
        let modesData = try JSONEncoder().encode(gameModes)
        let modesJSON = String(data: modesData, encoding: .utf8) ?? "[]"

        let row = SessionInsert(
            joinCode: code,
            hostId: user.id,
            pars: pars,
            gameModes: modesJSON,
            vegasTeamA: vegasTeamA,
            vegasTeamB: vegasTeamB
        )

        let created: SessionRow = try await client
            .from("game_sessions")
            .insert(row)
            .select()
            .single()
            .execute()
            .value

        // Add host as first player
        let playerInsert = SessionPlayerInsert(
            sessionId: created.id,
            userId: user.id,
            displayName: user.displayName,
            taxman: user.handicap,
            venmoHandle: user.venmoHandle,
            cashappHandle: user.cashappHandle
        )
        try await client.from("session_players").insert(playerInsert).execute()

        return try created.toSession()
    }

    func joinSession(joinCode: String) async throws -> GameSession {
        guard let user = _currentUser else { throw SnapsError.notAuthenticated }

        let session: SessionRow = try await client
            .from("game_sessions")
            .select()
            .eq("join_code", value: joinCode.uppercased())
            .single()
            .execute()
            .value

        let playerInsert = SessionPlayerInsert(
            sessionId: session.id,
            userId: user.id,
            displayName: user.displayName,
            taxman: user.handicap,
            venmoHandle: user.venmoHandle,
            cashappHandle: user.cashappHandle
        )
        try? await client.from("session_players").insert(playerInsert).execute()

        return try session.toSession()
    }

    func leaveSession(sessionId: String) async throws {
        guard let user = _currentUser else { throw SnapsError.notAuthenticated }
        try await client
            .from("session_players")
            .delete()
            .eq("session_id", value: sessionId)
            .eq("user_id", value: user.id)
            .execute()
    }

    func getSession(id: String) async throws -> GameSession {
        let row: SessionRow = try await client
            .from("game_sessions")
            .select("*, session_players(*)")
            .eq("id", value: id)
            .single()
            .execute()
            .value
        return try row.toSession()
    }

    func startSession(id: String) async throws {
        try await client
            .from("game_sessions")
            .update(["status": "active", "started_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: id)
            .execute()
    }

    func completeSession(id: String) async throws {
        try await client
            .from("game_sessions")
            .update(["status": "complete", "completed_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: id)
            .execute()
    }

    // ── Live Scores ───────────────────────────────────────────────────

    func submitScores(sessionId: String, scores: [Int?]) async throws {
        guard let user = _currentUser else { throw SnapsError.notAuthenticated }
        let upsert = LiveScoreUpsert(
            sessionId: sessionId,
            playerId: user.id,
            scores: scores.map { $0 ?? -1 }  // -1 = not played
        )
        try await client
            .from("live_scores")
            .upsert(upsert, onConflict: "session_id,player_id")
            .execute()
    }

    func submitTrackingData(sessionId: String, fairwayDirs: [String?], greenDirs: [String?], putts: [Int?]) async throws {
        guard let user = _currentUser else { throw SnapsError.notAuthenticated }
        let upsert = TrackingDataUpsert(
            sessionId: sessionId,
            playerId: user.id,
            fairwayDirs: fairwayDirs.map { $0 ?? "" },
            greenDirs: greenDirs.map { $0 ?? "" },
            putts: putts.map { $0 ?? -1 }
        )
        try await client
            .from("live_tracking")
            .upsert(upsert, onConflict: "session_id,player_id")
            .execute()
    }

    func submitHoleState(sessionId: String, hole: Int, state: HoleStateData) async throws {
        let encoded = try JSONEncoder().encode(state)
        let jsonStr = String(data: encoded, encoding: .utf8) ?? "{}"
        try await client
            .from("hole_states")
            .upsert(["session_id": sessionId, "hole": "\(hole)", "state": jsonStr],
                    onConflict: "session_id,hole")
            .execute()
    }

    func getLiveScores(sessionId: String) async throws -> LiveScores {
        let rows: [LiveScoreRow] = try await client
            .from("live_scores")
            .select()
            .eq("session_id", value: sessionId)
            .execute()
            .value

        let holeRows: [HoleStateRow] = try await client
            .from("hole_states")
            .select()
            .eq("session_id", value: sessionId)
            .execute()
            .value

        var scoresByPlayer: [String: [Int?]] = [:]
        for row in rows {
            scoresByPlayer[row.playerId] = row.scores.map { $0 == -1 ? nil : $0 }
        }

        var holeStates: [String: HoleStateData] = [:]
        for row in holeRows {
            if let data = row.state.data(using: .utf8),
               let state = try? JSONDecoder().decode(HoleStateData.self, from: data) {
                holeStates["hole_\(row.hole)"] = state
            }
        }

        let updatedAt = rows.compactMap { ISO8601DateFormatter().date(from: $0.updatedAt) }.max() ?? Date()

        return LiveScores(
            sessionId: sessionId,
            scoresByPlayer: scoresByPlayer,
            holeStates: holeStates,
            updatedAt: updatedAt
        )
    }

    // ── History & Stats ───────────────────────────────────────────────

    func getRoundHistory(userId: String) async throws -> [RoundHistory] {
        let rows: [DBRoundHistoryRow] = try await client
            .from("round_history")
            .select()
            .eq("user_id", value: userId)
            .order("played_at", ascending: false)
            .limit(50)
            .execute()
            .value
        return rows.map { $0.toHistory() }
    }

    func getStats(userId: String) async throws -> PlayerStats {
        let history = try await getRoundHistory(userId: userId)
        guard !history.isEmpty else { return .empty }

        let winnings = history.map { $0.netWinnings }
        let rounds = history.count
        let wins = history.filter { $0.netWinnings > 0 }.count
        let totalWinnings = winnings.reduce(0, +)
        let bestScore = history.compactMap { $0.totalScore > 0 ? $0.totalScore : nil }.min()
        let avgScore = history.filter { $0.totalScore > 0 }.map { Double($0.totalScore) }.reduce(0, +)
            / Double(max(history.filter { $0.totalScore > 0 }.count, 1))

        // Most played game mode
        let allModes = history.flatMap { $0.gameModes }
        let favorite = Dictionary(grouping: allModes, by: { $0 })
            .max(by: { $0.value.count < $1.value.count })?.key

        return PlayerStats(
            roundsPlayed: rounds,
            totalWinnings: totalWinnings,
            bestScore: bestScore,
            averageScore: avgScore,
            winRate: Double(wins) / Double(rounds),
            biggestWin: winnings.max() ?? 0,
            biggestLoss: winnings.min() ?? 0,
            favoriteGame: favorite
        )
    }

    func saveRound(sessionId: String, totalScore: Int, netWinnings: Double) async throws {
        guard let user = _currentUser else { throw SnapsError.notAuthenticated }
        let session = try? await getSession(id: sessionId)
        let insert = RoundHistoryInsert(
            userId: user.id,
            sessionId: sessionId,
            courseName: session?.courseName,
            totalScore: totalScore,
            netWinnings: netWinnings,
            gameModes: session?.gameModes.map { $0.mode } ?? [],
            playerCount: session?.players.count ?? 1,
            opponents: session?.players.compactMap { $0.userId != user.id ? $0.displayName : nil } ?? []
        )
        try await client.from("round_history").insert(insert).execute()
    }

    // ── Realtime ──────────────────────────────────────────────────────

    /// Subscribe to live score updates for a session.
    /// Call from ScoreCardView onAppear, cancel onDisappear.
    func subscribeToScores(sessionId: String, onUpdate: @escaping @Sendable (LiveScores) -> Void) -> RealtimeChannelV2 {
        let channel = client.realtimeV2.channel("scores:\(sessionId)")
        Task {
            await channel.onPostgresChange(
                InsertAction.self,
                table: "live_scores",
                filter: "session_id=eq.\(sessionId)"
            ) { _ in
                Task { @MainActor in
                    if let scores = try? await self.getLiveScores(sessionId: sessionId) {
                        onUpdate(scores)
                    }
                }
            }
            await channel.onPostgresChange(
                UpdateAction.self,
                table: "live_scores",
                filter: "session_id=eq.\(sessionId)"
            ) { _ in
                Task { @MainActor in
                    if let scores = try? await self.getLiveScores(sessionId: sessionId) {
                        onUpdate(scores)
                    }
                }
            }
            await channel.subscribe()
        }
        return channel
    }

    // ── Helpers ───────────────────────────────────────────────────────

    private func generateJoinCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}

// MARK: - Errors

enum SnapsError: LocalizedError {
    case notAuthenticated
    case sessionNotFound
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be signed in."
        case .sessionNotFound:  return "Session not found."
        case .unknown(let m):   return m
        }
    }
}

// MARK: - Database Row Types (Codable ↔ Supabase columns)

private struct ProfileRow: Decodable {
    let id: String
    let username: String
    let displayName: String
    let avatarUrl: String?
    let venmoHandle: String
    let cashappHandle: String
    let handicap: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName  = "display_name"
        case avatarUrl    = "avatar_url"
        case venmoHandle  = "venmo_handle"
        case cashappHandle = "cashapp_handle"
        case handicap
        case createdAt    = "created_at"
    }

    func toProfile() -> UserProfile {
        UserProfile(
            id: id, username: username, displayName: displayName,
            avatarUrl: avatarUrl, venmoHandle: venmoHandle,
            cashappHandle: cashappHandle, handicap: handicap,
            createdAt: ISO8601DateFormatter().date(from: createdAt) ?? Date()
        )
    }
}

private struct ProfilePatch: Encodable {
    let displayName: String
    let avatarUrl: String?
    let venmoHandle: String
    let cashappHandle: String
    let handicap: Int
    enum CodingKeys: String, CodingKey {
        case displayName  = "display_name"
        case avatarUrl    = "avatar_url"
        case venmoHandle  = "venmo_handle"
        case cashappHandle = "cashapp_handle"
        case handicap
    }
}

private struct SessionRow: Decodable {
    let id: String
    let joinCode: String
    let hostId: String
    let courseName: String?
    let pars: [Int]
    let gameModes: String      // JSON string
    let status: String
    let vegasTeamA: [String]
    let vegasTeamB: [String]
    let createdAt: String
    let startedAt: String?
    let completedAt: String?
    let sessionPlayers: [SessionPlayerRow]?

    enum CodingKeys: String, CodingKey {
        case id
        case joinCode      = "join_code"
        case hostId        = "host_id"
        case courseName    = "course_name"
        case pars
        case gameModes     = "game_modes"
        case status
        case vegasTeamA    = "vegas_team_a"
        case vegasTeamB    = "vegas_team_b"
        case createdAt     = "created_at"
        case startedAt     = "started_at"
        case completedAt   = "completed_at"
        case sessionPlayers = "session_players"
    }

    func toSession() throws -> GameSession {
        let fmt = ISO8601DateFormatter()
        let modesData = gameModes.data(using: .utf8) ?? Data()
        let modes = (try? JSONDecoder().decode([SessionGameMode].self, from: modesData)) ?? []

        return GameSession(
            id: id, joinCode: joinCode, hostId: hostId, courseName: courseName,
            pars: pars, gameModes: modes,
            status: GameSession.SessionStatus(rawValue: status) ?? .waiting,
            vegasTeamA: vegasTeamA, vegasTeamB: vegasTeamB,
            players: (sessionPlayers ?? []).map { $0.toPlayer() },
            createdAt: fmt.date(from: createdAt) ?? Date(),
            startedAt: startedAt.flatMap { fmt.date(from: $0) },
            completedAt: completedAt.flatMap { fmt.date(from: $0) }
        )
    }
}

private struct SessionInsert: Encodable {
    let joinCode: String
    let hostId: String
    let pars: [Int]
    let gameModes: String
    let vegasTeamA: [String]
    let vegasTeamB: [String]
    enum CodingKeys: String, CodingKey {
        case joinCode   = "join_code"
        case hostId     = "host_id"
        case pars
        case gameModes  = "game_modes"
        case vegasTeamA = "vegas_team_a"
        case vegasTeamB = "vegas_team_b"
    }
}

private struct SessionPlayerRow: Decodable {
    let id: String
    let sessionId: String
    let userId: String
    let displayName: String
    let taxman: Int
    let venmoHandle: String
    let cashappHandle: String
    enum CodingKeys: String, CodingKey {
        case id
        case sessionId     = "session_id"
        case userId        = "user_id"
        case displayName   = "display_name"
        case taxman
        case venmoHandle   = "venmo_handle"
        case cashappHandle = "cashapp_handle"
    }
    func toPlayer() -> SessionPlayer {
        SessionPlayer(id: id, userId: userId, displayName: displayName,
                      taxman: taxman, venmoHandle: venmoHandle, cashappHandle: cashappHandle)
    }
}

private struct SessionPlayerInsert: Encodable {
    let sessionId: String
    let userId: String
    let displayName: String
    let taxman: Int
    let venmoHandle: String
    let cashappHandle: String
    enum CodingKeys: String, CodingKey {
        case sessionId     = "session_id"
        case userId        = "user_id"
        case displayName   = "display_name"
        case taxman
        case venmoHandle   = "venmo_handle"
        case cashappHandle = "cashapp_handle"
    }
}

private struct TrackingDataUpsert: Encodable {
    let sessionId: String
    let playerId: String
    let fairwayDirs: [String]
    let greenDirs: [String]
    let putts: [Int]
    enum CodingKeys: String, CodingKey {
        case sessionId   = "session_id"
        case playerId    = "player_id"
        case fairwayDirs = "fairway_dirs"
        case greenDirs   = "green_dirs"
        case putts
    }
}

private struct LiveScoreUpsert: Encodable {
    let sessionId: String
    let playerId: String
    let scores: [Int]
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case playerId  = "player_id"
        case scores
    }
}

private struct LiveScoreRow: Decodable {
    let playerId: String
    let scores: [Int]
    let updatedAt: String
    enum CodingKeys: String, CodingKey {
        case playerId  = "player_id"
        case scores
        case updatedAt = "updated_at"
    }
}

private struct HoleStateRow: Decodable {
    let hole: Int
    let state: String
    let updatedAt: String
    enum CodingKeys: String, CodingKey {
        case hole
        case state
        case updatedAt = "updated_at"
    }
}

private struct DBRoundHistoryRow: Decodable {
    let id: String
    let sessionId: String?
    let courseName: String?
    let playedAt: String
    let totalScore: Int
    let netWinnings: Double
    let gameModes: [String]
    let playerCount: Int
    let opponents: [String]
    enum CodingKeys: String, CodingKey {
        case id
        case sessionId   = "session_id"
        case courseName  = "course_name"
        case playedAt    = "played_at"
        case totalScore  = "total_score"
        case netWinnings = "net_winnings"
        case gameModes   = "game_modes"
        case playerCount = "player_count"
        case opponents
    }
    func toHistory() -> RoundHistory {
        RoundHistory(
            id: id, sessionId: sessionId, courseName: courseName,
            playedAt: ISO8601DateFormatter().date(from: playedAt) ?? Date(),
            totalScore: totalScore, netWinnings: netWinnings,
            gameModes: gameModes, playerCount: playerCount, opponents: opponents
        )
    }
}

private struct RoundHistoryInsert: Encodable {
    let userId: String
    let sessionId: String?
    let courseName: String?
    let totalScore: Int
    let netWinnings: Double
    let gameModes: [String]
    let playerCount: Int
    let opponents: [String]
    enum CodingKeys: String, CodingKey {
        case userId      = "user_id"
        case sessionId   = "session_id"
        case courseName  = "course_name"
        case totalScore  = "total_score"
        case netWinnings = "net_winnings"
        case gameModes   = "game_modes"
        case playerCount = "player_count"
        case opponents
    }
}
