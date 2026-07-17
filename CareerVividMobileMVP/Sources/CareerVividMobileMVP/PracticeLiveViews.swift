import SwiftUI

struct LivePracticeScreen: View {
    @ObservedObject var session: LiveInterviewSession
    let config: InterviewLiveConfig
    let isAnalyzing: Bool
    let errorMessage: String?
    let onDoneAnswering: () -> Void
    let onEndInterview: () -> Void
    let onFeedback: () -> Void
    let onRetry: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            LivePracticeHeader(
                state: session.state,
                progressText: session.progressText,
                onClose: onClose
            )
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        LiveRoleContext(config: config)

                        if session.messages.isEmpty {
                            LiveInterviewPlaceholder(state: session.state)
                        } else {
                            ForEach(session.messages) { message in
                                InterviewMessageBubble(message: message)
                                    .id(message.id)
                            }
                        }

                        if let visibleErrorMessage {
                            PracticeErrorBanner(message: visibleErrorMessage)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 10)
                }
                .onChange(of: session.messages) { _, messages in
                    guard let last = messages.last else { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            LivePracticeFooter(
                state: session.state,
                canFinishAnswer: session.canFinishAnswer,
                canRequestFeedback: session.canRequestFeedback,
                isAnalyzing: isAnalyzing,
                onDoneAnswering: onDoneAnswering,
                onEndInterview: onEndInterview,
                onFeedback: onFeedback,
                onRetry: onRetry,
                onClose: onClose
            )
        }
        .overlay {
            if isAnalyzing {
                InterviewProcessingOverlay()
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isAnalyzing)
    }

    private var visibleErrorMessage: String? {
        if case .failed(let message) = session.state {
            return message
        }
        return errorMessage
    }
}

private struct LivePracticeHeader: View {
    let state: LiveInterviewSessionState
    let progressText: String
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Label(statusText, systemImage: statusIcon)
                .font(.caption.weight(.black))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())

            Spacer()

            Text(progressText)
                .font(.caption.weight(.black))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.cvSecondarySystemBackground)
                .clipShape(Capsule())

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .frame(width: 38, height: 38)
                    .background(Color.cvSecondarySystemBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var statusText: String {
        switch state {
        case .idle: return "Ready"
        case .connecting: return "Connecting"
        case .interviewerSpeaking: return "Vivid speaking"
        case .listening: return "Listening"
        case .ended: return "Ready for report"
        case .failed: return "Needs retry"
        }
    }

    private var statusIcon: String {
        switch state {
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .interviewerSpeaking: return "sparkles"
        case .listening: return "mic.fill"
        case .ended: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .idle: return "circle"
        }
    }

    private var statusColor: Color {
        switch state {
        case .failed: return .orange
        case .listening: return .green
        case .ended: return Color.cvBrand
        default: return Color.cvBrand
        }
    }
}

private struct LiveRoleContext: View {
    let config: InterviewLiveConfig

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: config.category.icon)
                .foregroundStyle(Color.cvBrand)
                .frame(width: 36, height: 36)
                .background(Color.cvBrandSoft)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(config.job.title)
                    .font(.subheadline.weight(.bold))
                Text("\(config.job.company) - \(config.category.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .cvCard(padding: 14)
    }
}

private struct LiveInterviewPlaceholder: View {
    let state: LiveInterviewSessionState

    var body: some View {
        VStack(spacing: 14) {
            if isFailed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.orange)
            } else {
                AgentActivityOrb(
                    systemImage: "sparkles",
                    tint: Color.cvBrand,
                    size: 74
                )
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !isFailed {
                InterviewPreparationSteps()
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .cvCard(padding: 18, radius: 24, raised: true)
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }

    private var title: String {
        isFailed ? "The live interview could not start." : "Vivid is preparing your interview."
    }

    private var subtitle: String {
        isFailed ? "Check the message below, then retry after the service is available." : "Building role context and opening the mic after Vivid speaks."
    }
}

private struct InterviewPreparationSteps: View {
    private let steps = [
        PreparationStep(title: "Role context", systemImage: "checkmark.circle.fill"),
        PreparationStep(title: "Live voice", systemImage: "waveform"),
        PreparationStep(title: "Transcript", systemImage: "text.bubble.fill")
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(steps) { step in
                Label(step.title, systemImage: step.systemImage)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.cvBrand)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.cvBrandSoft.opacity(0.9))
                    .clipShape(Capsule())
            }
        }
    }
}

private struct PreparationStep: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
}

private struct InterviewProcessingOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                AgentActivityOrb(
                    systemImage: "chart.bar.fill",
                    tint: Color.cvBrand,
                    size: 92
                )

                VStack(spacing: 6) {
                    Text("Building your feedback report")
                        .font(.headline.weight(.black))
                    Text("CareerVivid is reviewing the transcript, scoring your answers, and saving the practice history.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    ProcessingStepPill(title: "Transcript", systemImage: "text.bubble.fill")
                    ProcessingStepPill(title: "Scoring", systemImage: "speedometer")
                    ProcessingStepPill(title: "Report", systemImage: "doc.text.fill")
                }
            }
            .padding(22)
            .frame(maxWidth: 330)
            .background(Color.cvSurface.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 22, x: 0, y: 12)
            .padding(.horizontal, 28)
        }
    }
}

private struct ProcessingStepPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.cvBrand)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.cvBrandSoft)
            .clipShape(Capsule())
    }
}

