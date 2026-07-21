import Foundation

struct InterviewSkillProfile: Codable, Equatable {
    let targetRole: String
    let currentSkills: Set<String>
    let growthDirection: String
    let experienceLevel: String?

    init(
        targetRole: String,
        currentSkills: Set<String>,
        growthDirection: String,
        experienceLevel: String? = nil
    ) {
        self.targetRole = targetRole
        self.currentSkills = currentSkills
        self.growthDirection = growthDirection
        self.experienceLevel = experienceLevel
    }

    var resolvedExperienceLevel: String {
        experienceLevel ?? "Mid-level"
    }
}

enum InterviewSkillProfileStore {
    private static let key = "cv_interview_skill_profile_v1"

    static func load() -> InterviewSkillProfile? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(InterviewSkillProfile.self, from: data)
    }

    static func save(_ profile: InterviewSkillProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

enum SkillRoleFamily: String, CaseIterable, Identifiable, Codable {
    case engineering = "Engineering"
    case product = "Product"
    case design = "Design"
    case data = "Data & AI"
    case people = "People"
    case growth = "Customer & Growth"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .engineering: return "chevron.left.forwardslash.chevron.right"
        case .product: return "shippingbox.fill"
        case .design: return "paintpalette.fill"
        case .data: return "chart.xyaxis.line"
        case .people: return "person.3.fill"
        case .growth: return "arrow.up.right"
        }
    }
}

struct SkillRoleOption: Identifiable, Hashable {
    let title: String
    let family: SkillRoleFamily
    let systemImage: String
    var id: String { title }
}

struct SkillProfileOption: Identifiable, Hashable {
    let title: String
    let category: String
    let systemImage: String
    let families: Set<SkillRoleFamily>
    var id: String { title }
}

enum SkillProfileCatalog {
    static let experienceLevels = ["Student / switching", "Entry-level", "Mid-level", "Senior", "Lead / manager"]

    static let roles: [SkillRoleOption] = [
        .init(title: "Software Engineer", family: .engineering, systemImage: "chevron.left.forwardslash.chevron.right"),
        .init(title: "Frontend Engineer", family: .engineering, systemImage: "macwindow"),
        .init(title: "Full-stack Engineer", family: .engineering, systemImage: "square.stack.3d.up.fill"),
        .init(title: "Backend Engineer", family: .engineering, systemImage: "server.rack"),
        .init(title: "iOS Engineer", family: .engineering, systemImage: "iphone"),
        .init(title: "DevOps / SRE", family: .engineering, systemImage: "cloud.fill"),
        .init(title: "Security Engineer", family: .engineering, systemImage: "lock.shield.fill"),
        .init(title: "Engineering Manager", family: .engineering, systemImage: "person.2.fill"),
        .init(title: "Product Manager", family: .product, systemImage: "map.fill"),
        .init(title: "Technical PM", family: .product, systemImage: "gearshape.2.fill"),
        .init(title: "AI Product Manager", family: .product, systemImage: "sparkles"),
        .init(title: "Product Operations", family: .product, systemImage: "checklist"),
        .init(title: "Product Designer", family: .design, systemImage: "paintbrush.pointed.fill"),
        .init(title: "UX Researcher", family: .design, systemImage: "person.crop.circle.badge.questionmark"),
        .init(title: "UX / UI Designer", family: .design, systemImage: "rectangle.3.group.fill"),
        .init(title: "Design Lead", family: .design, systemImage: "wand.and.stars"),
        .init(title: "Data Scientist", family: .data, systemImage: "function"),
        .init(title: "Data Analyst", family: .data, systemImage: "chart.bar.fill"),
        .init(title: "Data Engineer", family: .data, systemImage: "cylinder.split.1x2.fill"),
        .init(title: "ML / AI Engineer", family: .data, systemImage: "brain.head.profile.fill"),
        .init(title: "Recruiter", family: .people, systemImage: "person.crop.circle.badge.plus"),
        .init(title: "Technical Recruiter", family: .people, systemImage: "person.text.rectangle.fill"),
        .init(title: "People Operations", family: .people, systemImage: "person.3.sequence.fill"),
        .init(title: "Talent Lead", family: .people, systemImage: "person.badge.shield.checkmark.fill"),
        .init(title: "Solutions Engineer", family: .growth, systemImage: "lightbulb.max.fill"),
        .init(title: "Sales Engineer", family: .growth, systemImage: "briefcase.fill"),
        .init(title: "Customer Success", family: .growth, systemImage: "hands.sparkles.fill"),
        .init(title: "Growth Marketer", family: .growth, systemImage: "megaphone.fill")
    ]

