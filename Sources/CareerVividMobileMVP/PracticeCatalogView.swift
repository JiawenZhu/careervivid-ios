import SwiftUI

private enum MockInterviewFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case bigTech = "Big Tech"
    case aiLabs = "AI Labs"
    case fintech = "Fintech & Quant"
    case hardware = "Hardware"

    var id: String { rawValue }

    func includes(_ guide: MobileInterviewGuideSummary) -> Bool {
        switch self {
        case .all:
            true
        case .bigTech:
            ["adobe", "amazon", "apple", "cisco", "google", "meta-facebook", "microsoft", "netflix", "oracle-interview", "salesforce", "sap", "servicenow"].contains(guide.slug)
        case .aiLabs:
            ["anthropic", "cohere", "cursor", "deepgram-interview-guide", "elevenlabs-interview-guide", "fireworks-ai", "hugging-face-interview-guide", "langchain", "mistral-ai-interview-guide", "openai", "perplexity", "pinecone-interview-guide", "scale-ai", "together-ai", "xai"].contains(guide.slug)
        case .fintech:
            ["affirm-interview-guide", "block", "brex", "chime", "coinbase", "deel", "jane-street", "mercury", "plaid", "ramp", "robinhood", "stripe", "wealthfront", "wise-interview-guide"].contains(guide.slug)
        case .hardware:
            ["amd-interview-guide", "anduril-interview-guide", "blue-origin-interview-guide", "intel-interview-guide", "nvidia", "qualcomm-interview-guide", "spacex-interview-guide", "tesla"].contains(guide.slug)
        }
    }
}

struct PracticeCatalogView: View {
    @State private var filter: MockInterviewFilter = .all
    @State private var searchText = ""
    @State private var guideLimit = 12
    @State private var companyProgress = CompanyQuestProgressStore.all()

    private var matchingGuides: [MobileInterviewGuideSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let candidates = MobileInterviewGuideCatalog.all.filter { guide in
            guard filter.includes(guide) else { return false }
            guard !query.isEmpty else { return true }
            return guide.company.lowercased().contains(query)
                || guide.slug.lowercased().contains(query)
                || MobileInterviewGuideCatalog.topicChips(for: guide.slug).contains { $0.lowercased().contains(query) }
        }

        if filter == .all && query.isEmpty {
            let featuredSlugs = Set(MobileInterviewGuideCatalog.webFeatured.map(\.slug))
            let remainder = candidates
                .filter { !featuredSlugs.contains($0.slug) }
                .sorted(by: MockInterviewGuideSort.isHigherPriority)
            return MobileInterviewGuideCatalog.webFeatured + remainder
        }

        return candidates.sorted(by: MockInterviewGuideSort.isHigherPriority)
    }

    private var visibleGuides: [MobileInterviewGuideSummary] {
        Array(matchingGuides.prefix(guideLimit))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MockInterviewGridBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        MockInterviewGuideHeader()
                        MockInterviewSearchField(searchText: $searchText)
                        MockInterviewFilterBar(filter: $filter)
                        MockInterviewGuideList(guides: visibleGuides, progressByCompany: companyProgress)

                        if matchingGuides.count > visibleGuides.count {
                            Button(action: showMoreGuides) {
                                Text("Show \(matchingGuides.count - visibleGuides.count) more companies")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .buttonStyle(MockInterviewSecondaryButtonStyle())
                        }

                        if matchingGuides.isEmpty {
                            MockInterviewEmptyState()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, CVLayout.floatingTabContentPadding)
                }
            }
            .navigationTitle("Mock Interview")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: MobileInterviewGuideSummary.self) { guide in
                MockInterviewQuestView(guide: guide)
            }
            .onChange(of: searchText) { _, _ in resetGuideLimit() }
            .onChange(of: filter) { _, _ in resetGuideLimit() }
            .onAppear { companyProgress = CompanyQuestProgressStore.all() }
        }
    }
}

