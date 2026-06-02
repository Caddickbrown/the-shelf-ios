import SwiftUI
import Foundation

// MARK: - Stats Response Models

struct StatsResponse: Decodable {
    let total: Int
    let totalRead: Int
    let totalReading: Int
    let totalToRead: Int
    let avgRating: Double?
    let fiveStars: Int
    let byYear: [YearCount]
    let topAuthors: [AuthorCount]
    let ratings: [String: Int]

    enum CodingKeys: String, CodingKey {
        case total
        case totalRead     = "total_read"
        case totalReading  = "total_reading"
        case totalToRead   = "total_to_read"
        case avgRating     = "avg_rating"
        case fiveStars     = "five_stars"
        case byYear        = "by_year"
        case topAuthors    = "top_authors"
        case ratings
    }
}

struct YearCount: Decodable, Identifiable {
    let year: Int
    let count: Int
    var id: Int { year }
}

struct AuthorCount: Decodable, Identifiable {
    let author: String
    let count: Int
    var id: String { author }
}

struct StatsExtendedResponse: Decodable {
    let genres: [GenreCount]
    let monthly: [MonthCount]
    let unreadCount: Int
    let avgPerYear: Double?
    let yearsToClear: Double?
    let formats: [FormatCount]

    enum CodingKeys: String, CodingKey {
        case genres, monthly, formats
        case unreadCount  = "unread_count"
        case avgPerYear   = "avg_per_year"
        case yearsToClear = "years_to_clear"
    }
}

struct GenreCount: Decodable, Identifiable {
    let genre: String
    let count: Int
    var id: String { genre }
}

struct MonthCount: Decodable, Identifiable {
    let month: String
    let count: Int
    var id: String { month }
}

struct FormatCount: Decodable, Identifiable {
    let format: String
    let count: Int
    var id: String { format }
}


// MARK: - StatsView

struct StatsView: View {
    @Environment(ShelfTheme.self) var theme

    @State private var stats: StatsResponse?
    @State private var extended: StatsExtendedResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(theme.accent)
                        Text("Loading stats…")
                            .font(.subheadline)
                            .foregroundStyle(theme.muted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundStyle(theme.orange)
                        Text("Couldn't load stats")
                            .font(.headline)
                            .foregroundStyle(theme.text)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(theme.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") { Task { await loadData() } }
                            .buttonStyle(.bordered)
                            .tint(theme.accent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    mainScrollView
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await loadData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(theme.accent)
                    }
                }
            }
        }
        .shelfBackground()
        .task { await loadData() }
    }

    // MARK: - Main scroll content

    private var mainScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let s = stats {
                    summarySection(s)
                    booksReadByYearSection(s)
                    ratingDistributionSection(s)
                    topAuthorsSection(s)
                }
                if let ext = extended {
                    readingPaceSection(ext)
                    genreDistributionSection(ext)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Section: Summary Cards

    private func summarySection(_ s: StatsResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            StatsSectionHeader(title: "Overview")

            let yearsToClear = extended?.yearsToClear
            let cards: [SummaryCardData] = [
                SummaryCardData(label: "Total Books",   value: "\(s.total)",             icon: "books.vertical.fill",   color: theme.accent),
                SummaryCardData(label: "Read",          value: "\(s.totalRead)",          icon: "checkmark.seal.fill",   color: theme.green),
                SummaryCardData(label: "Reading",       value: "\(s.totalReading)",       icon: "book.fill",             color: theme.blue),
                SummaryCardData(label: "To-Read Pile",  value: "\(s.totalToRead)",        icon: "tray.full.fill",        color: theme.orange),
                SummaryCardData(label: "Avg Rating",    value: avgRatingString(s.avgRating), icon: "star.fill",          color: Color(hex: "#FFD700")),
                SummaryCardData(label: "Five-Star Reads", value: "\(s.fiveStars)",        icon: "star.circle.fill",      color: Color(hex: "#FFD700")),
                SummaryCardData(label: "Years to Clear", value: yearsToClearString(yearsToClear), icon: "calendar.badge.clock", color: theme.red),
            ]

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(cards) { card in
                    SummaryCard(data: card)
                }
            }
        }
    }

    private func avgRatingString(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.1f ★", v)
    }

    private func yearsToClearString(_ v: Double?) -> String {
        guard let v, v > 0 else { return "—" }
        if v < 1 { return String(format: "%.1f yr", v) }
        return String(format: "%.0f yrs", v)
    }

    // MARK: - Section: Books Read by Year

    private func booksReadByYearSection(_ s: StatsResponse) -> some View {
        let sorted = s.byYear.sorted { $0.year < $1.year }
        let maxVal = sorted.map(\.count).max() ?? 1
        return VStack(alignment: .leading, spacing: 12) {
            StatsSectionHeader(title: "Books Read by Year")
            if sorted.isEmpty {
                emptyMessage("No year data yet")
            } else {
                VStack(spacing: 6) {
                    ForEach(sorted) { item in
                        BarRow(
                            label: "\(item.year)",
                            value: item.count,
                            maxValue: maxVal,
                            color: theme.accent
                        )
                    }
                }
                .padding(14)
                .shelfCard()
            }
        }
    }

    // MARK: - Section: Reading Pace (last 24 months)

    private func readingPaceSection(_ ext: StatsExtendedResponse) -> some View {
        // Show last 24 months, sorted by month string (ISO "YYYY-MM" sorts lexicographically)
        let sorted = ext.monthly.sorted { $0.month < $1.month }
        let recent = Array(sorted.suffix(24))
        let maxVal = recent.map(\.count).max() ?? 1
        return VStack(alignment: .leading, spacing: 12) {
            StatsSectionHeader(title: "Reading Pace (Last 24 Months)")
            if recent.isEmpty {
                emptyMessage("No monthly data yet")
            } else {
                VStack(spacing: 6) {
                    ForEach(recent) { item in
                        BarRow(
                            label: shortMonth(item.month),
                            value: item.count,
                            maxValue: maxVal,
                            color: theme.green
                        )
                    }
                }
                .padding(14)
                .shelfCard()
            }
        }
    }

    private func shortMonth(_ iso: String) -> String {
        // iso = "2024-03" → "Mar '24"
        let parts = iso.split(separator: "-")
        guard parts.count == 2,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              m >= 1, m <= 12 else { return iso }
        let names = ["Jan","Feb","Mar","Apr","May","Jun",
                     "Jul","Aug","Sep","Oct","Nov","Dec"]
        let yy = y % 100
        return "\(names[m-1]) '\(String(format: "%02d", yy))"
    }

    // MARK: - Section: Genre Distribution

    private func genreDistributionSection(_ ext: StatsExtendedResponse) -> some View {
        let sorted = ext.genres.sorted { $0.count > $1.count }
        let maxVal = sorted.map(\.count).max() ?? 1
        let purple = Color(hex: "#9b59b6")
        return VStack(alignment: .leading, spacing: 12) {
            StatsSectionHeader(title: "Genre Distribution")
            if sorted.isEmpty {
                emptyMessage("No genre data yet")
            } else {
                VStack(spacing: 6) {
                    ForEach(sorted) { item in
                        BarRow(
                            label: item.genre.isEmpty ? "Unknown" : item.genre,
                            value: item.count,
                            maxValue: maxVal,
                            color: purple
                        )
                    }
                }
                .padding(14)
                .shelfCard()
            }
        }
    }

    // MARK: - Section: Top Authors

    private func topAuthorsSection(_ s: StatsResponse) -> some View {
        let maxVal = s.topAuthors.map(\.count).max() ?? 1
        return VStack(alignment: .leading, spacing: 12) {
            StatsSectionHeader(title: "Top Authors")
            if s.topAuthors.isEmpty {
                emptyMessage("No author data yet")
            } else {
                VStack(spacing: 6) {
                    ForEach(s.topAuthors) { item in
                        BarRow(
                            label: item.author,
                            value: item.count,
                            maxValue: maxVal,
                            color: theme.accent
                        )
                    }
                }
                .padding(14)
                .shelfCard()
            }
        }
    }

    // MARK: - Section: Rating Distribution

    private func ratingDistributionSection(_ s: StatsResponse) -> some View {
        let gold = Color(hex: "#FFD700")
        let maxVal = (1...5).map { s.ratings["\($0)"] ?? 0 }.max() ?? 1

        return VStack(alignment: .leading, spacing: 12) {
            StatsSectionHeader(title: "Rating Distribution")
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(1...5, id: \.self) { star in
                    let count = s.ratings["\(star)"] ?? 0
                    RatingBar(
                        star: star,
                        count: count,
                        maxValue: maxVal,
                        color: gold
                    )
                }
            }
            .frame(height: 160)
            .padding(14)
            .shelfCard()
        }
    }

    // MARK: - Helpers

    private func emptyMessage(_ msg: String) -> some View {
        Text(msg)
            .font(.subheadline)
            .foregroundStyle(theme.muted)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
            .shelfCard()
    }

    // MARK: - Data loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let s = ShelfAPIService.shared.fetchStats()
            async let e = ShelfAPIService.shared.fetchStatsExtended()
            let (statsResult, extResult) = try await (s, e)
            stats = statsResult
            extended = extResult
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - StatsSectionHeader

