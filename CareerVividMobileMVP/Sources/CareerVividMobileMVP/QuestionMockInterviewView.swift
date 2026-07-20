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
    private let personalizedContent: PersonalizedPracticeContent?
    private let skillTreeProgressID: String?
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
        guideSlug: String? = nil,
        personalizedContent: PersonalizedPracticeContent? = nil,
        skillTreeProgressID: String? = nil
    ) {
        _selectedJob = State(initialValue: initialJob)
        _selectedCategory = State(initialValue: initialCategory)
        _stageTitle = State(initialValue: initialStageTitle)
        self.guideSlug = guideSlug
        self.personalizedContent = personalizedContent
        self.skillTreeProgressID = skillTreeProgressID
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
                    personalizedSourceLabel: personalizedContent?.sourceLabel,
                    coachingHint: personalizedContent?.coachingHint,
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
        guard personalizedContent == nil else { return nil }
        return QuestionWebQuestStage.resolve(stageTitle: stageTitle, category: selectedCategory)
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
        if let personalizedContent {
            questions = personalizedContent.questions
            officialSourceURL = ""
            questionIndex = 0
            questionLoadError = nil
            errorMessage = nil
            isLoadingQuestions = false
            return
        }

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
            questionIndex = CompanyQuestProgressStore.nextQuestionIndex(
                company: selectedJob.company,
                stageTitle: stageTitle,
                questionCount: officialQuestions.count
            )
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
                LocalInterviewReportCache.save(
                    result: result,
                    config: config,
                    stageTitle: stageTitle,
                    completedQuestionIndex: questionIndex,
                    questionCount: questions.count
                )
                if let skillTreeProgressID {
                    SkillTreeChallengeProgressStore.record(id: skillTreeProgressID, score: result.overallScore)
                }
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
            return "Impressive answer — ready for the real thing"
        case 70...:
            return "Strong start — make the outcome clearer"
        case 55...:
            return "A useful first pass — add stronger proof"
        default:
            return "Keep going — practice builds confidence"
        }
    }

    static func subtitle(for analysis: InterviewAnalysisResult) -> String {
        if let exp = analysis.experienceScore, exp >= 75 {
            return "You shared strong examples with real impact."
        }
        if analysis.relevanceScore >= 75 {
            return "You stayed connected to the company and the question."
        }
        if analysis.communicationScore >= 65 {
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
        Color.cvAppBackground.ignoresSafeArea()
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


