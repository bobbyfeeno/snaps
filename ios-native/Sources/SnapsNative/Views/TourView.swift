import SwiftUI
import WebKit

// MARK: - Models

struct TourEvent: Identifiable {
    let id: String
    let name: String
    let status: String
    let round: Int?
    let players: [TourPlayer]
}

struct TourPlayer: Identifiable {
    let id: String
    let rank: Int
    let name: String
    let countryFlag: String
    let totalScore: String
    let todayScore: String
    let thru: String
}

// MARK: - TourService

@Observable
class TourService {
    var event: TourEvent? = nil
    var isLoading = false
    var errorMessage: String? = nil
    var lastUpdated: Date? = nil

    private let url = "https://site.api.espn.com/apis/site/v2/sports/golf/pga/scoreboard"

    @MainActor
    func fetchLeaderboard() async {
        isLoading = true
        errorMessage = nil
        do {
            guard let endpoint = URL(string: url) else { throw URLError(.badURL) }
            let (data, _) = try await URLSession.shared.data(from: endpoint)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            guard let events = json?["events"] as? [[String: Any]],
                  let firstEvent = events.first else {
                errorMessage = "No live events right now"
                isLoading = false
                return
            }

            let name = firstEvent["name"] as? String ?? "PGA Tour"
            let statusObj = firstEvent["status"] as? [String: Any]
            let typeObj = statusObj?["type"] as? [String: Any]
            let statusDesc = typeObj?["description"] as? String ?? "—"
            let period = statusObj?["period"] as? Int

            let comps = firstEvent["competitions"] as? [[String: Any]]
            let competitors = comps?.first?["competitors"] as? [[String: Any]] ?? []

            var players: [TourPlayer] = []
            for c in competitors {
                let rank = c["order"] as? Int ?? 999
                let athlete = c["athlete"] as? [String: Any] ?? [:]
                let playerName = athlete["displayName"] as? String ?? "Unknown"
                let flagHref = (athlete["flag"] as? [String: Any])?["href"] as? String ?? ""
                let totalScore = c["score"] as? String ?? "—"
                let linescores = c["linescores"] as? [[String: Any]] ?? []
                let todayScore = linescores.last?["displayValue"] as? String ?? "—"
                let thruRaw = (c["status"] as? [String: Any])?["thru"] as? Int
                let thruStr: String
                if let t = thruRaw { thruStr = t == 18 ? "F" : "\(t)" }
                else if statusDesc.lowercased().contains("final") { thruStr = "F" }
                else { thruStr = "—" }

                players.append(TourPlayer(
                    id: c["id"] as? String ?? UUID().uuidString,
                    rank: rank, name: playerName, countryFlag: flagHref,
                    totalScore: totalScore, todayScore: todayScore, thru: thruStr
                ))
            }
            players.sort { $0.rank < $1.rank }
            event = TourEvent(id: firstEvent["id"] as? String ?? "1", name: name,
                              status: statusDesc, round: period, players: players)
            lastUpdated = Date()
        } catch {
            errorMessage = "Failed to load: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

// MARK: - TourView (main)

struct TourView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab = 0
    @State private var service = TourService()
    @State private var autoRefreshTask: Task<Void, Never>? = nil

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                headerBar

                // Segmented picker
                tabPicker
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                // Content
                if selectedTab == 0 {
                    leaderboardContent
} else {
                    rankingsContent
                }
            }
        }
        .onAppear {
            Task { await service.fetchLeaderboard() }
            startAutoRefresh()
        }
        .onDisappear { autoRefreshTask?.cancel() }
    }

    // MARK: - Header

    var headerBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PRO DATA")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(theme.textPrimary)
                    .tracking(2)
                if selectedTab == 0, let event = service.event {
                    Text(event.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                } else if selectedTab == 1 {
                    Text("Official World Golf Ranking")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if selectedTab == 0, let event = service.event {
                    statusBadge(event.status, round: event.round)
                    if let updated = service.lastUpdated {
                        Text("Updated \(timeAgo(updated))")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textMuted)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Tab Picker

    var tabPicker: some View {
        HStack(spacing: 0) {
            tabSegment(title: "Last Event", index: 0)
            tabSegment(title: "World Rankings", index: 1)
        }
        .background(theme.surface1, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(theme.border, lineWidth: 1))
    }

    func tabSegment(title: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(selectedTab == index ? .black : theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    selectedTab == index
                        ? Color.snapsGreen
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10)
                )
        }
        .buttonStyle(SnapsButtonStyle())
        .padding(3)
    }

    // MARK: - Leaderboard Content

    @ViewBuilder
    var leaderboardContent: some View {
        if service.isLoading && service.event == nil {
            Spacer()
            ProgressView().tint(Color.snapsGreen).scaleEffect(1.3)
            Spacer()
        } else if let msg = service.errorMessage, service.event == nil {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "wifi.slash").font(.system(size: 44)).foregroundStyle(theme.textMuted)
                Text(msg).font(.system(size: 15)).foregroundStyle(theme.textSecondary).multilineTextAlignment(.center)
                Button("Retry") { Task { await service.fetchLeaderboard() } }
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(Color.snapsGreen)
            }
            .padding(40)
            Spacer()
        } else if let event = service.event {
            ScrollView {
                LazyVStack(spacing: 0) {
                    columnHeader
                    ForEach(Array(event.players.prefix(50).enumerated()), id: \.element.id) { idx, player in
                        PlayerLeaderboardRow(player: player, isEven: idx % 2 == 0)
                    }
                    Text("via ESPN · auto-refreshes every 60s")
                        .font(.system(size: 11)).foregroundStyle(theme.textMuted).padding(.vertical, 20)
                }
                .padding(.bottom, 100)
            }
            .refreshable { await service.fetchLeaderboard() }
        }
    }

    var columnHeader: some View {
        HStack(spacing: 0) {
            Text("POS").frame(width: 40, alignment: .leading)
            Text("PLAYER").frame(maxWidth: .infinity, alignment: .leading)
            Text("TOT").frame(width: 52, alignment: .trailing)
            Text("TODAY").frame(width: 60, alignment: .trailing)
            Text("THRU").frame(width: 44, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(theme.textMuted)
        .tracking(1)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.surface1)
    }

    // MARK: - Rankings Content (WebView)

    var rankingsContent: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.snapsGreen.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("World Rankings")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                
                Text("Coming soon")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.textSecondary)
            }
            
            // Link to OWGR website
            Link(destination: URL(string: "https://www.owgr.com")!) {
                HStack(spacing: 8) {
                    Text("View on OWGR.com")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color.snapsGreen)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.snapsGreen.opacity(0.1), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.snapsGreen.opacity(0.3), lineWidth: 1))
            }
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 100)
    }

    // MARK: - Helpers

    func statusBadge(_ status: String, round: Int?) -> some View {
        let isLive = status.lowercased().contains("progress")
        let roundStr = round.map { "R\($0)" } ?? ""
        let label = isLive ? "● LIVE \(roundStr)" : status.uppercased()
        return Text(label)
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(isLive ? .white : theme.textSecondary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(isLive ? Color.snapsDanger : theme.surface2, in: Capsule())
    }

    func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                if Task.isCancelled { break }
                if selectedTab == 0 { await service.fetchLeaderboard() }
            }
        }
    }

    func timeAgo(_ date: Date) -> String {
        let diff = Int(-date.timeIntervalSinceNow)
        if diff < 60 { return "just now" }
        if diff < 3600 { return "\(diff / 60)m ago" }
        return "\(diff / 3600)h ago"
    }
}

