import SwiftUI

@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    var repo: any SnapsRepository = MockRepository()
    var currentUser: UserProfile? = MockData.profiles[0]
    var isAuthenticated: Bool = true
    var activeSession: GameSession?
    var errorMessage: String?

    private init() {}

    func setError(_ msg: String) {
        errorMessage = msg
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if errorMessage == msg { errorMessage = nil }
        }
    }
}