private enum MockInterviewGuideSort {
    static func isHigherPriority(_ left: MobileInterviewGuideSummary, _ right: MobileInterviewGuideSummary) -> Bool {
        let leftScore = left.questionCount * 4 + left.stageCount * 2 + MobileInterviewGuideCatalog.tipCount(for: left.slug) + Int(left.difficulty ?? 0)
        let rightScore = right.questionCount * 4 + right.stageCount * 2 + MobileInterviewGuideCatalog.tipCount(for: right.slug) + Int(right.difficulty ?? 0)
        return leftScore == rightScore ? left.company < right.company : leftScore > rightScore
    }
}

private extension PracticeCatalogView {
    func resetGuideLimit() {
        guideLimit = 12
    }

    func showMoreGuides() {
        guideLimit += 12
    }
}

private struct MockInterviewGuideHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "building.2.crop.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.cvStudioAccent)
                    .frame(width: 42, height: 42)
                    .background(Color.cvStudioAccentSoft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                Text("Know exactly what to expect")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.cvQuestInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("Interview stages, key topics, and sample questions sourced from real engineers at each company — powered by")
                Link("techinterview.org.", destination: URL(string: "https://www.techinterview.org/")!)
                    .underline()
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.cvQuestBody)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 0) {
                MockInterviewStat(value: MobileInterviewGuideCatalog.companies.formatted(), label: "companies")
                Divider().background(Color.cvQuestBorder)
                MockInterviewStat(value: MobileInterviewGuideCatalog.questions.formatted(), label: "questions")
                Divider().background(Color.cvQuestBorder)
                MockInterviewStat(value: MobileInterviewGuideCatalog.stages.formatted(), label: "stages")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.cvQuestPaper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.cvQuestBorder.opacity(0.72), lineWidth: 1))
        }
        .padding(16)
        .background(Color.cvQuestCard.opacity(0.95), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.cvQuestBorder, lineWidth: 1))
        .shadow(color: Color.cvQuestShadow, radius: 8, x: 0, y: 3)
    }
}

private struct MockInterviewStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.cvQuestInk)
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.cvQuestMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MockInterviewSearchField: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.cvQuestMuted)
            TextField("Search Google, Stripe, OpenAI, system design...", text: $searchText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.body.weight(.medium))
                .foregroundStyle(Color.cvQuestInk)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(Color.cvQuestPaper.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.cvQuestInk.opacity(0.86), lineWidth: 1))
    }
}

private struct MockInterviewFilterBar: View {
    @Binding var filter: MockInterviewFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MockInterviewFilter.allCases) { option in
                    Button {
                        filter = option
                    } label: {
                        Text(option.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(filter == option ? .white : Color.cvQuestBody)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 9)
                            .background(filter == option ? Color.cvStudioAccent : Color.cvQuestPaper.opacity(0.9), in: Capsule())
                            .overlay(Capsule().stroke(filter == option ? Color.clear : Color.cvQuestBorder.opacity(0.7), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct MockInterviewGuideList: View {
    let guides: [MobileInterviewGuideSummary]
    let progressByCompany: [String: CompanyQuestProgress]

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(guides) { guide in
                MockInterviewCompanyCard(
                    guide: guide,
                    progress: progressByCompany[CompanyQuestProgressStore.companyKey(for: guide.company)] ?? CompanyQuestProgress()
                )
            }
        }
    }
}

private struct MockInterviewCompanyCard: View {
    let guide: MobileInterviewGuideSummary
    let progress: CompanyQuestProgress

    private var practiceJob: JobLead {
        JobLead(
            title: "Interview candidate",
            company: guide.company,
            matchScore: 100,
            stage: .interview,
            nextStep: "Start company mock interview"
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                CompanyLogoMark(company: guide.company, slug: guide.slug, size: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(guide.company)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.cvQuestInk)
                        .lineLimit(1)
                    Text(guide.guideMetadata)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.cvQuestMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if let difficulty = guide.difficulty {
                    MockInterviewDifficultyBadge(difficulty: difficulty)
                }
            }

            if !guide.topicChips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(guide.topicChips, id: \.self) { topic in
                        Text(topic)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.cvQuestBody)
                            .lineLimit(1)
                    }
                }
            }

            MockInterviewCompanyProgress(progress: progress)

            HStack(spacing: 10) {
                NavigationLink(value: guide) {
                    Label(progress.attempts == 0 ? "Start quest" : "Continue quest", systemImage: progress.attempts == 0 ? "figure.fencing" : "arrow.clockwise")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(MockInterviewPrimaryButtonStyle())

                NavigationLink {
                    PracticeView(initialJob: practiceJob, guideSlug: guide.slug)
                } label: {
                    Image(systemName: "sparkles")
                        .font(.body.weight(.bold))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(MockInterviewIconButtonStyle())
                .accessibilityLabel("Start a single mock interview for \(guide.company)")

                Link(destination: guide.sourceURL) {
                    Image(systemName: "arrow.up.right")
                        .font(.body.weight(.bold))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(MockInterviewIconButtonStyle())
                .accessibilityLabel("Open \(guide.company) source guide")
            }
        }
        .padding(16)
        .background(Color.cvQuestCard.opacity(0.97), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Color.cvQuestBorder, lineWidth: 1))
        .shadow(color: Color.cvQuestShadow, radius: 7, x: 0, y: 3)
    }
}

