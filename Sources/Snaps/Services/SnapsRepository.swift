import Foundation

// MARK: - Repository Protocol
// All data operations go through this. Swap MockRepository for SupabaseRepository
// when you're ready to go live.

@MainActor
protocol SnapsRepository {
    // Auth
    func signIn(email: String, password: String) async throws -> UserProfile
    func signUp(email: String, password: String, username: String, displayName: String) async throws -> UserProfile
    func signOut() async throws
    func currentUser() -> UserProfile?

    // Profile
    func getProfile(userId: String) async throws -> UserProfile
    func updateProfile(_ profile: UserProfile) async throws
    func searchUsers(query: String) async throws -> [UserProfile]

    // Game sessions
    func createSession(pars: [Int], gameModes: [SessionGameMode], vegasTeamA: [String], vegasTeamB: [String]) async throws -> GameSession
    func joinSession(joinCode: String) async throws -> GameSession
    func leaveSession(sessionId: String) async throws
    func getSession(id: String) async throws -> GameSession
    func startSession(id: String) async throws
    func completeSession(id: String) async throws

    // Live scores (real-time in Supabase, polling in mock)
    func submitScores(sessionId: String, scores: [Int?]) async throws
    func submitTrackingData(sessionId: String, fairwayDirs: [String?], greenDirs: [String?], putts: [Int?]) async throws
    func submitHoleState(sessionId: String, hole: Int, state: HoleStateData) async throws
    func getLiveScores(sessionId: String) async throws -> LiveScores

    // History & stats
    func getRoundHistory(userId: String) async throws -> [RoundHistory]
    func getStats(userId: String) async throws -> PlayerStats
    func saveRound(sessionId: String, totalScore: Int, netWinnings: Double) async throws
}
