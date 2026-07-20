import SwiftUI
#if os(iOS)
import UIKit
#endif

private enum PracticeScreen {
    case setup
    case live
    case report
}

/// Previous multi-turn, interviewer-led flow. The company quest now opens the
/// focused, one-question-at-a-time \`PracticeView\` in QuestionMockInterviewView.
struct LegacyPracticeView: View {
    @StateObject private var liveSession = LiveInterviewSession()
    @State private var screen: PracticeScreen = .setup
    @State private var selectedJob: JobLead
    @State private var selectedCategory: PracticeCategory = .behavioral
    @State private var activeConfig: InterviewLiveConfig?
    @State private var analysis: InterviewAnalysisResult?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var activeWeaknessContextId: String?
    @State private var savedReports: [InterviewReportSnapshot] = []
    @State private var isLoadingReports = false
    @State private var reportHistoryError: String?

    init(
        initialJob: JobLead = SampleCareerVividData.jobs[0],
        initialCategory: PracticeCategory = .behavioral
    ) {
        _selectedJob = State(initialValue: initialJob)
        _selectedCategory = State(initialValue: initialCategory)
    }

    var body: some View {
        ZStack {
            Color.cvSystemGroupedBackground.ignoresSafeArea()

            switch screen {
            case .setup:
                PracticeSetupScreen(
                    selectedJob: $selectedJob,
                    selectedCategory: $selectedCategory,
                    questions: questionsForSelection,
                    errorMessage: errorMessage,
                    savedReports: savedReports,
                    isLoadingReports: isLoadingReports,
                    reportHistoryError: reportHistoryError,
                    onRefreshReports: refreshReports,
                    onOpenReport: openSavedReport,
                    onStart: startInterview
                )
            case .live:
                LivePracticeScreen(
                    session: liveSession,
                    config: activeConfig ?? currentConfig,
                    isAnalyzing: isAnalyzing,
                    errorMessage: errorMessage,
                    onDoneAnswering: finishAnswering,
                    onEndInterview: endInterview,
                    onFeedback: requestFeedback,
                    onRetry: retryInterview,
                    onClose: closeLiveInterview
                )
            case .report:
                PracticeReportScreen(
                    config: activeConfig ?? currentConfig,
                    analysis: analysis,
                    elapsedSeconds: liveSession.elapsedSeconds,
                    onPracticeAgain: practiceAgainWithSameQuestion,
                    onRemediateWeakness: remediateWeakness,
                    onRemediateAll: remediateWeaknesses
                )
            }
        }
        .navigationTitle("Mock interview")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSavedReports()
        }
    }

    private var currentConfig: InterviewLiveConfig {
        InterviewLiveConfig(
            job: selectedJob,
            category: selectedCategory,
            questions: questionsForSelection
        )
    }

    private var questionsForSelection: [String] {
        roleSpecificQuestions(job: selectedJob, category: selectedCategory)
    }
}

// MARK: - Actions

private extension LegacyPracticeView {
    func startInterview() {
        let config = currentConfig
        activeConfig = config
        activeWeaknessContextId = nil
        analysis = nil
        errorMessage = nil
        isAnalyzing = false
        screen = .live
        liveSession.start(config: config)
    }

    func retryInterview() {
        let config = activeConfig ?? currentConfig
        activeConfig = config
        analysis = nil
        errorMessage = nil
        isAnalyzing = false
        screen = .live
        liveSession.start(config: config)
    }

    func finishAnswering() {
        liveSession.finishAnswering()
    }

    func endInterview() {
        liveSession.endInterview()
    }

    func closeLiveInterview() {
        liveSession.cancel(resetToIdle: true)
        screen = .setup
        isAnalyzing = false
    }

    func resetToSetup() {
        liveSession.cancel(resetToIdle: true)
        analysis = nil
        errorMessage = nil
        isAnalyzing = false
        activeWeaknessContextId = nil
        screen = .setup
    }

    func practiceAgainWithSameQuestion() {
        let config = activeConfig ?? currentConfig
        activeConfig = config
        activeWeaknessContextId = nil
        analysis = nil
        errorMessage = nil
        isAnalyzing = false
        screen = .live
        liveSession.start(config: config)
    }

    func remediateWeakness(_ weakness: ReportInsightItem) {
        startRemediationInterview(with: [weakness], contextId: weakness.id)
    }