private struct MockInterviewCompanyProgress: View {
    let progress: CompanyQuestProgress

    private let stageIDs = MockInterviewQuestStage.stageIDs

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Interview loop")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.cvQuestMuted)

                Spacer(minLength: 8)

                if progress.attempts == 0 {
                    Text("Not started")
                } else {
                    Text("\(progress.clearedStageIDs.count) of \(stageIDs.count) cleared · Best \(progress.bestScore)")
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.cvQuestMuted)

            HStack(spacing: 5) {
                ForEach(stageIDs, id: \.self) { stageID in
                    Capsule()
                        .fill(stageColor(for: stageID))
                        .frame(maxWidth: .infinity)
                        .frame(height: 6)
                }
            }

            if progress.attempts > 0 {
                Text("\(progress.attempts) \(progress.attempts == 1 ? "attempt" : "attempts")")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.cvQuestMuted)
            }
        }
        .padding(12)
        .background(Color.cvStudioAccentSoft.opacity(0.48), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func stageColor(for stageID: String) -> Color {
        if progress.hasCleared(stageID) { return Color.cvQuestSuccess }
        if progress.hasAttempted(stageID) { return Color.cvQuestWarning }
        return Color.cvSeparator
    }
}

private struct MockInterviewDifficultyBadge: View {
    let difficulty: Double

    private var tint: Color {
        difficulty >= 8 ? Color.cvQuestDanger : difficulty >= 6.5 ? Color.cvQuestWarning : Color.cvQuestSuccess
    }

    var body: some View {
        Label(difficulty.formatted(.number.precision(.fractionLength(0...1))) + "/10", systemImage: "chart.bar")
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(tint.opacity(0.09), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.42), lineWidth: 1))
    }
}

private struct MockInterviewEmptyState: View {
    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: "building.2")
                .font(.title2)
                .foregroundStyle(Color.cvQuestMuted)
            Text("No matching company guides")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.cvQuestInk)
            Text("Try a company name, interview topic, or system design keyword.")
                .font(.subheadline)
                .foregroundStyle(Color.cvQuestBody)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }
}

private struct MockInterviewQuestView: View {
    let guide: MobileInterviewGuideSummary
    @State private var progress = CompanyQuestProgress()

    private var stages: [MockInterviewQuestStage] {
        MockInterviewQuestStage.tracks(for: guide)
    }

    private var practiceJob: JobLead {
        JobLead(
            title: "Interview candidate",
            company: guide.company,
            matchScore: 100,
            stage: .interview,
            nextStep: "Continue \(guide.company) quest"
        )
    }

    private var nextStage: MockInterviewQuestStage? {
        stages.first { !progress.hasCleared($0.id) } ?? stages.last
    }