    static let skills: [SkillProfileOption] = [
        option("React", "Engineering", "atom", [.engineering]),
        option("Node.js", "Engineering", "network", [.engineering]),
        option("TypeScript", "Engineering", "curlybraces", [.engineering]),
        option("Python", "Engineering", "chevron.left.forwardslash.chevron.right", [.engineering, .data]),
        option("Swift / SwiftUI", "Engineering", "swift", [.engineering]),
        option("Java / Kotlin", "Engineering", "cup.and.saucer.fill", [.engineering]),
        option("API Design", "Engineering", "point.3.connected.trianglepath.dotted", [.engineering, .product]),
        option("System Design", "Architecture", "rectangle.3.group", [.engineering, .data]),
        option("Distributed Systems", "Architecture", "server.rack", [.engineering, .data]),
        option("AWS", "Cloud", "cloud.fill", [.engineering, .data]),
        option("Google Cloud", "Cloud", "cloud.sun.fill", [.engineering, .data]),
        option("Azure", "Cloud", "cloud.bolt.fill", [.engineering, .data]),
        option("Kubernetes", "Cloud", "shippingbox.fill", [.engineering]),
        option("CI/CD", "Cloud", "arrow.triangle.2.circlepath", [.engineering]),
        option("Observability", "Cloud", "waveform.path.ecg", [.engineering, .data]),
        option("SQL", "Data", "cylinder.fill", [.engineering, .data, .product]),
        option("Data Modeling", "Data", "tablecells.fill", [.engineering, .data]),
        option("Experimentation", "Data", "flask.fill", [.data, .product, .growth]),
        option("Machine Learning", "AI", "brain.head.profile.fill", [.data, .engineering, .product]),
        option("LLM / RAG", "AI", "sparkles", [.data, .engineering, .product]),
        option("AI Coding Tools", "AI", "wand.and.stars", [.engineering, .data]),
        option("AI Product Judgment", "AI", "checkmark.seal.fill", [.product, .design, .engineering]),
        option("Product Strategy", "Product", "map.fill", [.product, .growth]),
        option("Roadmapping", "Product", "point.topleft.down.to.point.bottomright.curvepath", [.product]),
        option("Prioritization", "Product", "list.number", [.product, .design, .people, .growth]),
        option("Product Analytics", "Product", "chart.line.uptrend.xyaxis", [.product, .data, .growth]),
        option("User Research", "Design", "person.crop.circle.badge.questionmark", [.design, .product]),
        option("Prototyping", "Design", "square.on.square", [.design, .product]),
        option("Design Systems", "Design", "square.grid.3x3.fill", [.design, .engineering]),
        option("Interaction Design", "Design", "hand.tap.fill", [.design]),
        option("Accessibility", "Design", "accessibility", [.design, .engineering, .product]),
        option("Sourcing", "Recruiting", "magnifyingglass", [.people]),
        option("Structured Interviews", "Recruiting", "list.clipboard.fill", [.people]),
        option("Candidate Experience", "Recruiting", "heart.fill", [.people]),
        option("Talent Analytics", "Recruiting", "chart.bar.xaxis", [.people, .data]),
        option("Customer Discovery", "Customer", "bubble.left.and.text.bubble.right.fill", [.growth, .product, .design]),
        option("Solution Architecture", "Customer", "puzzlepiece.extension.fill", [.growth, .engineering]),
        option("Consultative Selling", "Customer", "person.line.dotted.person.fill", [.growth]),
        option("Lifecycle Marketing", "Growth", "paperplane.fill", [.growth]),
        option("Growth Experiments", "Growth", "arrow.up.forward.circle.fill", [.growth, .product]),
        option("Leadership", "Leadership", "star.fill", Set(SkillRoleFamily.allCases)),
        option("Stakeholder Management", "Leadership", "person.3.fill", Set(SkillRoleFamily.allCases)),
        option("Communication", "Leadership", "bubble.left.and.bubble.right.fill", Set(SkillRoleFamily.allCases)),
        option("Decision Making", "Leadership", "arrow.triangle.branch", Set(SkillRoleFamily.allCases))
    ]

