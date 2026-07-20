import SwiftUI

struct QuestionAnalysisScreen: View {
    let company: String
    let category: PracticeCategory
    let stageTitle: String?
    let question: String
    let analysis: InterviewAnalysisResult
    let elapsedSeconds: Int
    let onBack: () -> Void
    let onPracticeAgain: () -> Void
    let onPracticeFollowUp: () -> Void
    let onNextQuestion: () -> Void
    var backLabel: String = "Back to stages"
    var showsActions: Bool = true
    var showsFullTranscript: Bool = false

    private var strengths: [String] {
        QuestionAnalysisCopy.items(from: analysis.strengths)
    }

    private var improvements: [String] {
        QuestionAnalysisCopy.items(from: analysis.areasForImprovement)
    }

    private var candidateAnswer: String {
        analysis.transcript.last(where: { $0.speaker == .user })?.text ?? "Your answer was received."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button(action: onBack) {
                        Label(backLabel, systemImage: "chevron.left")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.cvQuestionMuted)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text("Interview report")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.cvStudioAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.cvStudioAccentSoft, in: Capsule())
                }

                QuestionReportSummaryCard(
                    score: analysis.overallScore,
                    company: company,
                    stageTitle: stageTitle ?? category.rawValue,
                    elapsed: timeString,
                    headline: QuestionAnalysisCopy.headline(for: analysis.overallScore),
                    subtitle: QuestionAnalysisCopy.subtitle(for: analysis)
                )

                Text("Metric breakdown")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.cvQuestionInk)

                VStack(spacing: 10) {
                    if analysis.hasV2Scores {
                        QuestionReportMetricCard(
                            title: "Communication",
                            detail: "Clarity, structure, and articulation",
                            score: analysis.communicationScore,
                            symbol: "text.alignleft"
                        )
                        QuestionReportMetricCard(
                            title: "Problem solving",
                            detail: "Analytical thinking and structured approach",
                            score: analysis.problemSolvingScore ?? analysis.confidenceScore,
                            symbol: "lightbulb"
                        )
                        QuestionReportMetricCard(
                            title: "Experience & impact",
                            detail: "Relevant examples with concrete outcomes",
                            score: analysis.experienceScore ?? analysis.relevanceScore,
                            symbol: "star"
                        )
                        QuestionReportMetricCard(
                            title: "Role alignment",
                            detail: "Connection to the target role",
                            score: analysis.roleAlignmentScore ?? analysis.relevanceScore,
                            symbol: "scope"
                        )
                        if let leadershipScore = analysis.leadershipScore {
                            QuestionReportMetricCard(
                                title: "Leadership",
                                detail: "People management and collaboration",
                                score: leadershipScore,
                                symbol: "person.3"
                            )
                        }
                    } else {
                        QuestionReportMetricCard(
                            title: "Communication",
                            detail: "Clarity, structure, and pacing",
                            score: analysis.communicationScore,
                            symbol: "text.alignleft"
                        )
                        QuestionReportMetricCard(
                            title: "Confidence",
                            detail: "Presence and specificity",
                            score: analysis.confidenceScore,
                            symbol: "waveform"
                        )
                        QuestionReportMetricCard(
                            title: "Answer relevance",
                            detail: "Connection to this question",
                            score: analysis.relevanceScore,
                            symbol: "scope"
                        )
                    }
                }

                if let skills = analysis.skills, !skills.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Demonstrated skills")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.cvQuestionInk)
                            .padding(.top, 4)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(skills, id: \.self) { skill in
                                    Text(skill)
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.cvStudioAccentSoft, in: Capsule())
                                        .foregroundStyle(Color.cvStudioAccent)
                                }
                            }
                        }
                    }
                }

                QuestionReportInsightCard(
                    title: "What went well",
                    subtitle: "Keep these strengths in your next answer.",
                    symbol: "checkmark.circle.fill",
                    tint: Color.cvQuestionSuccess,
                    background: Color.cvQuestionSuccess.opacity(0.08),
                    border: Color.cvQuestionSuccess.opacity(0.22),
                    items: strengths
                )

                QuestionReportInsightCard(
                    title: "Practice next",
                    subtitle: "Use this on your next attempt.",
                    symbol: "target",
                    tint: Color.cvQuestionWarning,
                    background: Color.cvQuestionWarning.opacity(0.08),
                    border: Color.cvQuestionWarning.opacity(0.25),
                    items: improvements
                )

                QuestionAnalysisQuestionCard(question: question)
                QuestionTranscriptCard(answer: candidateAnswer, showsFullTranscript: showsFullTranscript)

                if showsActions {
                    QuestionFollowUpCard(
                        prompt: QuestionFollowUp.prompt(for: question, category: category),
                        onPractice: onPracticeFollowUp
                    )

                    Button(action: onPracticeAgain) {
                        Label("Practice this answer again", systemImage: "arrow.clockwise")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(QuestionPrimaryButtonStyle())

                    Button(action: onNextQuestion) {
                        Label("Next question", systemImage: "arrow.right")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .buttonStyle(QuestionOutlineButtonStyle())
                }

                Text("Feedback tailored to \(company) and this question.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.cvQuestionMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, CVLayout.floatingTabContentPadding)
            }
            .padding(20)
        }
    }

    private var timeString: String {
        String(format: "%d:%02d response", elapsedSeconds / 60, elapsedSeconds % 60)
    }
}

