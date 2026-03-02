import Foundation

// MARK: - Golf Course Models

struct GolfLocation: Codable {
    let address: String?
    let city: String?
    let state: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
}

struct GolfHole: Codable {
    let par: Int
    let yardage: Int?
    let handicap: Int?
}

struct GolfTeeBox: Codable, Identifiable {
    var id: String { tee_name }
    let tee_name: String
    let course_rating: Double?
    let slope_rating: Int?
    let total_yards: Int?
    let par_total: Int?
    let holes: [GolfHole]?

    var displayName: String { tee_name }
    var totalYards: Int { total_yards ?? 0 }
    var parTotal: Int { par_total ?? 72 }
    var courseRating: Double { course_rating ?? 72.0 }
    var slopeRating: Int { slope_rating ?? 113 }
    var pars: [Int] { holes?.map(\.par) ?? Array(repeating: 4, count: 18) }
    var handicaps: [Int] { holes?.compactMap(\.handicap) ?? [] }
}

struct GolfCourseTees: Codable {
    let male: [GolfTeeBox]?
    let female: [GolfTeeBox]?

    var all: [GolfTeeBox] {
        (male ?? []) + (female ?? [])
    }
}

struct GolfCourse: Codable, Identifiable {
    let id: Int
    let club_name: String?
    let course_name: String?
    let location: GolfLocation?
    let tees: GolfCourseTees?

    var displayName: String { course_name ?? club_name ?? "Unknown Course" }
    var clubDisplayName: String { club_name ?? displayName }
    var city: String { location?.city ?? "" }
    var state: String { location?.state ?? "" }
    var locationString: String {
        [city, state].filter { !$0.isEmpty }.joined(separator: ", ")
    }
    var allTeeBoxes: [GolfTeeBox] { tees?.all ?? [] }
}

// MARK: - API Response Wrappers

private struct CourseSearchResponse: Codable {
    let courses: [GolfCourse]?
}

private struct SingleCourseResponse: Codable {
    let course: GolfCourse?
}

// MARK: - GolfCourseService

actor GolfCourseService {
    static let shared = GolfCourseService()

    private let baseURL = "https://api.golfcourseapi.com/v1"
    private let apiKey = "NSG3JPAYBEAL4UGVKJ6CGPJKCM"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    private func makeRequest(path: String) -> URLRequest? {
        guard let url = URL(string: baseURL + path) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    func searchCourses(query: String) async throws -> [GolfCourse] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let request = makeRequest(path: "/search?search_query=\(encoded)") else {
            throw GolfCourseError.invalidURL
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GolfCourseError.serverError
        }

        let decoded = try JSONDecoder().decode(CourseSearchResponse.self, from: data)
        return decoded.courses ?? []
    }

    func getCourse(id: Int) async throws -> GolfCourse {
        guard let request = makeRequest(path: "/courses/\(id)") else {
            throw GolfCourseError.invalidURL
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GolfCourseError.serverError
        }

        let decoded = try JSONDecoder().decode(SingleCourseResponse.self, from: data)
        guard let course = decoded.course else {
            throw GolfCourseError.notFound
        }
        return course
    }
}

// MARK: - Errors

enum GolfCourseError: LocalizedError {
    case invalidURL
    case serverError
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .serverError: return "Server error — please try again"
        case .notFound: return "Course not found"
        }
    }
}
