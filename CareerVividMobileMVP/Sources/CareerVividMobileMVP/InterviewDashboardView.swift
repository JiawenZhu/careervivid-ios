import SwiftUI

/// The home tab is intentionally interview-first. Every card is derived from
/// persisted report history so a new attempt adds context instead of erasing a
/// previous report for the same question.
struct InterviewDashboardView: View {
    @State private var reports = LocalInterviewReportCache.load().map(InterviewReportSnapshot.local)
    @State private var isLoading = true
    @State private var loadError: String?

    private var summary: InterviewDashboardSummary {
        InterviewDashboardSummary(reports: reports)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    InterviewDashboardHeader()

                    if reports.isEmpty && !isLoading {
                        InterviewDashboardEmptyState(message: loadError)
                    } else {
                        InterviewDashboardHero(summary: summary)
                        InterviewDashboardMetricRow(summary: summary)
                        InterviewDashboardNextStep(summary: summary)
                        InterviewDashboardInsightCard(
                            title: "What you are doing well",
                            subtitle: "Carry this into your next answer.",
                            icon: "checkmark.circle.fill",
                            tint: Color.cvQuestionSuccess,
                            background: Color.cvQuestionSuccess.opacity(0.08),
                            message: summary.primaryStrength
                        )
                        InterviewDashboardInsightCard(
                            title: "Focus next",
                            subtitle: "One clear way to improve your next report.",
                            icon: "target",
                            tint: Color.cvQuestionWarning,
                            background: Color.cvQuestionWarning.opacity(0.09),
                            message: summary.primaryImprovement
                        )
                        InterviewDashboardRecentReports(reports: reports)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, CVLayout.floatingTabContentPadding)
            }
            .background(Color.cvSystemGroupedBackground.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .task { await refreshReports() }
        .refreshable { await refreshReports() }
    }

    @MainActor
    private func refreshReports() async {
        isLoading = true
        defer { isLoading = false }
        do {
            reports = try await RemoteInterviewReportStore().loadReports(limit: 200)
            loadError = nil
        } catch {
            // Reports remain accessible offline from the unbounded device cache.
            reports = LocalInterviewReportCache.load().map(InterviewReportSnapshot.local)
            loadError = reports.isEmpty ? error.localizedDescription : nil
        }
    }
}

private struct InterviewDashboardHeader: View {
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.cvInkSecondary)
            Text("Your interview practice")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.cvInk)
            Text("Every report stays here, so you can see what is improving.")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.cvInkSecondary)
        }
    }
}

private struct InterviewDashboardHero: View {
    let summary: InterviewDashboardSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Interview activity")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.cvInk)
                    Text("Last 13 weeks")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.cvInkSecondary)
                }
                Spacer()
                Label("\(summary.activeDayCount) active days", systemImage: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.cvQuestionLavenderText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.cvQuestionSoftLavender.opacity(0.55), in: Capsule())
            }

            InterviewDashboardHeatmap(activityByDay: summary.activityByDay)

            HStack(spacing: 7) {
                Circle().fill(Color.cvQuestionHeatEmpty).frame(width: 7, height: 7)
                Text("Less")
                ForEach(1...4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(InterviewDashboardHeatmap.color(for: level))
                        .frame(width: 10, height: 10)
                }
                Text("More")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.cvInkSecondary)
        }
        .padding(18)
        .background(Color.cvSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.cvHairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.055), radius: 12, x: 0, y: 5)
    }
}

private struct InterviewDashboardHeatmap: View {
    let activityByDay: [Date: Int]
    private let calendar = Calendar.current
    private let columns = 13
    private let rows = 7

    var body: some View {
        let end = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(columns * rows - 1), to: end) ?? end
        HStack(spacing: 4) {
            ForEach(0..<columns, id: \.self) { column in
                VStack(spacing: 4) {
                    ForEach(0..<rows, id: \.self) { row in
                        let offset = column * rows + row
                        let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
                        let count = activityByDay[calendar.startOfDay(for: day), default: 0]
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Self.color(for: count))
                            .frame(maxWidth: .infinity)
                            .frame(height: 13)
                            .accessibilityLabel("\(count) interview reports on \(day.formatted(.dateTime.month().day()))")
                    }
                }
            }
        }
    }

    static func color(for count: Int) -> Color {
        switch count {
        case 4...: return Color.cvQuestionSuccess.opacity(0.90)
        case 3: return Color.cvQuestionDashboardBlue.opacity(0.75)
        case 2: return Color.cvQuestionLavenderText.opacity(0.72)
        case 1: return Color.cvQuestionSoftLavender
        default: return Color.cvQuestionHeatEmpty
        }
    }
}