    static func roles(in family: SkillRoleFamily) -> [SkillRoleOption] {
        roles.filter { $0.family == family }
    }

    static func family(for role: String) -> SkillRoleFamily {
        roles.first(where: { $0.title == role })?.family ?? .engineering
    }

    static func recommendedSkills(for role: String) -> [SkillProfileOption] {
        let family = family(for: role)
        let direct = skills.filter { $0.families.contains(family) }
        let universal = skills.filter { $0.category == "Leadership" }
        return Array((direct + universal).uniqued(by: \.title).prefix(12))
    }

    static func defaultSkills(for role: String) -> Set<String> {
        switch role {
        case "Software Engineer": return ["TypeScript", "API Design", "System Design"]
        case "Frontend Engineer": return ["React", "TypeScript", "Accessibility"]
        case "Full-stack Engineer": return ["React", "Node.js", "API Design"]
        case "Backend Engineer": return ["Node.js", "API Design", "SQL"]
        case "iOS Engineer": return ["Swift / SwiftUI", "API Design", "Accessibility"]
        case "DevOps / SRE": return ["AWS", "Kubernetes", "CI/CD"]
        case "Security Engineer": return ["System Design", "Observability", "AWS"]
        case "Engineering Manager": return ["Leadership", "Stakeholder Management", "Communication"]
        case "Product Manager": return ["Product Strategy", "Roadmapping", "Product Analytics"]
        case "Technical PM": return ["Product Strategy", "System Design", "Prioritization"]
        case "AI Product Manager": return ["AI Product Judgment", "Product Strategy", "LLM / RAG"]
        case "Product Operations": return ["Product Analytics", "Roadmapping", "Stakeholder Management"]
        case "Product Designer": return ["User Research", "Prototyping", "Interaction Design"]
        case "UX Researcher": return ["User Research", "Product Analytics", "Communication"]
        case "UX / UI Designer": return ["Design Systems", "Interaction Design", "Prototyping"]
        case "Design Lead": return ["Design Systems", "Leadership", "Stakeholder Management"]
        case "Data Scientist": return ["Python", "Machine Learning", "Experimentation"]
        case "Data Analyst": return ["SQL", "Product Analytics", "Data Modeling"]
        case "Data Engineer": return ["SQL", "Data Modeling", "Google Cloud"]
        case "ML / AI Engineer": return ["Python", "Machine Learning", "LLM / RAG"]
        case "Recruiter": return ["Sourcing", "Structured Interviews", "Candidate Experience"]
        case "Technical Recruiter": return ["Sourcing", "Structured Interviews", "Talent Analytics"]
        case "People Operations": return ["Candidate Experience", "Talent Analytics", "Stakeholder Management"]
        case "Talent Lead": return ["Leadership", "Sourcing", "Structured Interviews"]
        case "Solutions Engineer": return ["Solution Architecture", "API Design", "Customer Discovery"]
        case "Sales Engineer": return ["Solution Architecture", "Consultative Selling", "Customer Discovery"]
        case "Customer Success": return ["Customer Discovery", "Stakeholder Management", "Consultative Selling"]
        case "Growth Marketer": return ["Lifecycle Marketing", "Growth Experiments", "Product Analytics"]
        default: return ["Communication", "Stakeholder Management"]
        }
    }

    static func growthDirections(for role: String) -> [String] {
        switch family(for: role) {
        case .engineering: return ["Cloud & scale", "AI products", "Big Tech interviews", "Technical leadership"]
        case .product: return ["Product strategy", "AI products", "Growth & experimentation", "Product leadership"]
        case .design: return ["Product craft", "Design systems", "UX research", "Design leadership"]
        case .data: return ["Data & analytics", "ML systems", "AI products", "Technical leadership"]
        case .people: return ["Talent strategy", "Technical recruiting", "Candidate experience", "People leadership"]
        case .growth: return ["Customer & growth", "Solution strategy", "Product fluency", "Team leadership"]
        }
    }