    var body: some View {
        ZStack {
            MockInterviewGridBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MockInterviewQuestHero(guide: guide, stages: stages, progress: progress)

                    VStack(spacing: 0) {
                        ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                            MockInterviewQuestStageRow(
                                guide: guide,
                                stage: stage,
                                index: index,
                                practiceJob: practiceJob,
                                progress: progress,
                                isNext: stage.id == nextStage?.id
                            )

                            if index < stages.count - 1 {
                                Divider().overlay(Color.cvQuestBorder)
                            }
                        }
                    }
                    .background(Color.cvQuestCard.opacity(0.98), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.cvQuestBorder, lineWidth: 1))
                }
                .padding(16)
                .padding(.bottom, 38)
            }
        }
        .navigationTitle("Interview Studio")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { progress = CompanyQuestProgressStore.progress(for: guide.company) }
    }
}

private struct MockInterviewQuestHero: View {
    let guide: MobileInterviewGuideSummary
    let stages: [MockInterviewQuestStage]
    let progress: CompanyQuestProgress

    private var nextStage: MockInterviewQuestStage? {
        stages.first { !progress.hasCleared($0.id) } ?? stages.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 8) {
                Label("INTERVIEW QUEST", systemImage: "figure.fencing")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                if let difficulty = guide.difficulty {
                    Divider().frame(height: 17)
                    Label(difficulty.formatted(.number.precision(.fractionLength(0...1))) + " / 10", systemImage: "chart.bar")
                        .font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(Color.cvQuestAmber)

            HStack(spacing: 13) {
                CompanyLogoMark(company: guide.company, slug: guide.slug, size: 58)
                Text("Beat the \(guide.company) interview loop")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.cvQuestInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(questDescription)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.cvQuestBody)
                .fixedSize(horizontal: false, vertical: true)

            MockInterviewQuestProgressBar(progress: progress, stageIDs: stages.map(\.id))

            NavigationLink {
                PracticeView(
                    initialJob: practiceJob,
                    initialCategory: nextStage?.category ?? .behavioral,
                    initialStageTitle: nextStage?.title,
                    guideSlug: guide.slug
                )
            } label: {
                Label("Continue · \(nextStage?.title ?? "Mock interview")", systemImage: "play")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(MockInterviewPrimaryButtonStyle())
        }
        .padding(18)
        .background(Color.cvQuestCard.opacity(0.96), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.cvQuestBorder, lineWidth: 1))
        .shadow(color: Color.cvQuestShadow, radius: 8, x: 0, y: 3)
    }

    private var practiceJob: JobLead {
        JobLead(title: "Interview candidate", company: guide.company, matchScore: 100, stage: .interview, nextStep: "Continue company quest")
    }

    private var questDescription: String {
        let sourcedStages = guide.stageCount == 0 ? "a curated company guide" : "\(guide.stageCount) sourced interview stages"
        return "\(sourcedStages), expanded into all \(stages.count) focused practice tracks. Score 75+ on each to clear your quest."
    }
}

private struct MockInterviewQuestProgressBar: View {
    let progress: CompanyQuestProgress
    let stageIDs: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your progress")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.cvQuestMuted)
                Spacer()
                Text("\(progress.clearedStageIDs.count) of \(stageIDs.count) stages cleared")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.cvQuestMuted)
            }

            HStack(spacing: 5) {
                ForEach(stageIDs, id: \.self) { stageID in
                    Capsule()
                        .fill(stageColor(for: stageID))
                        .frame(maxWidth: .infinity)
                        .frame(height: 7)
                }
            }

            if progress.attempts > 0 {
                Text("\(progress.attempts) \(progress.attempts == 1 ? "attempt" : "attempts") · Best score \(progress.bestScore)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.cvQuestMuted)
            }
        }
        .padding(12)
        .background(Color.cvStudioAccentSoft.opacity(0.48), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func stageColor(for stageID: String) -> Color {
        if progress.hasCleared(stageID) { return Color.cvQuestSuccess }
        if progress.hasAttempted(stageID) { return Color.cvQuestWarning }
        return Color.cvSeparator
    }
}

