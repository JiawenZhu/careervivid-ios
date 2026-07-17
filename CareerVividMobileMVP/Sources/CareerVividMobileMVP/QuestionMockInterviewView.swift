@preconcurrency import AVFoundation
import SafariServices
import Speech
import SwiftUI

/// The company quest's focused mobile experience: one real interview question,
/// one timed spoken answer, and one report grounded in that exact response.
struct PracticeView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var answerSession = TimedAnswerSession()
    @State private var selectedJob: JobLead
    @State private var selectedCategory: PracticeCategory
    @State private var stageTitle: String?
    private let guideSlug: String?
    @State private var questions: [String] = []
    @State private var officialSourceURL = ""
    @State private var isLoadingQuestions = true
    @State private var questionLoadError: String?
    @State private var questionIndex = 0
    @State private var questionOverride: String?
    @State private var analysis: InterviewAnalysisResult?
    @State private var isAnalyzing = false
    @State private var isVividTranscribing = false
    @State private var errorMessage: String?
    @State private var showsTypedAnswer = false
    @State private var typedAnswer = ""
    @State private var transcriptionSuggestions: [String] = []

    init(
        initialJob: JobLead = SampleCareerVividData.jobs[0],
        initialCategory: PracticeCategory = .behavioral,
        initialStageTitle: String? = nil,
        guideSlug: String? = nil
    ) {
        _selectedJob = State(initialValue: initialJob)
        _selectedCategory = State(initialValue: initialCategory)
        _stageTitle = State(initialValue: initialStageTitle)
        self.guideSlug = guideSlug
    }

    var body: some View {
        Group {
            if let websiteStage {
                QuestionWebQuestStageView(
                    company: selectedJob.company,
                    guideSlug: guideSlug ?? "",
                    stage: websiteStage,
                    onClose: dismiss.callAsFunction
                )
            } else {
                nativeQuestionFlow
            }
        }
        .questionNavigationChromeHidden()
    }

    private var nativeQuestionFlow: some View {
        ZStack {
            QuestionPracticeGrid()

            if isLoadingQuestions {
                QuestionCatalogLoadingScreen(company: selectedJob.company, stageTitle: stageTitle)
            } else if let questionLoadError {
                QuestionCatalogUnavailableScreen(
                    company: selectedJob.company,
                    message: questionLoadError,
                    onBack: dismiss.callAsFunction,
                    onRetry: loadOfficialQuestions
                )
            } else if let analysis {
                QuestionAnalysisScreen(
                    company: selectedJob.company,
                    category: selectedCategory,
                    stageTitle: stageTitle,
                    question: activeQuestion,
                    analysis: analysis,
                    elapsedSeconds: analysis.durationInSeconds ?? answerSession.elapsedSeconds,
                    onBack: dismiss.callAsFunction,
                    onPracticeAgain: practiceAgain,
                    onPracticeFollowUp: practiceFollowUp,
                    onNextQuestion: nextQuestion
                )
            } else if isAnalyzing {
                QuestionReportGeneratingScreen(
                    company: selectedJob.company,
                    category: selectedCategory,
                    stageTitle: stageTitle,
                    answer: typedAnswer.isEmpty ? answerSession.transcript : typedAnswer,
                    elapsedSeconds: answerSession.elapsedSeconds
                )
            } else {
                QuestionAnswerScreen(
                    company: selectedJob.company,
                    category: selectedCategory,
                    stageTitle: stageTitle,
                    questionNumber: questionIndex + 1,
                    questionCount: questions.count,
                    question: activeQuestion,
                    officialSourceURL: officialSourceURL,
                    session: answerSession,
                    isAnalyzing: isAnalyzing,
                    isVividTranscribing: isVividTranscribing,
                    errorMessage: errorMessage,
                    transcriptionSuggestions: transcriptionSuggestions,
                    showsTypedAnswer: $showsTypedAnswer,
                    typedAnswer: $typedAnswer,
                    onBack: dismiss.callAsFunction,
                    onRecordAction: recordAction,
                    onAnalyzeTypedAnswer: analyzeTypedAnswer
                )
            }
        }
        .onChange(of: answerSession.transcript) { _, transcript in
            guard answerSession.state == .recording
                    || answerSession.state == .transcribing
                    || answerSession.state == .readyToAnalyze else { return }
            typedAnswer = transcript
        }
        .onChange(of: answerSession.state) { _, state in
            guard state == .readyToAnalyze else { return }
            Task { await replacePreviewWithVividTranscript() }
        }
        .task(id: questionCatalogRequestKey) {
            await loadOfficialQuestions()
        }
        .onDisappear {
            answerSession.reset()
        }
    }

    private var websiteStage: QuestionWebQuestStage? {
        QuestionWebQuestStage.resolve(stageTitle: stageTitle, category: selectedCategory)
    }

    private var questionCatalogRequestKey: String {
        "\(guideSlug ?? "")|\(stageTitle ?? selectedCategory.rawValue)"
    }

    private var activeQuestion: String {
        guard questions.indices.contains(questionIndex) else { return "" }
        return questionOverride ?? questions[questionIndex]
    }

    private var activeConfig: InterviewLiveConfig {
        InterviewLiveConfig(
            job: selectedJob,
            category: selectedCategory,
            questions: questions,
            questionContext: activeQuestion,
            remediationContextId: nil
        )
    }

    private func recordAction() {
        errorMessage = nil
        switch answerSession.state {
        case .recording:
            finishRecording()
        case .preparing, .transcribing:
            break
        case .idle, .ready, .readyToAnalyze, .failed:
            startRecording()
        }
    }

    private func startRecording() {
        errorMessage = nil
        guard answerSession.state != .recording && answerSession.state != .transcribing else { return }
        typedAnswer = ""
        transcriptionSuggestions = []
        Task { await answerSession.startRecording() }
    }

    private func finishRecording() {
        guard answerSession.state == .recording else { return }
        answerSession.stopRecording()
    }

    private func loadOfficialQuestions() async {
        guard let guideSlug, !guideSlug.isEmpty else {
            isLoadingQuestions = false
            questionLoadError = "Choose a company guide to load its official interview questions."
            return
        }

        isLoadingQuestions = true
        questionLoadError = nil
        errorMessage = nil

        do {
            let response = try await InterviewPracticeService().fetchOfficialQuestions(
                guideSlug: guideSlug,
                stage: stageTitle ?? selectedCategory.rawValue
            )
            let officialQuestions = response.questions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !officialQuestions.isEmpty else {
                throw InterviewPracticeServiceError.functionError("The official question catalog returned no usable questions for this stage.")
            }
            questions = officialQuestions
            officialSourceURL = response.sourceURL
            questionIndex = min(questionIndex, max(officialQuestions.count - 1, 0))
        } catch {
            questions = []
            officialSourceURL = ""
            questionLoadError = error.localizedDescription
        }
        isLoadingQuestions = false
    }

    private func analyzeTypedAnswer() {
        let answer = typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else {
            errorMessage = "Add an answer before requesting feedback."
            return
        }
        analyze(answer: answer, duration: max(answerSession.elapsedSeconds, 1))
    }

    /// Apple provides a live preview while recording. Once the candidate
    /// stops, Vivid receives the captured WAV and returns the
    /// editable source-of-truth transcript for the report.
    private func replacePreviewWithVividTranscript() async {
        guard !isVividTranscribing,
              let audio = answerSession.vividAudioWAV,
              !audio.isEmpty else { return }

        isVividTranscribing = true
        defer { isVividTranscribing = false }

        do {
            let result = try await InterviewPracticeService().transcribe(
                audioWAV: audio,
                durationInSeconds: answerSession.elapsedSeconds,
                question: activeQuestion,
                company: selectedJob.company,
                stage: stageTitle ?? selectedCategory.rawValue
            )
            let transcript = result.transcript
            guard !transcript.isEmpty else {
                errorMessage = "Vivid could not hear a clear answer. You can record again or edit the answer below."
                return
            }
            typedAnswer = transcript
            transcriptionSuggestions = result.suggestions
            answerSession.replaceTranscript(with: transcript)
        } catch {
            // Preserve Apple’s live preview if Vivid is temporarily offline;
            // the candidate can still correct it instead of losing the answer.
            if typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errorMessage = "Vivid transcription could not finish. Type your answer below or record again."
            }
        }
    }

    private func analyze(answer: String, duration: Int) {
        guard !isAnalyzing else { return }

        let cleanAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAnswer.isEmpty else {
            errorMessage = "We could not capture an answer. Try recording again or type your response."
            return
        }

        isAnalyzing = true
        errorMessage = nil
        let transcript = [
            InterviewTranscriptEntry(
                speaker: .interviewer,
                text: activeQuestion,
                isFinal: true,
                timestamp: Int(Date().timeIntervalSince1970 * 1_000)
            ),
            InterviewTranscriptEntry(
                speaker: .user,
                text: cleanAnswer,
                isFinal: true,
                timestamp: Int(Date().timeIntervalSince1970 * 1_000)
            )
        ]
        let config = activeConfig

        Task {
            do {
                let result = try await InterviewPracticeService().analyze(
                    config: config,
                    sessionId: nil,
                    transcript: transcript,
                    durationInSeconds: max(duration, 1)
                )
                LocalInterviewReportCache.save(result: result, config: config)
                analysis = result
                QuestionHaptic.play(.medium)
            } catch {
                errorMessage = error.localizedDescription
            }
            isAnalyzing = false
        }
    }

    private func practiceAgain() {
        QuestionHaptic.play(.light)
        questionOverride = nil
        analysis = nil
        errorMessage = nil
        showsTypedAnswer = false
        typedAnswer = ""
        transcriptionSuggestions = []
        answerSession.reset()
    }

    private func practiceFollowUp() {
        QuestionHaptic.play(.light)
        questionOverride = QuestionFollowUp.prompt(for: activeQuestion, category: selectedCategory)
        analysis = nil
        errorMessage = nil
        showsTypedAnswer = false
        typedAnswer = ""
        transcriptionSuggestions = []
        answerSession.reset()
    }

    private func nextQuestion() {
        QuestionHaptic.play(.light)
        guard questionIndex + 1 < questions.count else {
            dismiss()
            return
        }
        questionIndex += 1
        questionOverride = nil
        analysis = nil
        errorMessage = nil
        showsTypedAnswer = false
        typedAnswer = ""
        transcriptionSuggestions = []
        answerSession.reset()
    }
}

