import SwiftUI

struct QuestionAnswerScreen: View {
    let company: String
    let category: PracticeCategory
    let stageTitle: String?
    let questionNumber: Int
    let questionCount: Int
    let question: String
    let officialSourceURL: String
    @ObservedObject var session: TimedAnswerSession
    let isAnalyzing: Bool
    let isVividTranscribing: Bool
    let errorMessage: String?
    let transcriptionSuggestions: [String]
    @Binding var showsTypedAnswer: Bool
    @Binding var typedAnswer: String
    let onBack: () -> Void
    let onRecordAction: () -> Void
    let onAnalyzeTypedAnswer: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                QuestionTopBar(
                    company: company,
                    category: category,
                    stageTitle: stageTitle,
                    questionNumber: questionNumber,
                    questionCount: questionCount,
                    onBack: onBack
                )

                QuestionPromptCard(
                    category: category,
                    question: question,
                    helperText: QuestionCoachingHint.text(for: category)
                )

                if let sourceURL = URL(string: officialSourceURL), !officialSourceURL.isEmpty {
                    Link(destination: sourceURL) {
                        Label("Official company guide", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.cvStudioAccent)
                    }
                    .accessibilityHint("Opens the source guide used by the web and mobile question catalog")
                }

                Button {
                    showsTypedAnswer.toggle()
                } label: {
                    Label(
                        showsTypedAnswer ? "Record an answer" : "Type an answer instead",
                        systemImage: showsTypedAnswer ? "mic.fill" : "keyboard"
                    )
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(QuestionSecondaryButtonStyle())
                .disabled(session.state == .preparing || session.state == .recording || session.state == .transcribing || isAnalyzing || isVividTranscribing)

                if showsTypedAnswer {
                    TypedAnswerCard(answer: $typedAnswer)
                } else {
                    VoiceAnswerCard(
                        session: session,
                        isAnalyzing: isAnalyzing,
                        isVividTranscribing: isVividTranscribing,
                        coachingSuggestions: transcriptionSuggestions,
                        answerDraft: $typedAnswer,
                        onRecordAction: onRecordAction,
                        onSendAction: onAnalyzeTypedAnswer
                    )
                }

                if let errorMessage {
                    QuestionErrorCard(message: errorMessage)
                }

                Color.clear
                    .frame(height: CVLayout.floatingTabContentPadding + 24)
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsTypedAnswer {
                Button(action: onAnalyzeTypedAnswer) {
                    Label("Analyze this answer", systemImage: "sparkles")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(QuestionPrimaryButtonStyle())
                .disabled(isAnalyzing || isVividTranscribing)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 78)
                .background(.ultraThinMaterial)
            }
        }
    }
}

private struct QuestionTopBar: View {
    let company: String
    let category: PracticeCategory
    let stageTitle: String?
    let questionNumber: Int
    let questionCount: Int
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .frame(width: 42, height: 42)
                        .background(Color.cvQuestionPaper, in: Circle())
                        .overlay(Circle().stroke(Color.cvQuestionBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to interview stages")

                Spacer()

                VStack(spacing: 2) {
                    Text("\(company) · \(stageTitle ?? category.rawValue)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.cvQuestionInk)
                        .lineLimit(1)
                    Text("Question \(questionNumber) of \(questionCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.cvQuestionMuted)
                }

                Spacer()
                Color.clear.frame(width: 42, height: 42)
            }

            GeometryReader { proxy in
                Capsule()
                    .fill(Color.cvStudioAccent.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.cvStudioAccent)
                            .frame(width: proxy.size.width * CGFloat(questionNumber) / CGFloat(max(questionCount, 1)))
                    }
            }
            .frame(height: 5)
        }
    }
}

private struct QuestionPromptCard: View {
    let category: PracticeCategory
    let question: String
    let helperText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(category.rawValue.uppercased(), systemImage: category.icon)
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(Color.cvQuestionAmber)

            Text("Your question")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.cvQuestionMuted)
                .textCase(.uppercase)

            Text(question)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.cvQuestionInk)
                .fixedSize(horizontal: false, vertical: true)

            Text(helperText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.cvQuestionBody)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Color.cvQuestionCard.opacity(0.97), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.cvQuestionBorder, lineWidth: 1))
        .shadow(color: Color.cvQuestionShadow, radius: 8, x: 0, y: 3)
    }
}