    func remediateWeaknesses(_ weaknesses: [ReportInsightItem]) {
        let selectedWeaknesses = weaknesses.isEmpty
            ? ReportInsightParser.items(from: analysis?.areasForImprovement ?? "", kind: "weakness")
            : weaknesses
        startRemediationInterview(with: selectedWeaknesses, contextId: "weakness-booster-\(Date().timeIntervalSince1970)")
    }

    func startRemediationInterview(with weaknesses: [ReportInsightItem], contextId: String) {
        let baseConfig = activeConfig ?? currentConfig
        let focusItems = weaknesses.isEmpty
            ? [ReportInsightItem(id: "weakness-general", title: "Improve interview structure", body: "Practice clearer STAR answers, stronger examples, and tighter role relevance.", markdown: "Practice clearer STAR answers, stronger examples, and tighter role relevance.")]
            : weaknesses
        let focus = focusItems.map { "\($0.title): \($0.body)" }
        let config = InterviewLiveConfig(
            job: baseConfig.job,
            category: baseConfig.category,
            questions: remediationQuestions(for: focusItems, baseConfig: baseConfig),
            remediationContextId: contextId,
            remediationFocus: focus
        )
        activeConfig = config
        activeWeaknessContextId = contextId
        analysis = nil
        errorMessage = nil
        isAnalyzing = false
        screen = .live
        liveSession.start(config: config)
    }

    func requestFeedback() {
        guard !isAnalyzing else { return }
        let transcript = liveSession.transcriptEntries()
        guard transcript.contains(where: { $0.speaker == .user }) else {
            errorMessage = "Answer at least one question before generating feedback."
            return
        }

        let config = activeConfig ?? currentConfig
        isAnalyzing = true
        errorMessage = nil

        Task {
            do {
                let result = try await InterviewPracticeService().analyze(
                    config: config,
                    sessionId: liveSession.sessionId,
                    transcript: transcript,
                    durationInSeconds: liveSession.elapsedSeconds
                )
                LocalInterviewReportCache.save(result: result, config: config)
                rememberReport(.current(result: result, config: config))
                analysis = result
                screen = .report
            } catch {
                errorMessage = error.localizedDescription
            }
            isAnalyzing = false
        }
    }

    func openSavedReport(_ report: InterviewReportSnapshot) {
        playImpactHaptic(.light)
        let config = report.config
        selectedJob = config.job
        selectedCategory = config.category
        activeConfig = config
        activeWeaknessContextId = nil
        analysis = report.analysis
        errorMessage = nil
        isAnalyzing = false
        screen = .report
    }

    func refreshReports() {
        Task {
            await loadSavedReports(forceRemote: true)
        }
    }

    @MainActor
    func loadSavedReports(forceRemote: Bool = false) async {
        guard !isLoadingReports else { return }
        isLoadingReports = true
        reportHistoryError = nil

        let localReports = LocalInterviewReportCache.load().map(InterviewReportSnapshot.local)
        if !forceRemote, !localReports.isEmpty {
            savedReports = localReports
        }

        do {
            let remoteReports = try await RemoteInterviewReportStore().loadReports()
            let combined = mergeReports(primary: remoteReports, fallback: localReports)
            savedReports = combined
            reportHistoryError = nil
        } catch {
            if savedReports.isEmpty {
                savedReports = localReports
            }
            if savedReports.isEmpty {
                reportHistoryError = error.localizedDescription
            } else {
                reportHistoryError = "Showing local reports. Sign in or refresh to sync older Vivid reports."
            }
        }

        isLoadingReports = false
    }

    func rememberReport(_ report: InterviewReportSnapshot) {
        savedReports.removeAll { $0.analysis.id == report.analysis.id || $0.id == report.id }
        savedReports.insert(report, at: 0)
        savedReports = Array(savedReports.prefix(12))
    }

    func mergeReports(primary: [InterviewReportSnapshot], fallback: [InterviewReportSnapshot]) -> [InterviewReportSnapshot] {
        var seen = Set<String>()
        var merged: [InterviewReportSnapshot] = []

        for report in (primary + fallback).sorted(by: { $0.savedAt > $1.savedAt }) {
            let key = report.analysis.id
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            merged.append(report)
        }

        return Array(merged.prefix(12))
    }
}

// MARK: - Setup Screen

struct PracticeMetricPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.black))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 84)
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.cvSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.045), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Shared UI

