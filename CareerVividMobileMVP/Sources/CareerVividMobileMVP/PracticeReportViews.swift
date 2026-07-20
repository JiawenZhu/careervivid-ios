import SwiftUI
#if os(iOS)
import UIKit
#endif

struct PracticeReportScreen: View {
    let config: InterviewLiveConfig
    let analysis: InterviewAnalysisResult?
    let elapsedSeconds: Int
    let onPracticeAgain: () -> Void
    let onRemediateWeakness: (ReportInsightItem) -> Void
    let onRemediateAll: ([ReportInsightItem]) -> Void

    var body: some View {
        Group {
            if let analysis {
                let strengths = ReportInsightParser.items(from: analysis.strengths, kind: "strength")
                let weaknesses = ReportInsightParser.items(from: analysis.areasForImprovement, kind: "weakness")

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 14) {
                            Text("Interview report")
                                .font(.headline.weight(.bold))
                            ScoreRing(score: analysis.overallScore, label: "score", size: 108)

                            HStack(spacing: 12) {
                                PracticeMetricPill(value: timeString(analysis.durationInSeconds ?? elapsedSeconds), label: "Time")
                                PracticeMetricPill(value: config.category.rawValue, label: "Type")
                            }
                        }
                        .cvCard(padding: 22, radius: 26, raised: true)

                        InterviewScoreBreakdown(analysis: analysis)

                        if let skills = analysis.skills, !skills.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Demonstrated skills", systemImage: "bolt.badge.a.fill")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.cvBrand)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(skills, id: \.self) { skill in
                                            Text(skill)
                                                .font(.caption.weight(.bold))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.cvBrand.opacity(0.08))
                                                .foregroundStyle(Color.cvBrand)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            .cvCard(padding: 18, radius: 24, raised: true)
                        }

                        FeedbackInsightCard(
                            title: "What went well",
                            systemImage: "checkmark.seal.fill",
                            color: .green,
                            items: strengths
                        )

                        WeaknessRemediationCard(
                            weaknesses: weaknesses,
                            onSelect: onRemediateWeakness
                        )
                    }
                    .padding(20)
                    .padding(.bottom, CVLayout.floatingTabContentPadding + 72)
                }
                .safeAreaInset(edge: .bottom) {
                    ReportActionMatrix(
                        weaknesses: weaknesses,
                        onPracticeAgain: onPracticeAgain,
                        onRemediateAll: onRemediateAll
                    )
                }
            } else {
                PracticeErrorBanner(message: "No interview report is available yet.")
                    .padding(20)
            }
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}

private struct InterviewScoreBreakdown: View {
    let analysis: InterviewAnalysisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Metric breakdown", systemImage: "chart.bar.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.cvBrand)

            if analysis.hasV2Scores {
                ScoreBar(title: "Communication", score: analysis.communicationScore)
                ScoreBar(title: "Problem solving", score: analysis.problemSolvingScore ?? analysis.confidenceScore)
                ScoreBar(title: "Experience & impact", score: analysis.experienceScore ?? analysis.relevanceScore)
                ScoreBar(title: "Role alignment", score: analysis.roleAlignmentScore ?? analysis.relevanceScore)
                if let leadershipScore = analysis.leadershipScore {
                    ScoreBar(title: "Leadership", score: leadershipScore)
                }
            } else {
                ScoreBar(title: "Communication", score: analysis.communicationScore)
                ScoreBar(title: "Confidence", score: analysis.confidenceScore)
                ScoreBar(title: "Answer relevance", score: analysis.relevanceScore)
            }
        }
        .cvCard(padding: 18, radius: 24, raised: true)
    }
}

private struct ScoreBar: View {
    let title: String
    let score: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.bold))
                Spacer()
                Text("\(score)%")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.cvBrand)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.cvSystemFill)
                    Capsule()
                        .fill(Color.cvBrand)
                        .frame(width: proxy.size.width * min(CGFloat(score) / 100, 1))
                }
            }
            .frame(height: 7)
        }
    }
}

private struct FeedbackInsightCard: View {
    let title: String
    let systemImage: String
    let color: Color
    let items: [ReportInsightItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 7) {
                ForEach(items) { item in
                    MarkdownText(item.markdown)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
        }
        .cvCard(padding: 18, radius: 24, raised: true)
    }
}

private struct WeaknessRemediationCard: View {
    let weaknesses: [ReportInsightItem]
    let onSelect: (ReportInsightItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Practice next", systemImage: "target")
                .font(.headline.weight(.bold))
                .foregroundStyle(.orange)

            ForEach(weaknesses) { weakness in
                Button {
                    playImpactHaptic(.light)
                    onSelect(weakness)
                } label: {
                    WeaknessRow(weakness: weakness)
                }
                .buttonStyle(WeaknessRowButtonStyle())
                .accessibilityLabel("Practice weakness: \(weakness.title)")
            }
        }
        .cvCard(padding: 18, radius: 24, raised: true)
    }
}