    private static func option(
        _ title: String,
        _ category: String,
        _ systemImage: String,
        _ families: Set<SkillRoleFamily>
    ) -> SkillProfileOption {
        .init(title: title, category: category, systemImage: systemImage, families: families)
    }
}

private extension Array {
    func uniqued<Key: Hashable>(by keyPath: KeyPath<Element, Key>) -> [Element] {
        var seen = Set<Key>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}

struct PersonalizedPracticeContent: Hashable {
    let questions: [String]
    let coachingHint: String
    let sourceLabel: String
}

struct PracticeRoute: Identifiable, Hashable {
    let company: String
    let guideSlug: String
    let jobTitle: String
    let category: PracticeCategory
    let stageTitle: String
    let personalizedContent: PersonalizedPracticeContent?
    let skillTreeProgressID: String?

    init(
        company: String,
        guideSlug: String,
        jobTitle: String,
        category: PracticeCategory,
        stageTitle: String,
        personalizedContent: PersonalizedPracticeContent? = nil,
        skillTreeProgressID: String? = nil
    ) {
        self.company = company
        self.guideSlug = guideSlug
        self.jobTitle = jobTitle
        self.category = category
        self.stageTitle = stageTitle
        self.personalizedContent = personalizedContent
        self.skillTreeProgressID = skillTreeProgressID
    }

    var id: String { skillTreeProgressID ?? [guideSlug, stageTitle, category.rawValue].joined(separator: "|") }

    var job: JobLead {
        JobLead(
            title: jobTitle,
            company: personalizedContent == nil ? company : jobTitle,
            matchScore: 100,
            stage: .interview,
            nextStep: "Continue your skill tree"
        )
    }
}

struct SkillChallenge: Identifiable, Hashable {
    let id: String
    let skill: String
    let title: String
    let subtitle: String
    let systemImage: String
    let route: PracticeRoute
    let isBoss: Bool
}

enum SkillChallengeTreeBuilder {
    static func challenges(for profile: InterviewSkillProfile) -> [SkillChallenge] {
        let family = SkillProfileCatalog.family(for: profile.targetRole)
        let baseline = baselineChallenge(for: profile, family: family)
        var candidates = recommendations(for: profile, family: family)
            .filter { !profile.currentSkills.contains($0.skill) }

        if candidates.count < 3 {
            candidates.append(contentsOf: recommendations(for: profile, family: family).filter { item in
                !candidates.contains(where: { $0.id == item.id })
            })
        }

        let collaboration = collaborationChallenge(for: family)
        let boss = bossChallenge(for: profile, family: family)
        return ([baseline] + Array(candidates.prefix(3)) + [collaboration, boss]).map {
            personalized($0, for: profile)
        }
    }

    private static func baselineChallenge(for profile: InterviewSkillProfile, family: SkillRoleFamily) -> SkillChallenge {
        challenge(
            id: "story", skill: "Role story", title: "Tell your \(family.rawValue.lowercased()) story",
            subtitle: "Connect your \(profile.resolvedExperienceLevel.lowercased()) experience to the role in a clear opening answer.",
            icon: "person.wave.2", company: "Google", slug: "google", stage: "Recruiter screen", category: .behavioral
        )
    }