struct QuestionReportGeneratingScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let company: String
    let category: PracticeCategory
    let stageTitle: String?
    let answer: String
    let elapsedSeconds: Int

    @State private var activeStep = 0
    @State private var completedThrough = -1
    @State private var hasStartedProgress = false

    private var theme: QuestionReportGenerationTheme {
        QuestionReportGenerationTheme.resolve(stageTitle: stageTitle, category: category)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Creating your report")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.cvQuestionInk)
                    Text("\(company) · \(stageTitle ?? "Mock interview")")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.cvQuestionMuted)
                }
                Spacer()
                Text(timeString)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(Color.cvQuestionBody)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.cvQuestionPaper, in: Capsule())
            }
            .padding(20)

            Spacer(minLength: 20)

            VStack(spacing: 22) {
                QuestionReportAnalysisActivityControl(
                    symbol: theme.symbol,
                    accessibilityLabel: theme.accessibilityLabel
                )

                VStack(spacing: 7) {
                    Text(theme.headline)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.cvQuestionInk)
                    Text(theme.supportingText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.cvQuestionBody)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .background(Color.cvQuestionPaper.opacity(0.88), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.cvQuestionBorder.opacity(0.82), lineWidth: 1)
            )
            .padding(.horizontal, 20)

            Spacer(minLength: 24)

            VStack(spacing: 10) {
                ForEach(Array(theme.steps.enumerated()), id: \.offset) { index, step in
                    QuestionReportGenerationStepRow(
                        title: step.0,
                        subtitle: step.1,
                        state: stepState(for: index),
                        reduceMotion: reduceMotion
                    )
                }
            }
            .padding(20)

            if !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Report is based on your response.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.cvQuestionMuted)
                    .padding(.bottom, CVLayout.floatingTabContentPadding)
            }
        }
        .task {
            guard !hasStartedProgress else { return }
            hasStartedProgress = true

            guard !reduceMotion else { return }
            // Complete each row first, then move forward. This is deliberately
            // monotonic: a checked item never returns to the pending state.
            for step in 0..<(theme.steps.count - 1) {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.snappy(duration: 0.32, extraBounce: 0.06)) {
                    completedThrough = step
                }
                try? await Task.sleep(nanoseconds: 320_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.smooth(duration: 0.34)) {
                    activeStep = step + 1
                }
            }
        }
    }

    private func stepState(for index: Int) -> QuestionReportGenerationStepState {
        if index <= completedThrough { return .complete }
        if index == activeStep { return .active }
        return .waiting
    }

    private var timeString: String {
        String(format: "%d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }
}

private enum QuestionReportGenerationStepState: Equatable {
    case waiting
    case active
    case complete
}

private struct QuestionReportAnalysisActivityControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let symbol: String
    let accessibilityLabel: String

    private let arcColors: [Color] = [
        .cvStudioAccent,
        .cvQuestionDashboardBlue,
        .cvQuestionSuccess,
        .cvQuestionAmber
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let pulse = reduceMotion ? 0 : (sin(time * 3.1) + 1) / 2

            ZStack {
                Circle()
                    .fill(Color.cvStudioAccentSoft.opacity(0.58))
                    .frame(width: 150, height: 150)
                    .scaleEffect(1 + pulse * 0.035)

                ForEach(0..<arcColors.count, id: \.self) { index in
                    Circle()
                        .trim(from: 0.04, to: 0.19 + Double(index) * 0.025)
                        .stroke(
                            arcColors[index].opacity(index == 0 ? 0.92 : 0.72),
                            style: StrokeStyle(lineWidth: index == 0 ? 9 : 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(
                            Double(index) * 90 + time * (index.isMultiple(of: 2) ? 82 : -64)
                        ))
                }

                Circle()
                    .fill(Color.cvStudioAccentSoft)
                    .frame(width: 122, height: 122)
                    .overlay(
                        Circle()
                            .stroke(Color.cvQuestionSoftLavender.opacity(0.92), lineWidth: 1)
                    )

                VStack(spacing: 8) {
                    Image(systemName: symbol)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.cvStudioAccent)
                        .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)

                    Text("Analyzing")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.cvStudioAccent)

                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(arcColors[index])
                                .frame(width: 5, height: 5)
                                .offset(y: reduceMotion ? 0 : -3 * sin(time * 5 + Double(index) * 0.9))
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .frame(width: 172, height: 172)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct QuestionReportGenerationStepRow: View {
    let title: String
    let subtitle: String
    let state: QuestionReportGenerationStepState
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 12) {
            indicator
                .frame(width: 29, height: 29)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(state == .waiting ? Color.cvQuestionMuted : Color.cvQuestionInk)
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.cvQuestionMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(border, lineWidth: 1)
        )
        .animation(.smooth(duration: 0.32), value: state)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(accessibilityStatus)")
    }

    @ViewBuilder
    private var indicator: some View {
        switch state {
        case .complete:
            if reduceMotion {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.cvQuestionSuccess)
                    .background(Color.cvQuestionSuccess.opacity(0.11), in: Circle())
            } else {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.cvQuestionSuccess)
                    .background(Color.cvQuestionSuccess.opacity(0.11), in: Circle())
                    .symbolEffect(.bounce.down, value: state)
            }
        case .active:
            QuestionReportActivityGlyph(reduceMotion: reduceMotion)
                .background(Color.cvQuestionSoftLavender.opacity(0.58), in: Circle())
        case .waiting:
            Circle()
                .stroke(Color.cvQuestionMuted.opacity(0.30), lineWidth: 2)
                .padding(8)
        }
    }

    private var background: Color {
        switch state {
        case .complete: return Color.cvQuestionCard.opacity(0.88)
        case .active: return Color.cvQuestionCard
        case .waiting: return Color.cvQuestionCard.opacity(0.58)
        }
    }

    private var border: Color {
        switch state {
        case .complete: return Color.cvQuestionSuccess.opacity(0.20)
        case .active: return Color.cvQuestionSoftLavender
        case .waiting: return Color.cvQuestionBorder.opacity(0.80)
        }
    }

    private var accessibilityStatus: String {
        switch state {
        case .complete: return "complete"
        case .active: return "in progress"
        case .waiting: return "waiting"
        }
    }
}