private struct VoiceAnswerCard: View {
    @ObservedObject var session: TimedAnswerSession
    let isAnalyzing: Bool
    let isVividTranscribing: Bool
    let coachingSuggestions: [String]
    @Binding var answerDraft: String
    let onRecordAction: () -> Void
    let onSendAction: () -> Void

    private var isTranscriptionActive: Bool {
        session.state == .transcribing || isVividTranscribing
    }

    private var statusTitle: String {
        isTranscriptionActive ? "Turning speech into text" : session.state.title
    }

    private var statusDetail: String {
        isTranscriptionActive
            ? "Vivid is preparing an editable transcript of your answer."
            : session.state.detail
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.cvQuestionInk)
                    Text(statusDetail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.cvQuestionMuted)
                }
                Spacer()
                Text(session.formattedDuration)
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(session.state == .recording ? Color.cvQuestionRecordingRing : Color.cvQuestionInk)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(session.state == .recording ? Color.cvQuestionRecordingRing.opacity(0.10) : Color.cvQuestionPaper, in: Capsule())
            }

            if session.state == .recording || session.state == .transcribing || isVividTranscribing {
                LiveTranscriptPanel(
                    transcript: session.transcript,
                    audioLevel: session.audioLevel,
                    state: isVividTranscribing ? .transcribing : session.state
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }

            Button(action: onRecordAction) {
                TimedRecordControl(
                    progress: session.progress,
                    state: session.state,
                    isDisabled: isAnalyzing,
                    isTranscribing: isTranscriptionActive
                )
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(session.state == .preparing || session.state == .transcribing || isAnalyzing || isVividTranscribing)
            .accessibilityLabel(session.state == .recording ? "Stop recording answer" : session.state == .readyToAnalyze ? "Record answer again" : "Start recording answer")
            .accessibilityHint(session.state == .recording ? "Stops recording and opens the transcript for review." : "Starts recording your spoken answer.")

            if session.state == .readyToAnalyze && !isVividTranscribing {
                EditableTranscriptReview(
                    answer: $answerDraft,
                    suggestions: coachingSuggestions,
                    onSend: onSendAction
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity
                ))
            }
        }
        .padding(18)
        .background(Color.cvQuestionCard.opacity(0.97), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.cvQuestionBorder, lineWidth: 1))
        .animation(.easeInOut(duration: 0.22), value: session.state)
        .animation(.easeInOut(duration: 0.22), value: coachingSuggestions)
    }
}

private struct EditableTranscriptReview: View {
    @Binding var answer: String
    let suggestions: [String]
    let onSend: () -> Void

    private var cleanAnswer: String {
        answer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "pencil.line")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.cvStudioAccent)
                    .frame(width: 30, height: 30)
                    .background(Color.cvQuestionPaper, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Review your answer")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.cvQuestionInk)
                    Text("Correct the transcript before sending it to AI.")
                        .font(.caption)
                        .foregroundStyle(Color.cvQuestionMuted)
                }
            }

            ZStack(alignment: .topLeading) {
                if answer.isEmpty {
                    Text("We could not transcribe this recording. Type what you said here, or record again.")
                        .font(.body)
                        .foregroundStyle(Color.cvQuestionMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 15)
                        .allowsHitTesting(false)
                }

                ExpandableTranscriptTextView(text: $answer)
                    .frame(maxWidth: .infinity)
            }
            .background(Color.cvQuestionPaper.opacity(0.94), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.cvStudioAccent.opacity(0.20), lineWidth: 1)
            )

            if !suggestions.isEmpty {
                Divider()
                    .overlay(Color.cvStudioAccent.opacity(0.14))

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "lightbulb.max.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.cvQuestionSuccess)
                            .frame(width: 28, height: 28)
                            .background(Color.cvQuestionRecordingFill.opacity(0.74), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Strengthen this answer")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.cvQuestionInk)
                            Text("Try one change now, or record again.")
                                .font(.caption)
                                .foregroundStyle(Color.cvQuestionMuted)
                        }
                    }

                    ForEach(Array(suggestions.prefix(3).enumerated()), id: \.offset) { _, suggestion in
                        HStack(alignment: .top, spacing: 9) {
                            Circle()
                                .fill(Color.cvQuestionSuccess.opacity(0.72))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(suggestion)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.cvQuestionBody)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button(action: onSend) {
                HStack(spacing: 9) {
                    Image(systemName: "paperplane.fill")
                    Text("Send for Deep AI Analysis")
                }
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(QuestionPrimaryButtonStyle())
            .disabled(cleanAnswer.isEmpty)
            .opacity(cleanAnswer.isEmpty ? 0.48 : 1)
            .accessibilityHint("Sends your edited answer to CareerVivid and creates an interview report.")
        }
        .padding(14)
        .background(Color.cvStudioAccentSoft.opacity(0.46), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.cvStudioAccent.opacity(0.20), lineWidth: 1)
        )
    }
}