    private static func recommendations(for profile: InterviewSkillProfile, family: SkillRoleFamily) -> [SkillChallenge] {
        switch family {
        case .product:
            return [
                challenge(id: "product-judgment", skill: "Product Strategy", title: "Prioritize a product decision", subtitle: "Balance user value, business goals, evidence, and constraints.", icon: "map.fill", company: "Figma", slug: "figma", stage: "Values round", category: .behavioral),
                challenge(id: "product-metrics", skill: "Product Analytics", title: "Define product success", subtitle: "Choose metrics that reveal impact without hiding trade-offs.", icon: "chart.line.uptrend.xyaxis", company: "Stripe", slug: "stripe", stage: "Behavioral round", category: .behavioral),
                challenge(id: "product-ai", skill: "AI Product Judgment", title: "Frame an AI product bet", subtitle: "Explain quality, safety, latency, and user trust.", icon: "sparkles", company: "OpenAI", slug: "openai", stage: "Values round", category: .behavioral),
                challenge(id: "product-influence", skill: "Stakeholder Management", title: "Align a divided team", subtitle: "Move a product decision forward without direct authority.", icon: "person.3.fill", company: "Google", slug: "google", stage: "Behavioral round", category: .behavioral)
            ]
        case .design:
            return [
                challenge(id: "design-craft", skill: "Interaction Design", title: "Defend a design decision", subtitle: "Connect user evidence to the interaction you chose.", icon: "hand.tap.fill", company: "Figma", slug: "figma", stage: "Behavioral round", category: .behavioral),
                challenge(id: "design-research", skill: "User Research", title: "Turn research into direction", subtitle: "Show how an insight changed the product.", icon: "person.crop.circle.badge.questionmark", company: "Google", slug: "google", stage: "Behavioral round", category: .behavioral),
                challenge(id: "design-system", skill: "Design Systems", title: "Scale a design system", subtitle: "Explain adoption, governance, and measurable consistency.", icon: "square.grid.3x3.fill", company: "Figma", slug: "figma", stage: "Values round", category: .behavioral),
                challenge(id: "design-access", skill: "Accessibility", title: "Design for more people", subtitle: "Make inclusive decisions visible and specific.", icon: "accessibility", company: "Microsoft", slug: "microsoft", stage: "Behavioral round", category: .behavioral)
            ]
        case .data:
            return [
                challenge(id: "data-sql", skill: "SQL", title: "Reason with production data", subtitle: "Work through a real data problem and defend your approach.", icon: "cylinder.fill", company: "Databricks", slug: "databricks", stage: "Coding round", category: .technical),
                challenge(id: "data-quality", skill: "Data Modeling", title: "Build for data quality", subtitle: "Handle constraints, drift, and unreliable inputs.", icon: "tablecells.fill", company: "Scale AI", slug: "scale-ai", stage: "Coding round", category: .technical),
                challenge(id: "data-experiment", skill: "Experimentation", title: "Design a trustworthy experiment", subtitle: "Choose metrics, guardrails, and a decision threshold.", icon: "flask.fill", company: "Google", slug: "google", stage: "Behavioral round", category: .behavioral),
                challenge(id: "ml-system", skill: "Machine Learning", title: "Design an ML system", subtitle: "Make model, data, serving, and monitoring trade-offs visible.", icon: "brain.head.profile.fill", company: "OpenAI", slug: "openai", stage: "System design", category: .systemDesign)
            ]
        case .people:
            return [
                challenge(id: "talent-source", skill: "Sourcing", title: "Build a focused talent strategy", subtitle: "Translate a hiring need into a credible search plan.", icon: "magnifyingglass", company: "LinkedIn", slug: "linkedin", stage: "Recruiter screen", category: .behavioral),
                challenge(id: "talent-interview", skill: "Structured Interviews", title: "Run a fair interview loop", subtitle: "Create consistent evidence and reduce avoidable bias.", icon: "list.clipboard.fill", company: "Google", slug: "google", stage: "Behavioral round", category: .behavioral),
                challenge(id: "candidate", skill: "Candidate Experience", title: "Protect candidate trust", subtitle: "Communicate clearly when priorities or timelines change.", icon: "heart.fill", company: "Stripe", slug: "stripe", stage: "Values round", category: .behavioral),
                challenge(id: "talent-data", skill: "Talent Analytics", title: "Use hiring data responsibly", subtitle: "Turn funnel signals into a practical improvement plan.", icon: "chart.bar.xaxis", company: "LinkedIn", slug: "linkedin", stage: "Behavioral round", category: .behavioral)
            ]
        case .growth:
            return [
                challenge(id: "customer-discovery", skill: "Customer Discovery", title: "Uncover the real customer need", subtitle: "Ask precise questions and turn evidence into action.", icon: "bubble.left.and.text.bubble.right.fill", company: "Salesforce", slug: "salesforce", stage: "Recruiter screen", category: .behavioral),
                challenge(id: "solution", skill: "Solution Architecture", title: "Explain a credible solution", subtitle: "Connect technical constraints to customer outcomes.", icon: "puzzlepiece.extension.fill", company: "Stripe", slug: "stripe", stage: "Values round", category: .behavioral),
                challenge(id: "consultative", skill: "Consultative Selling", title: "Handle a difficult objection", subtitle: "Preserve trust while moving the decision forward.", icon: "person.line.dotted.person.fill", company: "HubSpot", slug: "hubspot", stage: "Behavioral round", category: .behavioral),
                challenge(id: "growth", skill: "Growth Experiments", title: "Design a growth experiment", subtitle: "Tie a clear hypothesis to metrics and guardrails.", icon: "arrow.up.forward.circle.fill", company: "Airbnb", slug: "airbnb", stage: "Behavioral round", category: .behavioral)
            ]
        case .engineering:
            return engineeringRecommendations(for: profile.growthDirection)
        }
    }