private struct InterviewDashboardMetricRow: View {
    let summary: InterviewDashboardSummary

    var body: some View {
        HStack(spacing: 10) {
            InterviewDashboardMetric(value: "\(summary.totalAttempts)", label: "reports", icon: "doc.text.fill", tint: Color.cvQuestionLavenderText)
            InterviewDashboardMetric(value: "\(summary.currentStreak)", label: "day streak", icon: "flame.fill", tint: Color.cvQuestionWarning)
            InterviewDashboardMetric(value: "\(summary.averageScore)", label: "average", icon: "chart.line.uptrend.xyaxis", tint: Color.cvQuestionSuccess)
        }
    }
}

private struct InterviewDashboardMetric: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.cvInk)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.cvInkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.cvSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.cvHairline, lineWidth: 1))
    }
}

private struct InterviewDashboardNextStep: View {
    let summary: InterviewDashboardSummary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.right.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.cvQuestionLavenderText)
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.progressMessage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.cvInk)
                Text(summary.nextStep)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.cvInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .background(Color.cvQuestionSoftLavender.opacity(0.30), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Color.cvQuestionSoftLavender, lineWidth: 1))
    }
}

private struct InterviewDashboardInsightCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let background: Color
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title).font(.subheadline.weight(.bold)).foregroundStyle(Color.cvInk)
            }
            Text(subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.cvInkSecondary)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.cvInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(tint.opacity(0.20), lineWidth: 1))
    }
}

private struct InterviewDashboardRecentReports: View {
    let reports: [InterviewReportSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent reports")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.cvInk)
            Text("Every attempt is saved independently — including a new report for the same question.")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.cvInkSecondary)

            ForEach(reports.prefix(5)) { report in
                NavigationLink {
                    InterviewSavedReportDetail(report: report)
                } label: {
                    HStack(spacing: 12) {
                        Text("\(report.analysis.overallScore)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(scoreTint(report.analysis.overallScore))
                            .frame(width: 42, height: 42)
                            .background(scoreTint(report.analysis.overallScore).opacity(0.10), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(report.company) · \(report.category.rawValue)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.cvInk)
                                .lineLimit(1)
                            Text(report.question)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.cvInkSecondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(report.displayDate)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.cvInkSecondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.cvInkTertiary)
                        }
                    }
                    .padding(12)
                    .background(Color.cvSurface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.cvHairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens this saved interview report")
            }
        }
    }

    private func scoreTint(_ score: Int) -> Color {
        switch score {
        case 75...: return Color.cvQuestionSuccess
        case 55...: return Color.cvQuestionWarning
        default: return Color.cvQuestionDanger
        }
    }
}

private struct InterviewSavedReportDetail: View {
    @Environment(\.dismiss) private var dismiss
    let report: InterviewReportSnapshot

    var body: some View {
        QuestionAnalysisScreen(
            company: report.company,
            category: report.category,
            stageTitle: report.category.rawValue,
            question: report.question,
            analysis: report.analysis,
            elapsedSeconds: report.analysis.durationInSeconds ?? 0,
            onBack: dismiss.callAsFunction,
            onPracticeAgain: {},
            onPracticeFollowUp: {},
            onNextQuestion: {},
            backLabel: "Back to reports",
            showsActions: false,
            showsFullTranscript: true
        )
        .background(Color.cvSystemGroupedBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }
}

private struct InterviewDashboardEmptyState: View {
    let message: String?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "mic.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(Color.cvQuestionLavenderText)
                .frame(width: 62, height: 62)
                .background(Color.cvQuestionSoftLavender.opacity(0.58), in: Circle())
            Text("Your interview dashboard is ready")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.cvInk)
            Text(message ?? "Complete your first mock answer and its feedback, score, strengths, and next steps will be saved here.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.cvInkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.cvSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.cvHairline, lineWidth: 1))
    }
}