enum QuestionAnalysisCopy {
    static func headline(for score: Int) -> String {
        switch score {
        case 85...:
            return "Clear, credible answer — sharpen the impact"
        case 70...:
            return "Strong start — make the outcome clearer"
        default:
            return "A useful first pass — add stronger proof"
        }
    }

    static func subtitle(for analysis: InterviewAnalysisResult) -> String {
        if analysis.relevanceScore >= 80 {
            return "You stayed connected to the company and the question."
        }
        if analysis.communicationScore >= 70 {
            return "Your context came through clearly. Now make the evidence more specific."
        }
        return "Use a tighter example so the interviewer can follow your decision and impact."
    }

    static func items(from markdown: String) -> [String] {
        let items = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: .newlines)
            .map { line in
                line
                    .replacingOccurrences(of: #"^\s*[-*•]\s*"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "**", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        return items.isEmpty ? ["Keep the answer grounded in one concrete example."] : items
    }
}

enum QuestionCoachingHint {
    static func text(for category: PracticeCategory) -> String {
        switch category {
        case .behavioral:
            return "Give the context, the decision you made, and what changed. Use the structure that fits your story."
        case .technical:
            return "Explain your approach, the evidence you used, and one trade-off you considered."
        case .systemDesign:
            return "State your assumptions, make key trade-offs visible, and explain how you would validate the design."
        case .leadership:
            return "Show how you created alignment, made a judgment call, and helped the team move forward."
        }
    }
}

enum QuestionFollowUp {
    static func prompt(for question: String, category: PracticeCategory) -> String {
        switch category {
        case .behavioral:
            return "What would you do differently if you faced the same situation again?"
        case .technical:
            return "What evidence would make you change your technical decision?"
        case .systemDesign:
            return "Which trade-off would you revisit first if the system had ten times more traffic?"
        case .leadership:
            return "How would you know the team was truly aligned after your decision?"
        }
    }
}

// MARK: - Visual system

struct QuestionPracticeGrid: View {
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let spacing: CGFloat = 34
                var path = Path()
                for x in stride(from: 0, through: size.width, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: 0, through: size.height, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(Color.cvQuestionGrid), lineWidth: 1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Color.cvQuestionBackground)
        .ignoresSafeArea()
    }
}