// MARK: - OWGR WebView

struct OWGRWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = UIColor(Color.snapsBg)
        webView.isOpaque = false
        webView.scrollView.backgroundColor = UIColor(Color.snapsBg)

        // Inject CSS to remove OWGR header/nav and match our dark theme
        let css = """
            header, nav, .navbar, .cookie-banner, footer, .footer,
            .site-header, .top-bar, .consent, [class*='cookie'], [class*='banner'],
            [class*='header']:not(.ranking-header), [id*='header'] {
                display: none !important;
            }
            body { background: #080808 !important; color: #F5F5F5 !important; font-family: -apple-system, sans-serif !important; }
            table { width: 100% !important; }
        """
        let script = WKUserScript(
            source: """
                var style = document.createElement('style');
                style.textContent = `\(css)`;
                document.head.appendChild(style);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(script)

        if let url = URL(string: "https://www.owgr.com/current-world-ranking?pageNo=1&pageSize=50") {
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            webView.load(request)
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Player Row

struct PlayerLeaderboardRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let player: TourPlayer
    let isEven: Bool

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }

    var scoreColor: Color {
        if player.totalScore == "E" { return theme.textPrimary }
        if player.totalScore.hasPrefix("-") { return Color.snapsGreen }
        return Color.snapsDanger
    }

    var todayColor: Color {
        if player.todayScore == "E" || player.todayScore == "—" { return theme.textSecondary }
        if player.todayScore.hasPrefix("-") { return Color.snapsGreen }
        return Color.snapsDanger
    }

    var body: some View {
        HStack(spacing: 0) {
            Text("\(player.rank)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(player.rank <= 3 ? Color.snapsGold : theme.textSecondary)
                .frame(width: 40, alignment: .leading)

            HStack(spacing: 8) {
                if !player.countryFlag.isEmpty, let url = URL(string: player.countryFlag) {
                    AsyncImage(url: url) { img in img.resizable().scaledToFit() }
                    placeholder: { theme.surface2 }
                        .frame(width: 20, height: 14)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                Text(player.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(player.totalScore)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(scoreColor)
                .frame(width: 52, alignment: .trailing)

            Text(player.todayScore)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(todayColor)
                .frame(width: 60, alignment: .trailing)

            Text(player.thru)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textMuted)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(isEven ? theme.bg : theme.surface1.opacity(0.4))
    }
}