private struct MockInterviewQuestStage: Identifiable {
    let id: String
    let title: String
    let description: String
    let category: PracticeCategory
    let systemImage: String

    static let stageIDs = ["recruiter", "coding", "system-design", "behavioral", "values", "final"]

    static func tracks(for guide: MobileInterviewGuideSummary) -> [MockInterviewQuestStage] {
        let templates: [MockInterviewQuestStage] = [
            .init(id: "recruiter", title: "Recruiter screen", description: "Background, motivation, and role fit — make a clear first impression.", category: .behavioral, systemImage: "person.wave.2"),
            .init(id: "coding", title: "Coding round", description: "Technical problem solving in \(guide.company)'s interview style.", category: .technical, systemImage: "chevron.left.forwardslash.chevron.right"),
            .init(id: "system-design", title: "System design", description: "Architecture, trade-offs, and scale for a real product scenario.", category: .systemDesign, systemImage: "rectangle.3.group"),
            .init(id: "behavioral", title: "Behavioral round", description: "Past experience, teamwork, and impact — bring clear, concrete examples.", category: .behavioral, systemImage: "bubble.left.and.bubble.right"),
            .init(id: "values", title: "Values round", description: "Judgment, mission alignment, and how you make decisions under uncertainty.", category: .behavioral, systemImage: "heart.text.square"),
            .init(id: "final", title: "Final round", description: "Hiring-manager wrap-up — connect your judgment to the company mission.", category: .behavioral, systemImage: "flag.checkered")
        ]
        return templates
    }
}

private struct MockInterviewQuestStageRow: View {
    let guide: MobileInterviewGuideSummary
    let stage: MockInterviewQuestStage
    let index: Int
    let practiceJob: JobLead
    let progress: CompanyQuestProgress
    let isNext: Bool

    private var isCleared: Bool { progress.hasCleared(stage.id) }
    private var hasAttempt: Bool { progress.hasAttempted(stage.id) }
    private var score: Int? { progress.bestScore(for: stage.id) }
    private var statusText: String {
        isCleared ? "CLEARED" : isNext ? "UP NEXT" : hasAttempt ? "IN PROGRESS" : ""
    }
    private var actionLabel: String {
        isCleared ? "Practice again" : hasAttempt ? "Resume stage" : "Start stage"
    }
    private var actionSymbol: String {
        hasAttempt ? "arrow.clockwise" : stage.systemImage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: isCleared ? "checkmark" : "\(index + 1).circle")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isCleared ? Color.cvQuestSuccess : Color.cvStudioAccent)
                    .frame(width: 43, height: 43)
                    .background((isCleared ? Color.cvQuestSuccess : Color.cvStudioAccent).opacity(0.10), in: Circle())
                    .overlay(Circle().stroke((isCleared ? Color.cvQuestSuccess : Color.cvStudioAccent).opacity(0.18), lineWidth: 1))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(stage.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.cvQuestInk)
                        if !statusText.isEmpty {
                            Text(statusText)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(isCleared ? Color.cvQuestSuccess : Color.cvStudioAccent, in: Capsule())
                        }
                    }
                    Text(stage.description)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.cvQuestBody)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(stageProgressText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.cvQuestMuted)

                    if let score {
                        ProgressView(value: Double(score), total: 100)
                            .tint(isCleared ? Color.cvQuestSuccess : Color.cvQuestWarning)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            NavigationLink {
                PracticeView(
                    initialJob: practiceJob,
                    initialCategory: stage.category,
                    initialStageTitle: stage.title,
                    guideSlug: guide.slug
                )
            } label: {
                Label(actionLabel, systemImage: actionSymbol)
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            .buttonStyle(MockInterviewPrimaryButtonStyle())
        }
        .padding(16)
        .background(isNext ? Color.cvStudioAccentSoft.opacity(0.72) : Color.clear)
    }

    private var stageProgressText: String {
        guard hasAttempt else { return "Pass ≥ 75" }
        let attemptLabel = "\(progress.attempts(for: stage.id)) \(progress.attempts(for: stage.id) == 1 ? "attempt" : "attempts")"
        return "Pass ≥ 75 · Best \(score ?? 0) · \(attemptLabel)"
    }
}