private struct QuestionReportActivityGlyph: View {
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    let progress = reduceMotion ? 0.5 : (elapsed + Double(index) * 0.14)
                        .truncatingRemainder(dividingBy: 0.72) / 0.72
                    Circle()
                        .fill(Color.cvQuestionLavenderText)
                        .frame(width: 4.5, height: 4.5)
                        .opacity(0.35 + (1 - abs(progress * 2 - 1)) * 0.65)
                        .offset(y: -2 + (1 - abs(progress * 2 - 1)) * 4)
                }
            }
        }
    }
}

/// A report should feel specific to the interview stage being evaluated. These
/// themes keep the warm, restrained visual system while making the in-flight
/// analysis legible: the icon, motion, and reasoning sequence match the kind
/// of answer the candidate just gave.
private enum QuestionReportGenerationTheme {
    case recruiterScreen
    case coding
    case systemDesign
    case values
    case behavioral
    case finalRound

    static func resolve(stageTitle: String?, category: PracticeCategory) -> Self {
        let stage = stageTitle?.lowercased() ?? ""
        if stage.contains("recruit") || stage.contains("screen") { return .recruiterScreen }
        if stage.contains("cod") { return .coding }
        if stage.contains("system") { return .systemDesign }
        if stage.contains("value") { return .values }
        if stage.contains("final") || stage.contains("hiring") { return .finalRound }
        if stage.contains("behavior") { return .behavioral }

        switch category {
        case .technical: return .coding
        case .systemDesign: return .systemDesign
        case .leadership: return .values
        case .behavioral: return .behavioral
        }
    }