/// Keeps the transcript editor as tall as its complete answer so the interview
/// page owns scrolling. This avoids a nested scroll view and leaves the send
/// action directly after the final line, even for multi-page answers.
private struct ExpandableTranscriptTextView: UIViewRepresentable {
    @Binding var text: String

    private let minimumHeight: CGFloat = 126

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = UIColor(Color.cvQuestionInk)
        textView.tintColor = UIColor(Color.cvStudioAccent)
        textView.isScrollEnabled = false
        textView.showsVerticalScrollIndicator = false
        textView.textContainerInset = UIEdgeInsets(top: 13, left: 9, bottom: 13, right: 9)
        textView.textContainer.lineFragmentPadding = 4
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.accessibilityLabel = "Review your answer"
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        if textView.text != text {
            textView.text = text
        }
        textView.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView textView: UITextView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let measuredSize = textView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: width, height: max(minimumHeight, ceil(measuredSize.height)))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ExpandableTranscriptTextView

        init(parent: ExpandableTranscriptTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            textView.invalidateIntrinsicContentSize()
        }
    }
}

private struct LiveTranscriptPanel: View {
    let transcript: String
    let audioLevel: CGFloat
    let state: TimedAnswerState

    private var isListening: Bool {
        state == .recording
    }

    private var displayedTranscript: String {
        let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.isEmpty else { return cleaned }
        return isListening
            ? "Start speaking. Your words will appear here in real time."
            : "Your recording is secure. Vivid is preparing the editable transcript."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("Live transcript", systemImage: "text.bubble.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.cvStudioAccent)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(isListening ? Color.cvQuestionDanger : Color.cvQuestionWarning)
                        .frame(width: 7, height: 7)
                    Text(isListening ? "Listening" : "Transcribing")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(Color.cvQuestionMuted)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.cvQuestionPaper.opacity(0.88), in: Capsule())
            }

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    Text(displayedTranscript)
                        .font(.body.weight(transcript.isEmpty ? .regular : .medium))
                        .foregroundStyle(transcript.isEmpty ? Color.cvQuestionMuted : Color.cvQuestionInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .id("live-transcript-end")
                }
                .frame(minHeight: 64, maxHeight: 126)
                .onChange(of: transcript) { _, _ in
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo("live-transcript-end", anchor: .bottom)
                    }
                }
            }

            HStack(spacing: 10) {
                if isListening {
                    LiveTranscriptWaveform(level: audioLevel, isActive: true)
                } else {
                    TranscribingStreamIndicator()
                }
                Text(isListening ? "Tap the circle again when you finish" : "Preparing your answer for review")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.cvQuestionMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(0)
            }
        }
        .padding(15)
        .background(Color.cvStudioAccentSoft.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.cvStudioAccent.opacity(isListening ? 0.28 : 0.16), lineWidth: 1)
        )
        .shadow(color: Color.cvStudioAccent.opacity(0.07), radius: 8, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Live transcript")
        .accessibilityValue(displayedTranscript)
    }
}