private struct StatsSectionHeader: View {
    @Environment(ShelfTheme.self) var theme
    let title: String

    var body: some View {
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(theme.text)
    }
}

// MARK: - SummaryCard

private struct SummaryCardData: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let icon: String
    let color: Color
}

private struct SummaryCard: View {
    @Environment(ShelfTheme.self) var theme
    let data: SummaryCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: data.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(data.color)
                Spacer()
            }
            Text(data.value)
                .font(.title2.bold())
                .foregroundStyle(theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(data.label)
                .font(.caption)
                .foregroundStyle(theme.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .shelfCard()
    }
}

// MARK: - BarRow (reusable horizontal bar)

struct BarRow: View {
    @Environment(ShelfTheme.self) var theme
    let label: String
    let value: Int
    let maxValue: Int
    let color: Color

    private let labelWidth: CGFloat = 80

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.muted)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: labelWidth, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.surface2)
                        .frame(height: 14)

                    // Fill
                    let ratio = maxValue > 0 ? CGFloat(value) / CGFloat(maxValue) : 0
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(4, geo.size.width * ratio), height: 14)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 20)

            Text("\(value)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(theme.muted)
                .frame(minWidth: 28, alignment: .trailing)
        }
    }
}

// MARK: - RatingBar (vertical bar for rating distribution)

struct RatingBar: View {
    @Environment(ShelfTheme.self) var theme
    let star: Int
    let count: Int
    let maxValue: Int
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let availableHeight = geo.size.height - 38 // reserve space for count + label
            let ratio = maxValue > 0 ? CGFloat(count) / CGFloat(maxValue) : 0
            let barHeight = max(4, availableHeight * ratio)

            VStack(spacing: 4) {
                // Count above bar
                Text("\(count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(theme.muted)
                    .frame(height: 16)

                Spacer(minLength: 0)

                // Bar
                VStack {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(height: barHeight)
                }
                .frame(maxWidth: .infinity)

                // Star label
                Text("\(star)★")
                    .font(.caption2)
                    .foregroundStyle(theme.muted)
                    .frame(height: 18)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    StatsView()
        .environment(ShelfTheme.shared)
}