    var symbol: String {
        switch self {
        case .recruiterScreen: return "person.wave.2"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .systemDesign: return "rectangle.3.group"
        case .values: return "scale.3d"
        case .behavioral: return "person.2.fill"
        case .finalRound: return "flag.checkered"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .recruiterScreen: return "Analyzing recruiter-screen answer"
        case .coding: return "Analyzing coding answer"
        case .systemDesign: return "Analyzing system-design answer"
        case .values: return "Analyzing values answer"
        case .behavioral: return "Analyzing behavioral answer"
        case .finalRound: return "Analyzing final-round answer"
        }
    }

    var headline: String {
        switch self {
        case .recruiterScreen: return "Reviewing your recruiter-screen answer"
        case .coding: return "Reviewing your coding approach"
        case .systemDesign: return "Reviewing your system design"
        case .values: return "Reviewing your judgment and values"
        case .behavioral: return "Reviewing your behavioral story"
        case .finalRound: return "Reviewing your final-round answer"
        }
    }

    var supportingText: String {
        switch self {
        case .recruiterScreen: return "Checking role motivation, clarity, and first-impression signals."
        case .coding: return "Checking your approach, trade-offs, and how you reasoned through the problem."
        case .systemDesign: return "Checking your architecture, constraints, and the trade-offs you made."
        case .values: return "Checking the principles and judgment behind your decisions."
        case .behavioral: return "Checking how clearly your story shows ownership, actions, and impact."
        case .finalRound: return "Checking your judgment, communication, and fit for the full interview loop."
        }
    }

    var steps: [(String, String)] {
        switch self {
        case .recruiterScreen:
            return [
                ("Reading your introduction", "Checking clarity and role motivation"),
                ("Finding your fit signals", "Looking for relevant experience and intent"),
                ("Building your screen report", "Organizing the strongest next steps")
            ]
        case .coding:
            return [
                ("Tracing your approach", "Following how you broke down the problem"),
                ("Checking technical trade-offs", "Reviewing complexity, edge cases, and validation"),
                ("Building your coding report", "Organizing specific improvements for your next solution")
            ]
        case .systemDesign:
            return [
                ("Mapping your architecture", "Reading the system components and requirements"),
                ("Checking scale trade-offs", "Reviewing reliability, latency, and cost decisions"),
                ("Building your design report", "Organizing the next design decisions to practice")
            ]
        case .values:
            return [
                ("Reading your judgment", "Checking the principles behind your decision"),
                ("Finding your evidence", "Looking for ownership, integrity, and concrete impact"),
                ("Building your values report", "Organizing clear next steps for you")
            ]
        case .behavioral:
            return [
                ("Reading your story", "Checking context, actions, and outcomes"),
                ("Finding your evidence", "Looking for ownership, impact, and trade-offs"),
                ("Building your behavioral report", "Organizing clear next steps for you")
            ]
        case .finalRound:
            return [
                ("Reviewing your full answer", "Checking clarity, judgment, and role fit"),
                ("Finding your strongest signals", "Looking for impact, questions, and decision quality"),
                ("Building your final-round report", "Organizing the final points to sharpen")
            ]
        }
    }