private struct InterviewDashboardSummary {
    let reports: [InterviewReportSnapshot]
    private let calendar = Calendar.current

    init(reports: [InterviewReportSnapshot]) {
        self.reports = reports.sorted { $0.savedAt > $1.savedAt }
    }

    var totalAttempts: Int { reports.count }
    var averageScore: Int {
        guard !reports.isEmpty else { return 0 }
        return Int((Double(reports.map(\.analysis.overallScore).reduce(0, +)) / Double(reports.count)).rounded())
    }
    var activityByDay: [Date: Int] {
        Dictionary(grouping: reports) { report in
            calendar.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(report.savedAt) / 1000))
        }.mapValues(\.count)
    }
    var activeDayCount: Int { activityByDay.count }
    var currentStreak: Int { streak(from: calendar.startOfDay(for: Date())) }

    var primaryStrength: String {
        insight(from: reports.first?.analysis.strengths) ?? "Keep recording concrete examples — they make your interview story easier to trust."
    }
    var primaryImprovement: String {
        insight(from: reports.first?.analysis.areasForImprovement) ?? "Practice one focused answer, then use the next report to check whether your clarity improved."
    }
    var progressMessage: String {
        guard reports.count > 1 else { return "Your first benchmark is saved" }
        let recent = reports.prefix(3).map(\.analysis.overallScore)
        let earlier = reports.dropFirst(3).prefix(3).map(\.analysis.overallScore)
        guard !earlier.isEmpty else { return "Build a useful baseline with a few more reports" }
        let delta = recent.reduce(0, +) / recent.count - earlier.reduce(0, +) / earlier.count
        return delta > 0 ? "Your recent score is up \(delta) points" : delta < 0 ? "Your recent score is down \(abs(delta)) points" : "Your recent scores are holding steady"
    }
    var nextStep: String { primaryImprovement }

    private func streak(from start: Date) -> Int {
        var cursor = start
        var count = 0
        while activityByDay[cursor] != nil {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private func insight(from raw: String?) -> String? {
        guard let raw else { return nil }
        let items = raw
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "*-•"))) }
            .filter { !$0.isEmpty }
        return items.first ?? raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension InterviewReportSnapshot {
    var question: String {
        analysis.transcript.last(where: { $0.speaker == .interviewer })?.text
            ?? questions.first
            ?? "Interview practice"
    }
}

private extension Color {
    static let cvQuestionPaper = Color(red: 1.000, green: 0.980, blue: 0.945) // #FFFAF1
    static let cvQuestionCard = Color(red: 1.000, green: 0.979, blue: 0.941) // #FFF9F0
    static let cvQuestionInk = Color(red: 0.129, green: 0.106, blue: 0.086) // #211B16
    static let cvQuestionBody = Color(red: 0.400, green: 0.353, blue: 0.290) // #665A4A
    static let cvQuestionMuted = Color(red: 0.420, green: 0.447, blue: 0.514) // #6B7283
    static let cvQuestionBorder = Color(red: 0.894, green: 0.827, blue: 0.737) // #E4D3BC
    static let cvQuestionShadow = Color(red: 0.545, green: 0.353, blue: 0.086).opacity(0.08)
    static let cvQuestionSoftLavender = Color(red: 0.875, green: 0.886, blue: 1.000) // #DFE2FF
    static let cvQuestionLavenderText = Color(red: 0.553, green: 0.533, blue: 0.902) // #8D88E6
    static let cvQuestionDashboardBlue = Color(red: 0.231, green: 0.510, blue: 0.965) // #3B82F6
    static let cvQuestionHeatEmpty = Color(red: 0.925, green: 0.922, blue: 0.940) // #ECEBF0
    static let cvQuestionSuccess = Color(red: 0.082, green: 0.502, blue: 0.239) // #15803D
    static let cvQuestionWarning = Color(red: 0.851, green: 0.467, blue: 0.024) // #D97706
    static let cvQuestionDanger = Color(red: 0.882, green: 0.114, blue: 0.282) // #E11D48
}