    private static func engineeringRecommendations(for direction: String) -> [SkillChallenge] {
        if direction == "AI products" {
            return [
                challenge(id: "ai-judgment", skill: "AI Product Judgment", title: "Explain AI product trade-offs", subtitle: "Balance quality, safety, latency, and user value.", icon: "sparkles", company: "OpenAI", slug: "openai", stage: "Values round", category: .behavioral),
                challenge(id: "ai-systems", skill: "System Design", title: "Design an AI product system", subtitle: "Make scale, reliability, and model boundaries visible.", icon: "server.rack", company: "OpenAI", slug: "openai", stage: "System design", category: .systemDesign),
                challenge(id: "ai-coding", skill: "AI Coding Tools", title: "Ship with AI coding tools", subtitle: "Demonstrate technical depth beyond tool usage.", icon: "wand.and.stars", company: "Anthropic", slug: "anthropic", stage: "Coding round", category: .technical),
                challenge(id: "backend", skill: "Node.js", title: "Build a reliable backend", subtitle: "Practice implementation details and failure handling.", icon: "network", company: "Scale AI", slug: "scale-ai", stage: "Coding round", category: .technical)
            ]
        }
        if direction == "Big Tech interviews" {
            return [
                challenge(id: "coding", skill: "Algorithms", title: "Strengthen coding fundamentals", subtitle: "Work through a real company-style coding challenge.", icon: "chevron.left.forwardslash.chevron.right", company: "Google", slug: "google", stage: "Coding round", category: .technical),
                challenge(id: "system", skill: "System Design", title: "Design at product scale", subtitle: "Clarify requirements and defend important trade-offs.", icon: "server.rack", company: "Google", slug: "google", stage: "System design", category: .systemDesign),
                challenge(id: "frontend", skill: "React", title: "Show frontend product depth", subtitle: "Connect implementation choices to product behavior.", icon: "macwindow", company: "Figma", slug: "figma", stage: "Coding round", category: .technical),
                challenge(id: "leadership", skill: "Leadership", title: "Demonstrate ownership", subtitle: "Use evidence to show judgment and impact.", icon: "star.fill", company: "Google", slug: "google", stage: "Behavioral round", category: .behavioral)
            ]
        }
        if direction == "Technical leadership" {
            return [
                challenge(id: "architecture", skill: "System Design", title: "Own an architecture decision", subtitle: "Explain constraints, alternatives, and long-term consequences.", icon: "rectangle.3.group", company: "Stripe", slug: "stripe", stage: "System design", category: .systemDesign),
                challenge(id: "influence", skill: "Leadership", title: "Influence without authority", subtitle: "Align teams and move a decision forward.", icon: "person.3.fill", company: "Google", slug: "google", stage: "Behavioral round", category: .behavioral),
                challenge(id: "values", skill: "Decision Making", title: "Make values visible", subtitle: "Practice judgment under uncertainty.", icon: "heart.text.square.fill", company: "Anthropic", slug: "anthropic", stage: "Values round", category: .behavioral),
                challenge(id: "scale", skill: "Distributed Systems", title: "Design for operational scale", subtitle: "Cover reliability, observability, and graceful failure.", icon: "cloud.fill", company: "Amazon", slug: "amazon", stage: "System design", category: .systemDesign)
            ]
        }
        return [
            challenge(id: "aws", skill: "AWS", title: "Design for cloud scale", subtitle: "Practice reliability, storage, and traffic trade-offs.", icon: "cloud.fill", company: "Amazon", slug: "amazon", stage: "System design", category: .systemDesign),
            challenge(id: "gcp", skill: "Google Cloud", title: "Reason about distributed systems", subtitle: "Explain scale and failure modes clearly.", icon: "network", company: "Google", slug: "google", stage: "System design", category: .systemDesign),
            challenge(id: "system", skill: "System Design", title: "Build architecture confidence", subtitle: "Turn requirements into a defendable system design.", icon: "rectangle.3.group", company: "Stripe", slug: "stripe", stage: "System design", category: .systemDesign),
            challenge(id: "tools", skill: "AI Coding Tools", title: "Show engineering depth with AI", subtitle: "Connect AI-assisted delivery to quality and ownership.", icon: "sparkles", company: "OpenAI", slug: "openai", stage: "Values round", category: .behavioral)
        ]
    }