private struct LiveTranscriptWaveform: View {
    let level: CGFloat
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let barCount = 16

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.06, paused: !isActive || reduceMotion)) { context in
            let phase = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate * 5.2
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    let rhythm = abs(sin(phase + Double(index) * 0.73))
                    let normalizedLevel = max(isActive ? level : 0.04, 0.04)
                    let barHeight = 3 + (17 * normalizedLevel * CGFloat(0.30 + rhythm * 0.70))

                    Capsule(style: .continuous)
                        .fill(waveformColor(for: index))
                        .frame(width: 3, height: barHeight)
                        .animation(.easeOut(duration: 0.10), value: level)
                }
            }
            .frame(height: 22)
        }
        .frame(width: 80, alignment: .leading)
        .clipped()
        .accessibilityHidden(true)
    }

    private func waveformColor(for index: Int) -> Color {
        switch index % 6 {
        case 0:
            return Color.cvQuestionDashboardBlue.opacity(0.72)
        case 3:
            return Color.cvQuestionSuccess.opacity(0.62)
        default:
            return Color.cvStudioAccent.opacity(0.72)
        }
    }
}

private struct TimedRecordControl: View {
    let progress: CGFloat
    let state: TimedAnswerState
    let isDisabled: Bool
    let isTranscribing: Bool

    private var isRecording: Bool {
        state == .recording
    }

    private var progressColor: Color {
        isRecording ? .cvQuestionRecordingRing : .cvStudioAccent
    }

    private var controlFill: Color {
        isRecording ? .cvQuestionRecordingFill : .cvStudioAccent
    }

    private var controlForeground: Color {
        isRecording ? .cvQuestionRecordingText : .white
    }

    var body: some View {
        Group {
            if isTranscribing {
                TranscribingActivityControl()
            } else {
                ZStack {
                    Circle()
                        .stroke(Color.cvStudioAccent.opacity(0.15), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: max(0.012, progress))
                        .stroke(
                            progressColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.4), value: progress)

                    Circle()
                        .fill(controlFill)
                        .frame(width: 130, height: 130)
                        .shadow(color: controlFill.opacity(0.22), radius: 16, x: 0, y: 8)

                    VStack(spacing: 8) {
                        if state == .preparing {
                            ProgressView()
                                .tint(controlForeground)
                                .controlSize(.regular)
                        } else {
                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.title2.weight(.bold))
                        }
                        Text(state == .preparing ? "Preparing" : isRecording ? "Tap to stop" : state == .readyToAnalyze ? "Record again" : "Tap to record")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(controlForeground)
                }
            }
        }
        .frame(width: 172, height: 172)
        .opacity(isDisabled ? 0.55 : 1)
        .padding(.vertical, 4)
    }
}

private struct TranscribingActivityControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    Image(systemName: "waveform.and.magnifyingglass")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.cvStudioAccent)
                        .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)

                    Text("Transcribing")
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Transcribing your recorded answer")
    }
}

private struct TranscribingStreamIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.06, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    let wave = reduceMotion ? 0.35 : (sin(time * 5.4 - Double(index) * 0.85) + 1) / 2
                    Circle()
                        .fill(dotColor(for: index))
                        .frame(width: 6, height: 6)
                        .scaleEffect(0.78 + wave * 0.30)
                        .opacity(0.38 + wave * 0.62)
                        .offset(y: -2 * wave)
                }
            }
        }
        .frame(width: 42, height: 16)
        .fixedSize(horizontal: true, vertical: true)
        .layoutPriority(2)
        .accessibilityHidden(true)
    }

    private func dotColor(for index: Int) -> Color {
        switch index {
        case 1: return .cvQuestionDashboardBlue
        case 2: return .cvQuestionSuccess
        default: return .cvStudioAccent
        }
    }
}

private struct TypedAnswerCard: View {
    @Binding var answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your answer", systemImage: "keyboard")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.cvQuestionInk)
            TextEditor(text: $answer)
                .font(.body)
                .foregroundStyle(Color.cvQuestionInk)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 170)
                .padding(10)
                .background(Color.cvQuestionPaper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.cvQuestionBorder, lineWidth: 1))

        }
        .padding(18)
        .background(Color.cvQuestionCard.opacity(0.97), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.cvQuestionBorder, lineWidth: 1))
    }
}

private struct QuestionErrorCard: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.cvQuestionDanger)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cvQuestionDanger.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.cvQuestionDanger.opacity(0.25), lineWidth: 1))
    }
}


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
