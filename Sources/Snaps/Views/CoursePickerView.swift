import SwiftUI
import Combine
import CoreLocation

// MARK: - CoursePickerView

struct CoursePickerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }

    var onSelect: (GolfCourse, GolfTeeBox) -> Void

    @StateObject private var locationManager = LocationManager()

    @State private var searchText = ""
    @State private var results: [GolfCourse] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedCourse: GolfCourse?
    @State private var selectedTeeBox: GolfTeeBox?
    @State private var phase: Phase = .search

    // Nearby courses state
    @State private var nearbyCourses: [GolfCourse] = []
    @State private var isLoadingNearby = false
    @State private var nearbySearchDone = false
    @State private var nearbyCityName: String?

    private let debounceSubject = PassthroughSubject<String, Never>()
    @State private var cancellables = Set<AnyCancellable>()

    enum Phase {
        case search, teePicker
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    if phase == .teePicker {
                        Button {
                            withAnimation(.spring()) { phase = .search }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(theme.textPrimary)
                                .frame(width: 36, height: 36)
                        }
                    } else {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }

                    Spacer()

                    Text(phase == .search ? "SELECT COURSE" : "CHOOSE TEES")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(theme.textPrimary)
                        .tracking(2)

                    Spacer()

                    // Skip button
                    Button {
                        dismiss()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                if phase == .search {
                    searchPhase
                } else if let course = selectedCourse {
                    teePickerPhase(course: course)
                }
            }
        }
        .onAppear {
            setupDebounce()
            locationManager.requestLocation()
        }
        .onChange(of: locationManager.cityName) { _, cityName in
            guard let city = cityName, !nearbySearchDone else { return }
            nearbyCityName = city
            Task { await loadNearbyCourses(city: city) }
        }
        .onChange(of: locationManager.locationError) { _, isError in
            if isError && !nearbySearchDone {
                nearbySearchDone = true // mark done so we show fallback
            }
        }
    }

    // MARK: - Search Phase

    var searchPhase: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(searchText.isEmpty ? theme.textMuted : theme.green)

                TextField("Search courses...", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.textPrimary)
                    .autocorrectionDisabled()
                    .onChange(of: searchText) { _, newVal in
                        debounceSubject.send(newVal)
                    }

                if isLoading || isLoadingNearby {
                    ProgressView()
                        .tint(theme.green)
                        .scaleEffect(0.85)
                } else if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        results = []
                        errorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.surface1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                searchText.isEmpty ? theme.border : theme.green.opacity(0.5),
                                lineWidth: 1
                            )
                    )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // Results
            ScrollView {
                LazyVStack(spacing: 8) {
                    if searchText.isEmpty {
                        nearbySection
                    } else {
                        searchResultsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Nearby Section (shown when search bar is empty)

    @ViewBuilder
    var nearbySection: some View {
        if isLoadingNearby {
            VStack(spacing: 16) {
                ProgressView()
                    .tint(theme.green)
                    .scaleEffect(1.2)
                Text("Finding nearby courses…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.top, 60)
            .frame(maxWidth: .infinity)
        } else if !nearbyCourses.isEmpty {
            // Nearby courses available
            if let city = nearbyCityName {
                sectionLabel("NEARBY COURSES — \(city.uppercased())")
            } else {
                sectionLabel("NEARBY COURSES")
            }
            ForEach(nearbyCourses) { course in
                courseRow(course, distanceText: distanceText(for: course))
            }
        } else if nearbySearchDone || locationManager.locationError {
            // Location denied or search yielded nothing — show prompt
            promptCard
        } else {
            // Still waiting for location permission / first fix
            VStack(spacing: 16) {
                ProgressView()
                    .tint(theme.green)
                    .scaleEffect(1.2)
                Text("Locating you…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.top, 60)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Search Results Section (shown while user is typing)

    @ViewBuilder
    var searchResultsSection: some View {
        if let error = errorMessage {
            errorCard(error)
        } else if results.isEmpty && !isLoading {
            emptyState
        } else if !results.isEmpty {
            sectionLabel("\(results.count) COURSE\(results.count == 1 ? "" : "S") FOUND")
            ForEach(results) { course in
                courseRow(course, distanceText: distanceText(for: course))
            }
        }
    }

    // MARK: - Tee Picker Phase

    func teePickerPhase(course: GolfCourse) -> some View {
        VStack(spacing: 0) {
            // Course header card
            VStack(alignment: .leading, spacing: 6) {
                Text(course.displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                if !course.locationString.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.green)
                        Text(course.locationString)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(theme.surface1, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.border, lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            if course.allTeeBoxes.isEmpty {
                noTeesState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        sectionLabel("SELECT YOUR TEES")

                        ForEach(course.allTeeBoxes) { tee in
                            teeBoxRow(tee, course: course)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 100)
                }
            }

            // Confirm button
            if let tee = selectedTeeBox {
                VStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onSelect(selectedCourse!, tee)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Confirm — \(tee.displayName) Tees")
                                    .font(.system(size: 16, weight: .black))
                                Text("\(tee.totalYards) yards · \(String(format: "%.1f", tee.courseRating))/\(tee.slopeRating) · Par \(tee.parTotal)")
                                    .font(.system(size: 12, weight: .medium))
                                    .opacity(0.75)
                            }
                            Spacer()
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .frame(height: 60)
                        .frame(maxWidth: .infinity)
                        .background(theme.green, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: theme.green.opacity(0.35), radius: 12, y: 4)
                    }
                    .buttonStyle(SnapsButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .padding(.top, 8)
                    .background(theme.bg.opacity(0.95))
                }
            }
        }
    }

    // MARK: - Sub-views

    func courseRow(_ course: GolfCourse, distanceText: String? = nil) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedCourse = course
            selectedTeeBox = nil
            withAnimation(.spring()) { phase = .teePicker }
        } label: {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.green.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Text("⛳")
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(course.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        if !course.locationString.isEmpty {
                            Text(course.locationString)
                                .font(.system(size: 12))
                                .foregroundStyle(theme.textSecondary)
                        }
                        if let dist = distanceText {
                            if !course.locationString.isEmpty {
                                Text("·")
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.textMuted)
                            }
                            Text(dist)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(theme.green)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textMuted)
            }
            .padding(14)
            .background(theme.surface1, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.border, lineWidth: 1))
        }
        .buttonStyle(SnapsButtonStyle())
    }

    func teeBoxRow(_ tee: GolfTeeBox, course: GolfCourse) -> some View {
        let isSelected = selectedTeeBox?.id == tee.id
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.25)) {
                selectedTeeBox = isSelected ? nil : tee
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 8) {
                        // Tee color dot
                        Circle()
                            .fill(teeColor(tee.tee_name))
                            .frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
                            .shadow(color: teeColor(tee.tee_name).opacity(0.5), radius: 4)

                        Text(tee.displayName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(isSelected ? theme.green : theme.textPrimary)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? theme.green : theme.textMuted)
                }

                HStack(spacing: 16) {
                    statBadge("Par", value: "\(tee.parTotal)")
                    statBadge("Yards", value: "\(tee.totalYards)")
                    statBadge("Rating", value: String(format: "%.1f", tee.courseRating))
                    statBadge("Slope", value: "\(tee.slopeRating)")
                }

                // Hole pars preview (compact)
                if let holes = tee.holes, !holes.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(holes.prefix(9).indices, id: \.self) { i in
                            Text("\(holes[i].par)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(parColor(holes[i].par))
                                .frame(width: 22, height: 22)
                                .background(parColor(holes[i].par).opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                        }
                        if holes.count > 9 {
                            Text("·")
                                .foregroundStyle(theme.textMuted)
                                .font(.system(size: 11))
                            ForEach(holes.dropFirst(9).indices, id: \.self) { i in
                                let hole = holes.dropFirst(9)[holes.dropFirst(9).index(holes.dropFirst(9).startIndex, offsetBy: i)]
                                Text("\(hole.par)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(parColor(hole.par))
                                    .frame(width: 22, height: 22)
                                    .background(parColor(hole.par).opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? theme.green.opacity(0.06) : theme.surface1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? theme.green.opacity(0.5) : theme.border, lineWidth: 1)
                    )
            )
            .shadow(color: isSelected ? theme.green.opacity(0.15) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(SnapsButtonStyle())
    }

    func statBadge(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.textMuted)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(theme.surface2, in: RoundedRectangle(cornerRadius: 8))
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Text("⛳")
                .font(.system(size: 40))
            Text("No courses found for \"\(searchText)\"")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
            Text("Try a city name or partial course name")
                .font(.system(size: 12))
                .foregroundStyle(theme.textMuted)
        }
        .padding(.top, 50)
        .frame(maxWidth: .infinity)
    }

    var promptCard: some View {
        VStack(spacing: 14) {
            Text("⛳")
                .font(.system(size: 48))
            Text("Find Your Course")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(theme.textPrimary)
            Text("Search by course name or city to load official pars and handicaps")
                .font(.system(size: 13))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity)
    }

    var noTeesState: some View {
        VStack(spacing: 12) {
            Text("🏌️")
                .font(.system(size: 40))
            Text("No tee data available")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            Text("This course doesn't have tee box data in the API yet")
                .font(.system(size: 12))
                .foregroundStyle(theme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .padding(.top, 50)
    }

    func errorCard(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text("Error loading courses")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(theme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(theme.danger.opacity(0.25), lineWidth: 1))
        .padding(.top, 20)
    }

    func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(theme.textMuted)
            .tracking(1.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 2)
    }

    // MARK: - Nearby Courses Logic

    @MainActor
    func loadNearbyCourses(city: String) async {
        guard !nearbySearchDone else { return }
        isLoadingNearby = true
        do {
            let courses = try await GolfCourseService.shared.searchCourses(query: city)
            if let userLoc = locationManager.location {
                nearbyCourses = courses
                    .filter { $0.location?.latitude != nil && $0.location?.longitude != nil }
                    .sorted { a, b in
                        distanceMiles(from: userLoc, to: a) ?? .infinity <
                        distanceMiles(from: userLoc, to: b) ?? .infinity
                    }
                // Append courses without coordinates at the end
                let withoutCoords = courses.filter { $0.location?.latitude == nil || $0.location?.longitude == nil }
                nearbyCourses += withoutCoords
            } else {
                nearbyCourses = courses
            }
        } catch {
            nearbyCourses = []
        }
        isLoadingNearby = false
        nearbySearchDone = true
    }

    // MARK: - Distance Helpers

    func distanceMiles(from userLocation: CLLocation, to course: GolfCourse) -> Double? {
        guard let lat = course.location?.latitude,
              let lng = course.location?.longitude else { return nil }
        let courseLoc = CLLocation(latitude: lat, longitude: lng)
        let meters = userLocation.distance(from: courseLoc)
        return meters / 1609.344
    }

    func distanceText(for course: GolfCourse) -> String? {
        guard let userLoc = locationManager.location else { return nil }
        guard let miles = distanceMiles(from: userLoc, to: course) else { return nil }
        if miles < 10 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.0f mi", miles)
        }
    }

    // MARK: - Helpers

    func teeColor(_ name: String) -> Color {
        let lower = name.lowercased()
        if lower.contains("black") { return Color(hex: "#1A1A1A").opacity(0) == .clear ? .primary : Color(hex: "#888888") }
        if lower.contains("gold") || lower.contains("yellow") { return Color(hex: "#F59E0B") }
        if lower.contains("blue") { return Color(hex: "#3B82F6") }
        if lower.contains("white") { return Color(hex: "#E5E5E5") }
        if lower.contains("red") { return Color(hex: "#EF4444") }
        if lower.contains("green") { return Color(hex: "#22C55E") }
        if lower.contains("silver") { return Color(hex: "#9CA3AF") }
        if lower.contains("champion") { return Color(hex: "#8B5CF6") }
        return Color(hex: "#6B7280")
    }

    func teeColorActual(_ name: String) -> Color {
        let lower = name.lowercased()
        if lower.contains("black") { return Color(hex: "#444444") }
        if lower.contains("gold") || lower.contains("yellow") { return Color(hex: "#F59E0B") }
        if lower.contains("blue") { return Color(hex: "#3B82F6") }
        if lower.contains("white") { return Color(hex: "#D1D5DB") }
        if lower.contains("red") { return Color(hex: "#EF4444") }
        if lower.contains("green") { return Color(hex: "#22C55E") }
        if lower.contains("silver") { return Color(hex: "#9CA3AF") }
        if lower.contains("champion") { return Color(hex: "#8B5CF6") }
        return Color(hex: "#6B7280")
    }

    func parColor(_ par: Int) -> Color {
        switch par {
        case 3: return Color(hex: "#22C55E")
        case 5: return Color(hex: "#F59E0B")
        default: return Color(hex: "#6B7280")
        }
    }

    // MARK: - Debounce Setup

    func setupDebounce() {
        debounceSubject
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { query in
                let trimmed = query.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else {
                    results = []
                    errorMessage = nil
                    return
                }
                Task {
                    await performSearch(query: trimmed)
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    func performSearch(query: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let courses = try await GolfCourseService.shared.searchCourses(query: query)
            // Sort by distance if we have user location
            if let userLoc = locationManager.location {
                results = courses.sorted { a, b in
                    distanceMiles(from: userLoc, to: a) ?? .infinity <
                    distanceMiles(from: userLoc, to: b) ?? .infinity
                }
            } else {
                results = courses
            }
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    CoursePickerView { course, tee in
        print("Selected: \(course.displayName), tees: \(tee.displayName)")
    }
}