    func ringRotation(for isAnimating: Bool) -> Double {
        guard isAnimating else { return 0 }
        switch self {
        case .coding: return 360
        case .systemDesign: return -360
        case .finalRound: return 180
        case .recruiterScreen, .values, .behavioral: return 0
        }
    }

    func iconScale(for isAnimating: Bool) -> CGFloat {
        guard isAnimating else { return 0.94 }
        switch self {
        case .values, .finalRound: return 1.1
        case .recruiterScreen, .coding, .systemDesign, .behavioral: return 1
        }
    }

    func iconOffsetY(for isAnimating: Bool) -> CGFloat {
        guard isAnimating else { return 0 }
        switch self {
        case .recruiterScreen: return -4
        case .behavioral: return 4
        case .coding, .systemDesign, .values, .finalRound: return 0
        }
    }

    func iconRotation(for isAnimating: Bool) -> Double {
        guard isAnimating else { return 0 }
        switch self {
        case .systemDesign: return 7
        case .finalRound: return -4
        case .recruiterScreen, .coding, .values, .behavioral: return 0
        }
    }

    var ringAnimation: Animation {
        switch self {
        case .coding: return .linear(duration: 1.05).repeatForever(autoreverses: false)
        case .systemDesign: return .linear(duration: 1.6).repeatForever(autoreverses: false)
        case .finalRound: return .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
        case .recruiterScreen, .values, .behavioral: return .default
        }
    }

    var iconAnimation: Animation {
        switch self {
        case .recruiterScreen, .behavioral: return .easeInOut(duration: 0.82).repeatForever(autoreverses: true)
        case .values: return .easeInOut(duration: 0.92).repeatForever(autoreverses: true)
        case .systemDesign: return .easeInOut(duration: 1.15).repeatForever(autoreverses: true)
        case .finalRound: return .easeInOut(duration: 1.05).repeatForever(autoreverses: true)
        case .coding: return .linear(duration: 1.05).repeatForever(autoreverses: false)
        }
    }
}

private struct QuestionReportSummaryCard: View {
    let score: Int
    let company: String
    let stageTitle: String
    let elapsed: String
    let headline: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            QuestionReportScoreRing(score: score)
            VStack(alignment: .leading, spacing: 6) {
                Text("Priority focus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.cvStudioAccent)
                Text(headline)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.cvQuestionInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.cvQuestionBody)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text("\(company) · \(stageTitle)")
                    Text("•")
                    Text(elapsed)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.cvQuestionMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.cvQuestionCard.opacity(0.97), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.cvQuestionBorder, lineWidth: 1))
    }
}

private struct QuestionReportScoreRing: View {
    let score: Int
    @State private var displayedScore = 0

    private var tint: Color {
        switch score {
        case 75...: return Color.cvQuestionSuccess
        case 55...: return Color.cvQuestionWarning
        default: return Color.cvQuestionDanger
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.13), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(displayedScore) / 100)
                .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(displayedScore)")
                    .font(.title2.monospacedDigit().weight(.bold))
                    .foregroundStyle(tint)
                Text("OVERALL")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Color.cvQuestionMuted)
            }
        }
        .frame(width: 82, height: 82)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                displayedScore = max(0, min(score, 100))
            }
        }
    }
}