    private static func collaborationChallenge(for family: SkillRoleFamily) -> SkillChallenge {
        let title = family == .people ? "Partner with a hiring manager" : family == .growth ? "Align customer and product teams" : "Lead through ambiguity"
        return challenge(id: "collaboration", skill: "Communication", title: title, subtitle: "Practice decisions, trade-offs, and cross-team communication.", icon: "bubble.left.and.bubble.right.fill", company: "Google", slug: "google", stage: "Behavioral round", category: .behavioral)
    }

    private static func bossChallenge(for profile: InterviewSkillProfile, family: SkillRoleFamily) -> SkillChallenge {
        let destination: (String, String) = switch family {
        case .product, .design: ("Figma", "figma")
        case .data: ("Databricks", "databricks")
        case .people: ("LinkedIn", "linkedin")
        case .growth: ("Salesforce", "salesforce")
        case .engineering: profile.growthDirection == "AI products" ? ("OpenAI", "openai") : ("Google", "google")
        }
        return challenge(id: "boss", skill: "Role readiness", title: "Boss interview", subtitle: "Bring your judgment, evidence, and career story together.", icon: "flag.checkered", company: destination.0, slug: destination.1, stage: "Final round", category: .behavioral, isBoss: true)
    }

    private static func challenge(id: String, skill: String, title: String, subtitle: String, icon: String, company: String, slug: String, stage: String, category: PracticeCategory, isBoss: Bool = false) -> SkillChallenge {
        SkillChallenge(id: id, skill: skill, title: title, subtitle: subtitle, systemImage: icon, route: .init(company: company, guideSlug: slug, jobTitle: "\(company) candidate", category: category, stageTitle: stage), isBoss: isBoss)
    }