private struct WeaknessRow: View {
    let weakness: ReportInsightItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "scope")
                .font(.subheadline.weight(.black))
                .foregroundStyle(.orange)
                .frame(width: 30, height: 30)
                .background(Color.orange.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(weakness.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                if !weakness.body.isEmpty {
                    MarkdownText(weakness.body)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text("Start targeted drill")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(Color.cvBrand)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cvBrandSoft)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(Color.cvTertiarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct WeaknessRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ReportActionMatrix: View {
    let weaknesses: [ReportInsightItem]
    let onPracticeAgain: () -> Void
    let onRemediateAll: ([ReportInsightItem]) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                playImpactHaptic(.medium)
                onPracticeAgain()
            } label: {
                ReportActionButtonLabel(
                    title: "Practice Again",
                    subtitle: "Same question",
                    systemImage: "arrow.clockwise",
                    isPrimary: false
                )
            }
            .buttonStyle(.plain)

            Button {
                playImpactHaptic(.medium)
                onRemediateAll(weaknesses)
            } label: {
                ReportActionButtonLabel(
                    title: "Skill Booster",
                    subtitle: "Fix weak spots",
                    systemImage: "bolt.fill",
                    isPrimary: true
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }
}

private struct ReportActionButtonLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isPrimary: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.black))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(subtitle)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .opacity(0.78)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(isPrimary ? .white : Color.cvBrand)
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(isPrimary ? AnyShapeStyle(LinearGradient.cvBrandGradient) : AnyShapeStyle(Color.cvBrandSoft))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: isPrimary ? Color.cvBrand.opacity(0.18) : .clear, radius: 14, x: 0, y: 7)
    }
}

private struct MarkdownText: View {
    let markdown: String

    init(_ markdown: String) {
        self.markdown = markdown
    }

    var body: some View {
        Text(attributedMarkdown)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributedMarkdown: AttributedString {
        let sanitized = ReportInsightParser.normalizedMarkdown(markdown)
        if let attributed = try? AttributedString(markdown: sanitized) {
            return attributed
        }
        return AttributedString(ReportInsightParser.plainText(from: sanitized))
    }
}

struct ReportInsightItem: Identifiable, Hashable {
    let id: String
    let title: String
    let body: String
    let markdown: String
}

enum ReportInsightParser {
    static func items(from markdown: String, kind: String) -> [ReportInsightItem] {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: .newlines)
            .map(cleanLeadingBullet)
            .filter { !$0.isEmpty }

        let sourceLines = lines.isEmpty ? [markdown.trimmingCharacters(in: .whitespacesAndNewlines)] : lines
        return sourceLines.enumerated().compactMap { index, line in
            let clean = normalizedMarkdown(line)
            guard !clean.isEmpty else { return nil }
            let parts = splitTitleAndBody(clean)
            return ReportInsightItem(
                id: "\(kind)-\(index)-\(stableSlug(parts.title))",
                title: plainText(from: parts.title),
                body: plainText(from: parts.body),
                markdown: clean
            )
        }
    }

    static func normalizedMarkdown(_ value: String) -> String {
        cleanLeadingBullet(value)
            .replacingOccurrences(of: #"(?m)^\s*\d+\.\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func plainText(from markdown: String) -> String {
        markdown
            .replacingOccurrences(of: #"\*\*(.*?)\*\*"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"`([^`]+)`"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"[_*]{1,2}"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanLeadingBullet(_ line: String) -> String {
        line
            .replacingOccurrences(of: #"^\s*[-*•]\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func splitTitleAndBody(_ markdown: String) -> (title: String, body: String) {
        let clean = normalizedMarkdown(markdown)
        if clean.hasPrefix("**"),
           let close = clean.dropFirst(2).range(of: "**") {
            let titleStart = clean.index(clean.startIndex, offsetBy: 2)
            let rawTitle = String(clean[titleStart..<close.lowerBound])
            var remainder = String(clean[close.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if remainder.hasPrefix(":") {
                remainder.removeFirst()
                remainder = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return (
                rawTitle.trimmingCharacters(in: CharacterSet(charactersIn: ": ").union(.whitespacesAndNewlines)),
                remainder
            )
        }

        if let colon = clean.firstIndex(of: ":") {
            let title = String(clean[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
            let body = String(clean[clean.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty, !body.isEmpty, title.count <= 80 {
                return (title, body)
            }
        }

        return (firstWords(from: clean), clean)
    }

    private static func firstWords(from text: String) -> String {
        let words = plainText(from: text).split(separator: " ").prefix(7)
        return words.isEmpty ? "Practice focus" : words.joined(separator: " ")
    }

    private static func stableSlug(_ text: String) -> String {
        plainText(from: text)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

func playImpactHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    #if os(iOS)
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.prepare()
    generator.impactOccurred()
    #endif
}

func remediationQuestions(for weaknesses: [ReportInsightItem], baseConfig: InterviewLiveConfig) -> [String] {
    let focusItems = weaknesses.isEmpty
        ? [ReportInsightItem(id: "weakness-general", title: "Improve answer structure", body: "Use clearer examples, sharper STAR structure, and role-specific evidence.", markdown: "Use clearer examples, sharper STAR structure, and role-specific evidence.")]
        : Array(weaknesses.prefix(5))

    var questions = focusItems.map { weakness in
        "Let's work on \(weakness.title.lowercased()). For a \(baseConfig.job.title) interview at \(baseConfig.job.company), answer with a specific example that directly improves this weakness."
    }
    questions.append("Now combine the improvements into one concise, role-specific answer that uses clear structure, concrete impact, and confident delivery.")
    return questions
}