private struct CompanyLogoMark: View {
    let company: String
    let slug: String
    let size: CGFloat

    var body: some View {
        AsyncImage(url: logoURL, transaction: Transaction(animation: .easeOut(duration: 0.18))) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.18)
            default:
                Text(String(company.prefix(1)).uppercased())
                    .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.cvQuestAmber)
            }
        }
        .frame(width: size, height: size)
        .background(.white, in: Circle())
        .overlay(Circle().stroke(Color.cvQuestBorder, lineWidth: 1))
        .shadow(color: Color.cvQuestShadow, radius: 4, x: 0, y: 2)
        .accessibilityLabel("\(company) logo")
    }

    private var logoURL: URL? {
        URL(string: "https://www.google.com/s2/favicons?domain=\(companyDomain)&sz=128")
    }

    private var companyDomain: String {
        let overrides = [
            "blizzard-activision": "blizzard.com", "scale-ai": "scale.com", "character-ai": "character.ai",
            "hugging-face": "huggingface.co", "fireworks-ai": "fireworks.ai", "1password": "1password.com",
            "23andme": "23andme.com", "apple-silicon-team": "apple.com", "xai": "x.ai"
        ]
        let base = slug.replacingOccurrences(of: "-interview-guide", with: "")
        if let override = overrides[base] { return override }
        return "\(base.replacingOccurrences(of: "-", with: "")).com"
    }
}

private struct MockInterviewGridBackground: View {
    var body: some View {
        Color.cvAppBackground.ignoresSafeArea()
    }
}

private struct MockInterviewPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(configuration.isPressed ? Color.cvStudioAccent.opacity(0.85) : Color.cvStudioAccent)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.cvStudioAccent.opacity(configuration.isPressed ? 0.08 : 0.18), radius: 8, x: 0, y: 3)
    }
}

private struct MockInterviewSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.cvStudioAccent)
            .background(Color.cvStudioAccentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.cvStudioAccent.opacity(0.22), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.76 : 1)
    }
}

private struct MockInterviewIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.cvQuestMuted)
            .background(Color.cvQuestPaper.opacity(0.95), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.cvQuestBorder.opacity(0.74), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.68 : 1)
    }
}

private extension MobileInterviewGuideSummary {
    var topicChips: [String] {
        MobileInterviewGuideCatalog.topicChips(for: slug)
    }

    var guideMetadata: String {
        var parts: [String] = []
        if questionCount > 0 { parts.append("\(questionCount) questions") }
        if stageCount > 0 { parts.append("\(stageCount) stages") }
        let tips = MobileInterviewGuideCatalog.tipCount(for: slug)
        if tips > 0 { parts.append("\(tips) tips") }
        return parts.isEmpty ? "Company guide overview" : parts.joined(separator: " · ")
    }

    var sourceURL: URL {
        URL(string: "https://www.techinterview.org/companies/\(slug)")!
    }
}

private extension Color {
    static let cvQuestPaper = Color.cvSurface
    static let cvQuestCard = Color.cvSurface
    static let cvQuestInk = Color.cvInk
    static let cvQuestBody = Color.cvInkSecondary
    static let cvQuestMuted = Color.cvInkSecondary
    static let cvQuestBorder = Color.cvSeparator
    static let cvQuestShadow = Color.black.opacity(0.05)
    static let cvQuestAmber = Color(red: 0.663, green: 0.475, blue: 0.208) // #A97935
    static let cvQuestSuccess = Color(red: 0.082, green: 0.502, blue: 0.239) // #15803D
    static let cvQuestWarning = Color(red: 0.851, green: 0.467, blue: 0.024) // #D97706
    static let cvQuestDanger = Color(red: 0.882, green: 0.114, blue: 0.282) // #E11D48
}