private struct QuestionReportMetricCard: View {
    let title: String
    let detail: String
    let score: Int
    let symbol: String
    @State private var fill = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.cvStudioAccent)
                    .frame(width: 28, height: 28)
                    .background(Color.cvStudioAccentSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.cvQuestionInk)
                    Text(detail)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.cvQuestionMuted)
                }
                Spacer()
                Text("\(score)%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.cvStudioAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.cvStudioAccentSoft, in: Capsule())
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.cvStudioAccentSoft)
                    Capsule()
                        .fill(Color.cvStudioAccent)
                        .frame(width: proxy.size.width * min(max(fill, 0), 1))
                }
            }
            .frame(height: 7)
        }
        .padding(14)
        .background(Color.cvQuestionCard.opacity(0.97), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.cvQuestionBorder, lineWidth: 1))
        .onAppear {
            withAnimation(.easeOut(duration: 0.65).delay(0.12)) {
                fill = Double(max(0, min(score, 100))) / 100
            }
        }
    }
}

private struct QuestionReportInsightCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let background: Color
    let border: Color
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.cvQuestionInk)
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.cvQuestionBody)
                }
            }
            ForEach(Array(items.prefix(3).enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(tint).frame(width: 5, height: 5).padding(.top, 6)
                    Text(item)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.cvQuestionBody)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(border, lineWidth: 1))
    }
}

private struct QuestionAnalysisQuestionCard: View {
    let question: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR QUESTION")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Color.cvQuestionAmber)
            Text(question)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.cvQuestionInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.cvQuestionCard.opacity(0.97), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.cvQuestionBorder, lineWidth: 1))
    }
}

private struct QuestionTranscriptCard: View {
    let answer: String
    var showsFullTranscript: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Your response", systemImage: "text.bubble")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.cvQuestionInk)
            Text(answer)
                .font(.subheadline)
                .foregroundStyle(Color.cvQuestionBody)
                .lineLimit(showsFullTranscript ? nil : 5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.cvQuestionCard.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.cvQuestionBorder, lineWidth: 1))
    }
}

private struct QuestionFeedbackCard: View {
    let score: Int
    let headline: String
    let subtitle: String
    let strengths: [String]
    let improvements: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(headline)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.cvQuestionInk)
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.cvQuestionBody)
                }
                Spacer(minLength: 8)
                Text("\(score)")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.cvStudioAccent)
                    .frame(width: 72, height: 72)
                    .background(Color.cvStudioAccentSoft, in: Circle())
                    .overlay(Circle().stroke(Color.cvStudioAccent, lineWidth: 1.5))
            }

            if let firstStrength = strengths.first {
                QuestionFeedbackRow(
                    icon: "checkmark",
                    tint: Color.cvQuestionSuccess,
                    text: firstStrength
                )
            }

            ForEach(Array(improvements.prefix(2).enumerated()), id: \.offset) { index, improvement in
                QuestionFeedbackRow(
                    icon: index == 0 ? "lightbulb" : "sparkles",
                    tint: index == 0 ? Color.cvQuestionWarning : Color.cvStudioAccent,
                    text: improvement
                )
            }
        }
        .padding(18)
        .background(Color.cvQuestionCard.opacity(0.97), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.cvQuestionBorder, lineWidth: 1))
    }
}

private struct QuestionFeedbackRow: View {
    let icon: String
    let tint: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.10), in: Circle())
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.cvQuestionBody)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

private struct QuestionFollowUpCard: View {
    let prompt: String
    let onPractice: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("TRY THIS FOLLOW-UP")
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(Color.cvStudioAccent)
            Text(prompt)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.cvQuestionBody)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onPractice) {
                Label("Practice follow-up", systemImage: "arrow.turn.down.right")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
            }
            .buttonStyle(QuestionOutlineButtonStyle())
        }
        .padding(16)
        .background(Color.cvStudioAccentSoft.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.cvStudioAccent.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Recording


private extension Color {
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