struct PracticeCategoryChip: View {
    let category: PracticeCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption.weight(.semibold))
                Text(category.rawValue)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? Color.cvBrand : Color.cvSecondarySystemBackground)
            .clipShape(Capsule())
            .shadow(color: isSelected ? Color.cvBrand.opacity(0.16) : .clear, radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

struct PracticeErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Question Generation

func roleSpecificQuestions(job: JobLead, category: PracticeCategory) -> [String] {
    switch category {
    case .behavioral:
        return [
            "Tell me about a recent project that shows why you are a strong fit for \(job.title).",
            "Describe a time you had to make progress with unclear requirements or shifting priorities.",
            "What is one project outcome you are proud of, and what was your personal contribution?",
            "Tell me about feedback you received and how it changed the way you work.",
            "How do you communicate trade-offs to non-technical stakeholders?",
        ]
    case .systemDesign:
        return [
            "Let's design a core system a \(job.title) at \(job.company) might own. What requirements would you clarify first?",
            "How would you break that system into services, data stores, and async workflows?",
            "What are the main scaling risks, and how would you measure them?",
            "Where would you use caching, queues, or background jobs, and why?",
            "How would you monitor reliability and debug production incidents?",
        ]
    case .technical:
        return [
            "Walk me through a technical project that best proves you can do \(job.title) work.",
            "What was the hardest engineering decision in that project?",
            "How did you test or validate the solution before shipping?",
            "Tell me about a performance, reliability, or data problem you solved.",
            "What would you improve if you had another week on that project?",
        ]
    case .leadership:
        return [
            "Tell me about a time you influenced a technical decision without formal authority.",
            "How do you keep teammates aligned when priorities conflict?",
            "Describe a project where you raised the quality bar for the team.",
            "How do you coach or unblock other engineers while still delivering your own work?",
            "Tell me about a mistake or incident and how you helped the team learn from it.",
        ]
    }
}

/// Mobile company quests do not assume every answer should use STAR. They
/// choose a concise prompt for the actual company and stage, then the report
/// evaluates the response against that question.
func companyStageQuestions(
    job: JobLead,
    category: PracticeCategory,
    stageTitle: String?
) -> [String] {
    let stage = stageTitle?.lowercased() ?? ""

    if stage.contains("recruiter") {
        return [
            "Why are you interested in \(job.company), and what makes this role the right next step for you?",
            "What part of your background would help you make an impact at \(job.company) quickly?",
            "What are you looking for in your next team, and how does \(job.company) fit that?"
        ]
    }

    if stage.contains("final") {
        return [
            "What would you prioritize in your first 90 days at \(job.company), and why?",
            "Tell me about a difficult judgment call that shows how you would lead work at \(job.company).",
            "What questions would you ask a hiring manager to decide whether you can do your best work here?"
        ]
    }

    if stage.contains("behavioral") || stage.contains("value") {
        return [
            "Tell me about a time you resolved a difficult conflict with a teammate. What changed because of your approach?",
            "Describe a time you took ownership when the path was unclear. How would that experience help at \(job.company)?",
            "Tell me about a decision where you balanced speed, quality, and collaboration."
        ]
    }

    if stage.contains("coding") {
        return [
            "Walk through how you would solve a representative coding problem in \(job.company)'s interview style. Start with your approach and trade-offs.",
            "How would you test the solution and explain its complexity to an interviewer?",
            "What would make you choose a simpler implementation over a more optimized one?"
        ]
    }

    if stage.contains("system") {
        return [
            "Design a core system that \(job.company) might rely on. What requirements would you clarify first?",
            "What trade-offs would you make around reliability, latency, and cost?",
            "How would you know the design was working once it reached production scale?"
        ]
    }

    switch category {
    case .behavioral:
        return [
            "Tell me about a recent project that shows why you could contribute at \(job.company).",
            "Describe a time you had to make progress with unclear requirements. What did you decide and why?",
            "What is one project outcome you are proud of, and what was your personal contribution?"
        ]
    case .systemDesign:
        return [
            "Design a core system a \(job.title) at \(job.company) might own. What requirements would you clarify first?",
            "How would you break that system into services, data stores, and async workflows?",
            "What are the main scaling risks, and how would you measure them?"
        ]
    case .technical:
        return [
            "Walk me through a technical project that best proves you can do \(job.title) work at \(job.company).",
            "What was the hardest engineering decision in that project, and what evidence guided you?",
            "How did you test or validate the solution before shipping?"
        ]
    case .leadership:
        return [
            "Tell me about a time you influenced a technical decision without formal authority.",
            "How would you keep teammates aligned when priorities conflict at \(job.company)?",
            "Describe a project where you raised the quality bar for the team."
        ]
    }
}