private struct AgentActivityOrb: View {
    let systemImage: String
    let tint: Color
    var size: CGFloat
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.14), lineWidth: 1)
                .frame(width: size * 1.45, height: size * 1.45)
                .scaleEffect(isAnimating ? 1.08 : 0.92)
                .opacity(isAnimating ? 0.2 : 0.55)

            Circle()
                .fill(tint.opacity(0.11))
                .frame(width: size * 1.08, height: size * 1.08)
                .scaleEffect(isAnimating ? 1.04 : 0.88)

            Circle()
                .trim(from: 0.12, to: 0.82)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))

            Image(systemName: systemImage)
                .font(.system(size: size * 0.28, weight: .black))
                .foregroundStyle(tint)
                .scaleEffect(isAnimating ? 1.06 : 0.94)
        }
        .frame(width: size * 1.5, height: size * 1.5)
        .onAppear {
            withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
        .accessibilityHidden(true)
    }
}

private struct InterviewMessageBubble: View {
    let message: InterviewLiveMessage

    var body: some View {
        HStack(alignment: .bottom) {
            if message.speaker == .user { Spacer(minLength: 44) }

            VStack(alignment: .leading, spacing: 6) {
                Label(message.speaker.displayName, systemImage: message.speaker == .user ? "person.fill" : "wand.and.stars")
                    .font(.caption.weight(.black))
                    .foregroundStyle(message.speaker == .user ? .white.opacity(0.85) : .secondary)
                Text(message.text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(message.speaker == .user ? .white : .primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(message.speaker == .user ? Color.cvBrand : Color.cvSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(message.speaker == .user ? 0.10 : 0.055), radius: 14, x: 0, y: 7)
            .overlay(alignment: .topTrailing) {
                if message.isLive {
                    Text("Live")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(message.speaker == .user ? Color.cvBrand : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.white.opacity(message.speaker == .user ? 0.9 : 0.65))
                        .clipShape(Capsule())
                        .offset(x: 8, y: -8)
                }
            }
            .frame(maxWidth: 280, alignment: message.speaker == .user ? .trailing : .leading)

            if message.speaker == .interviewer { Spacer(minLength: 44) }
        }
    }
}

private struct LivePracticeFooter: View {
    let state: LiveInterviewSessionState
    let canFinishAnswer: Bool
    let canRequestFeedback: Bool
    let isAnalyzing: Bool
    let onDoneAnswering: () -> Void
    let onEndInterview: () -> Void
    let onFeedback: () -> Void
    let onRetry: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                StepStatusRow(
                    title: "Live transcript",
                    subtitle: "Your answers appear as text",
                    isDone: hasTranscriptStarted
                )
                StepStatusRow(
                    title: canRequestFeedback ? "Create report" : "Feedback report",
                    subtitle: canRequestFeedback ? "Tap Get feedback to save this attempt" : "Saved after analysis",
                    isDone: false
                )
            }

            HStack(spacing: 12) {
                Button(role: canEndInterview ? .destructive : nil, action: secondaryAction) {
                    Label(secondaryTitle, systemImage: secondarySystemImage)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(secondaryForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: primaryAction) {
                    primaryLabel
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .cvPrimaryActionButton()
                .disabled(primaryDisabled)
                .opacity(primaryDisabled ? 0.48 : 1)
            }
        }
        .padding(16)
        .padding(.bottom, max(CVLayout.floatingTabContentPadding - 28, 64))
        .background(.ultraThinMaterial)
    }

    private var hasTranscriptStarted: Bool {
        switch state {
        case .listening, .ended: return true
        default: return false
        }
    }

    private var canEndInterview: Bool {
        switch state {
        case .connecting, .interviewerSpeaking, .listening:
            return !isAnalyzing
        case .idle, .ended, .failed:
            return false
        }
    }

    private var secondaryTitle: String {
        canEndInterview ? "End" : "Close"
    }

    private var secondarySystemImage: String {
        canEndInterview ? "stop.circle.fill" : "xmark.circle.fill"
    }

    private var secondaryForeground: Color {
        canEndInterview ? .red : .secondary
    }

    private var secondaryBackground: Color {
        canEndInterview ? Color.red.opacity(0.12) : Color.cvSecondarySystemBackground
    }

    private var primaryLabel: some View {
        Group {
            if isAnalyzing {
                Label("Analyzing", systemImage: "sparkles")
            } else if isFailed {
                Label("Retry", systemImage: "arrow.clockwise")
            } else if canRequestFeedback {
                Label("Get feedback", systemImage: "chart.bar.fill")
            } else if canFinishAnswer {
                Label("Done answering", systemImage: "checkmark")
            } else {
                Label(holdingText, systemImage: "mic.fill")
            }
        }
    }

    private var holdingText: String {
        switch state {
        case .connecting: return "Connecting"
        case .interviewerSpeaking: return "Vivid speaking"
        default: return "Listening soon"
        }
    }

    private var primaryDisabled: Bool {
        isAnalyzing || (!isFailed && !canFinishAnswer && !canRequestFeedback)
    }

    private func primaryAction() {
        if isFailed {
            onRetry()
        } else if canRequestFeedback {
            onFeedback()
        } else if canFinishAnswer {
            onDoneAnswering()
        }
    }

    private func secondaryAction() {
        if canEndInterview {
            onEndInterview()
        } else {
            onClose()
        }
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }
}

private struct StepStatusRow: View {
    let title: String
    let subtitle: String
    let isDone: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.subheadline)
                .foregroundStyle(isDone ? .green : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.bold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.cvSecondarySystemBackground.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Report Screen

