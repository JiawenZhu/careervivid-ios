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
    @State private var hasPresentedWebsite = false

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
            QuestionPracticeGrid()

            VStack(spacing: 16) {
                Image(systemName: stage.symbol)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.cvStudioAccent)
                    .frame(width: 64, height: 64)
                    .background(Color.cvStudioAccentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text("Opening \(stage.title)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.cvQuestionInk)
                Text("\(company)'s official \(stage.title.lowercased()) is running in CareerVivid Web so you get the full specialized experience.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.cvQuestionBody)
                    .multilineTextAlignment(.center)

                Button {
                    presentsWebsite = true
                } label: {
                    Label("Open \(stage.title)", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(QuestionPrimaryButtonStyle())
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .background(Color.cvQuestionCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.cvQuestionBorder, lineWidth: 1))
            .padding(24)
        }
        .task {
            guard !hasPresentedWebsite else { return }
            hasPresentedWebsite = true
            presentsWebsite = true
        }
        .sheet(isPresented: $presentsWebsite, onDismiss: onClose) {
            QuestionWebQuestSafariView(url: webURL)
                .ignoresSafeArea()
        }
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

private extension Color {
    static let cvQuestionCard = Color(red: 1.000, green: 0.979, blue: 0.941) // #FFF9F0
    static let cvQuestionInk = Color(red: 0.129, green: 0.106, blue: 0.086) // #211B16
    static let cvQuestionBody = Color(red: 0.400, green: 0.353, blue: 0.290) // #665A4A
    static let cvQuestionBorder = Color(red: 0.894, green: 0.827, blue: 0.737) // #E4D3BC
    static let cvQuestionWarning = Color(red: 0.851, green: 0.467, blue: 0.024) // #D97706
}