struct QuestionPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(configuration.isPressed ? Color.cvStudioAccent.opacity(0.86) : Color.cvStudioAccent)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.cvStudioAccent.opacity(configuration.isPressed ? 0.08 : 0.18), radius: 9, x: 0, y: 4)
    }
}

struct QuestionSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.cvStudioAccent)
            .background(Color.cvStudioAccentSoft.opacity(0.72), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.cvStudioAccent.opacity(0.24), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.74 : 1)
    }
}

struct QuestionOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.cvStudioAccent)
            .background(Color.cvQuestionPaper.opacity(0.86), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.cvStudioAccent.opacity(0.58), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.74 : 1)
    }
}

enum QuestionHapticStyle {
    case light
    case medium
}

enum QuestionHaptic {
    static func play(_ style: QuestionHapticStyle) {
        #if os(iOS)
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = switch style {
        case .light: .light
        case .medium: .medium
        }
        cvImpactHaptic(feedbackStyle)
        #endif
    }
}

/// A pair of unobtrusive, app-owned audio cues makes the tap-to-record state
/// obvious without relying on private or device-specific system sound IDs.
/// The recording cue rises; the finish cue resolves downward.
private extension View {
    @ViewBuilder
    func questionNavigationChromeHidden() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}

private extension Color {
    static let cvQuestionBackground = Color(red: 0.969, green: 0.941, blue: 0.902) // #F7F0E6
    static let cvQuestionPaper = Color(red: 1.000, green: 0.980, blue: 0.945) // #FFFAF1
    static let cvQuestionCard = Color(red: 1.000, green: 0.979, blue: 0.941) // #FFF9F0
    static let cvQuestionInk = Color(red: 0.129, green: 0.106, blue: 0.086) // #211B16
    static let cvQuestionBody = Color(red: 0.400, green: 0.353, blue: 0.290) // #665A4A
    static let cvQuestionMuted = Color(red: 0.420, green: 0.447, blue: 0.514) // #6B7283
    static let cvQuestionBorder = Color(red: 0.894, green: 0.827, blue: 0.737) // #E4D3BC
    static let cvQuestionGrid = Color(red: 0.545, green: 0.353, blue: 0.086).opacity(0.075)
    static let cvQuestionShadow = Color(red: 0.545, green: 0.353, blue: 0.086).opacity(0.08)
    static let cvQuestionAmber = Color(red: 0.663, green: 0.475, blue: 0.208) // #A97935
    static let cvQuestionSoftLavender = Color(red: 0.875, green: 0.886, blue: 1.000) // #DFE2FF
    static let cvQuestionLavenderText = Color(red: 0.553, green: 0.533, blue: 0.902) // #8D88E6
    static let cvQuestionDashboardBlue = Color(red: 0.231, green: 0.510, blue: 0.965) // #3B82F6
    static let cvQuestionSuccess = Color(red: 0.082, green: 0.502, blue: 0.239) // #15803D
    static let cvQuestionRecordingFill = Color(red: 0.851, green: 0.949, blue: 0.886) // #D9F2E2
    static let cvQuestionRecordingText = Color(red: 0.086, green: 0.396, blue: 0.208) // #166534
    static let cvQuestionRecordingRing = Color(red: 0.984, green: 0.443, blue: 0.522) // #FB7185
    static let cvQuestionWarning = Color(red: 0.851, green: 0.467, blue: 0.024) // #D97706
    static let cvQuestionDanger = Color(red: 0.882, green: 0.114, blue: 0.282) // #E11D48
    static let cvQuestionDashboardRose = Color(red: 0.882, green: 0.114, blue: 0.282) // #E11D48
}
