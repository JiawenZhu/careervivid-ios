import SafariServices
import SwiftUI

enum QuestionWebQuestStage: String {
    case coding
    case systemDesign = "system_design"

    var title: String {
        switch self {
        case .coding: return "Coding workspace"
        case .systemDesign: return "System design workspace"
        }
    }

    var symbol: String {
        switch self {
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .systemDesign: return "rectangle.3.group"
        }
    }

    /// Short reason this stage is better on a larger screen.
    var experienceDetail: String {
        switch self {
        case .coding: return "a full code editor and test runner"
        case .systemDesign: return "an architecture drawing canvas"
        }
    }

    /// Conversational name used inline in the desktop-recommendation copy.
    var shortName: String {
        switch self {
        case .coding: return "coding round"
        case .systemDesign: return "system design round"
        }
    }

    /// The concrete things the user gets in the full web workspace, shown as a
    /// short feature list on the desktop-recommendation screen.
    var highlights: [(symbol: String, label: String)] {
        switch self {
        case .coding:
            return [
                ("chevron.left.forwardslash.chevron.right", "Full code editor"),
                ("checkmark.circle", "Instant test runner"),
            ]
        case .systemDesign:
            return [
                ("rectangle.3.group", "Drag-and-drop canvas"),
                ("arrow.triangle.branch", "Architecture diagram"),
            ]
        }
    }

    /// Only specialized, browser-based stages leave the native real-time
    /// answer flow. Screening, behavioral, values, and final always stay in
    /// the app, even though they all use the same official question catalog.
    static func resolve(stageTitle: String?, category: PracticeCategory) -> Self? {
        switch stageTitle?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "coding round", "coding":
            return .coding
        case "system design", "system design round":
            return .systemDesign
        case .some:
            return nil
        case .none:
            switch category {
            case .technical:
                return .coding
            case .systemDesign:
                return .systemDesign
            case .behavioral, .leadership:
                return nil
            }
        }
    }
}

/// Coding and system design use the full CareerVivid web workspaces, which
/// already contain the code editor, test runner, and whiteboard. SFSafariView-
/// Controller preserves normal Safari authentication while keeping the user in
/// the app's flow.
struct QuestionWebQuestStageView: View {
    let company: String
    let guideSlug: String
    let stage: QuestionWebQuestStage
    let onClose: () -> Void

    @State private var presentsWebsite = false

    private var webURL: URL {
        var components = URLComponents(string: "https://careervivid.app/quest/\(guideSlug)")!
        components.queryItems = [
            URLQueryItem(name: "stage", value: stage.rawValue),
            URLQueryItem(name: "source", value: "ios"),
        ]
        return components.url!
    }

    var body: some View {
        ZStack {
            Color.cvAppBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 16)

                VStack(spacing: 24) {
                    iconBadge

                    VStack(spacing: 14) {
                        Text(stage.title)
                            .font(.system(.caption, design: .rounded).weight(.heavy))
                            .textCase(.uppercase)
                            .kerning(1.2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 7)
                            .background(
                                LinearGradient(
                                    colors: [Color.cvStudioAccent, Color.cvPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: Capsule()
                            )
                            .shadow(color: Color.cvStudioAccent.opacity(0.30), radius: 9, x: 0, y: 5)

                        Text("Better on a bigger screen")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.cvQuestionInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("\(company)'s \(stage.shortName) uses \(stage.experienceDetail). You'll get the smoothest experience on a desktop or laptop — but you can keep going here.")
                            .font(.system(.callout, design: .rounded).weight(.medium))
                            .foregroundStyle(Color.cvQuestionBody)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }

                    highlightsCard
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 16)

                actionButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $presentsWebsite, onDismiss: onClose) {
            QuestionWebQuestSafariView(url: webURL)
                .ignoresSafeArea()
        }
    }

    private var iconBadge: some View {
        Image(systemName: "desktopcomputer")
            .font(.system(size: 36, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 92, height: 92)
            .background(
                LinearGradient(
                    colors: [Color.cvStudioAccent, Color.cvPurple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .shadow(color: Color.cvStudioAccent.opacity(0.32), radius: 20, x: 0, y: 12)
    }

    private var highlightsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(stage.highlights.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 14) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.cvStudioAccent)
                        .frame(width: 36, height: 36)
                        .background(Color.cvStudioAccentSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                    Text(item.label)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.cvQuestionInk)

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 13)

                if index < stage.highlights.count - 1 {
                    Divider().overlay(Color.cvQuestionBorder)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 2)
        .background(Color.cvQuestionCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.cvQuestionBorder, lineWidth: 1))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                QuestionHaptic.play(.medium)
                presentsWebsite = true
            } label: {
                HStack(spacing: 8) {
                    Text("Continue on mobile")
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                    Image(systemName: "arrow.up.forward")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    LinearGradient(
                        colors: [Color.cvStudioAccent, Color.cvPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .shadow(color: Color.cvStudioAccent.opacity(0.34), radius: 14, x: 0, y: 7)
            }
            .buttonStyle(QuestionGateButtonStyle())

            Button(action: onClose) {
                Text("Not now")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.cvStudioAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.cvStudioAccentSoft.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.cvStudioAccent.opacity(0.22), lineWidth: 1))
            }
            .buttonStyle(QuestionGateButtonStyle())
        }
    }
}

/// Subtle scale + dim press feedback for the custom gradient buttons on the
/// desktop-recommendation gate (the shared button styles bake in their own
/// background, so the gate uses this lighter-weight style instead).
private struct QuestionGateButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct QuestionWebQuestSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct QuestionCatalogLoadingScreen: View {
    let company: String
    let stageTitle: String?

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.cvStudioAccent)
            Text("Loading official questions")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.cvQuestionInk)
            Text("Getting the \(company) \(stageTitle ?? "mock interview") prompts from CareerVivid's web-aligned guide.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.cvQuestionBody)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Color.cvQuestionCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.cvQuestionBorder, lineWidth: 1))
        .padding(24)
    }
}

struct QuestionCatalogUnavailableScreen: View {
    let company: String
    let message: String
    let onBack: () -> Void
    let onRetry: () async -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.cvQuestionWarning)
            Text("Official questions unavailable")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.cvQuestionInk)
            Text("We did not substitute a generic question. \(message)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.cvQuestionBody)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Button("Back", action: onBack)
                    .buttonStyle(QuestionSecondaryButtonStyle())
                Button {
                    Task { await onRetry() }
                } label: {
                    Label("Try again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(QuestionPrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.cvQuestionCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.cvQuestionBorder, lineWidth: 1))
        .padding(24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(company) official questions unavailable. \(message)")
    }
}