    private static func personalized(_ challenge: SkillChallenge, for profile: InterviewSkillProfile) -> SkillChallenge {
        let route = PracticeRoute(
            company: challenge.route.company,
            guideSlug: challenge.route.guideSlug,
            jobTitle: profile.targetRole,
            category: challenge.route.category,
            stageTitle: challenge.route.stageTitle,
            personalizedContent: SkillChallengeQuestionFactory.content(for: challenge, profile: profile),
            skillTreeProgressID: "skill-tree|\(profile.targetRole.lowercased())|\(challenge.id)"
        )
        return SkillChallenge(
            id: challenge.id,
            skill: challenge.skill,
            title: challenge.title,
            subtitle: challenge.subtitle,
            systemImage: challenge.systemImage,
            route: route,
            isBoss: challenge.isBoss
        )
    }
}

enum SkillChallengeQuestionFactory {
    static func content(for challenge: SkillChallenge, profile: InterviewSkillProfile) -> PersonalizedPracticeContent {
        let role = profile.targetRole
        let experience = profile.resolvedExperienceLevel.lowercased()
        let skills = profile.currentSkills.sorted()
        let foundation = skills.first ?? "your strongest skill"
        let supportingSkill = skills.dropFirst().first ?? challenge.skill
        let source = "Personalized for \(role) • built from \(challenge.route.company) interview themes"

        switch challenge.route.category {
        case .technical:
            return .init(
                questions: [
                    "As a \(role), walk through how you would solve a \(challenge.skill) problem. Start with the requirements you would clarify, then explain your approach and trade-offs.",
                    "How would you use \(foundation) with \(challenge.skill) to build a reliable solution? Explain the key implementation decisions and how you would test them.",
                    "A teammate proposes a simpler implementation that could fail at scale. How would you compare it with your approach and make the decision?"
                ],
                coachingHint: "Make your approach concrete: clarify constraints, explain the trade-off, then show how you would validate the result.",
                sourceLabel: source
            )
        case .systemDesign:
            return .init(
                questions: [
                    "You are a \(role) improving \(challenge.skill) for a growing product. What requirements would you clarify before proposing the architecture?",
                    "Design the core flow using \(foundation) and \(supportingSkill). Explain the components, data flow, and the first reliability trade-off you would make.",
                    "Traffic grows tenfold after launch. What would you change first, and how would you know the system is still meeting the user need?"
                ],
                coachingHint: "State assumptions first, make the request flow visible, and name one reliability or scale trade-off you would revisit.",
                sourceLabel: source
            )
        case .leadership:
            return leadershipContent(role: role, skill: challenge.skill, experience: experience, source: source)
        case .behavioral:
            return behavioralContent(
                role: role,
                skill: challenge.skill,
                experience: experience,
                currentSkill: foundation,
                isRoleStory: challenge.id == "story",
                source: source
            )
        }
    }

    private static func behavioralContent(
        role: String,
        skill: String,
        experience: String,
        currentSkill: String,
        isRoleStory: Bool,
        source: String
    ) -> PersonalizedPracticeContent {
        let roleArticle = role.lowercased().hasPrefix("ios") ? "an" : "a"
        let openingQuestion = isRoleStory
            ? "Tell me about the path that prepared you for \(roleArticle) \(role) role. Which \(currentSkill) experience best shows how you work, what you owned, and the impact you had?"
            : "For \(roleArticle) \(role) role, tell me about a \(experience) project or situation where you used \(skill). What was the context, what decision did you own, and what changed?"

        return .init(
            questions: [
                openingQuestion,
                "Tell me about a time \(currentSkill) helped you handle a difficult constraint. How did you choose what to prioritize?",
                "What would make a hiring team confident that you can grow from \(currentSkill) into stronger \(skill) ownership? Use one specific example."
            ],
            coachingHint: "Use one focused story: context, your decision, evidence of impact, and what you learned for the next challenge.",
            sourceLabel: source
        )
    }

    private static func leadershipContent(role: String, skill: String, experience: String, source: String) -> PersonalizedPracticeContent {
        .init(
            questions: [
                "As a \(role), tell me about a time you used \(skill) to align people with different priorities. What did you do and what changed?",
                "Describe a decision you made with incomplete information. How did you create clarity for the team and protect the outcome?",
                "What is one leadership behavior you are deliberately building at the \(experience) level, and how have you practiced it recently?"
            ],
            coachingHint: "Show how you created alignment, made a judgment call, and measured the effect on people or outcomes.",
            sourceLabel: source
        )
    }
}

struct SkillTreeChallengeProgress: Codable, Equatable {
    var attempts = 0
    var bestScore = 0
    var isCleared = false
}

enum SkillTreeChallengeProgressStore {
    private static let key = "cv_skill_tree_challenge_progress_v1"

    static func progress(for id: String) -> SkillTreeChallengeProgress {
        all()[id] ?? SkillTreeChallengeProgress()
    }

    static func record(id: String, score: Int) {
        var values = all()
        var value = values[id] ?? SkillTreeChallengeProgress()
        value.attempts += 1
        value.bestScore = max(value.bestScore, score)
        value.isCleared = value.isCleared || score >= 75
        values[id] = value
        guard let data = try? JSONEncoder().encode(values) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func all() -> [String: SkillTreeChallengeProgress] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: SkillTreeChallengeProgress].self, from: data)) ?? [:]
    }

    /// Clears all saved challenge progress. Used when deleting the account.
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
