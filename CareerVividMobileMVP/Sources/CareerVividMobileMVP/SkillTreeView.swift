import SwiftUI

private enum SkillTreePalette {
    static let accents: [Color] = [
        .cvStudioAccent,
        .cvBlue,
        .cvGreen,
        .cvBrandWarm,
        .cvPink,
        .cvYellow
    ]

    static let softs: [Color] = [
        .cvStudioAccentSoft,
        .cvBlueSoft,
        .cvGreenSoft,
        .cvBrandSoft,
        .cvPinkSoft,
        .cvYellowSoft
    ]

    static func accent(at index: Int) -> Color {
        accents[abs(index) % accents.count]
    }

    static func soft(at index: Int) -> Color {
        softs[abs(index) % softs.count]
    }
}

struct SkillTreeView: View {
    @State private var profile: InterviewSkillProfile? = InterviewSkillProfileStore.load()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cvAppBackground.ignoresSafeArea()

                if let profile {
                    SkillTreePathView(profile: profile, onEditProfile: resetProfile)
                } else {
                    SkillProfileSetupView(onSave: saveProfile)
                }
            }
            .navigationTitle("Skill Tree")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: PracticeRoute.self) { route in
                PracticeView(
                    initialJob: route.job,
                    initialCategory: route.category,
                    initialStageTitle: route.stageTitle,
                    guideSlug: route.guideSlug,
                    personalizedContent: route.personalizedContent,
                    skillTreeProgressID: route.skillTreeProgressID
                )
            }
        }
    }

    private func saveProfile(_ profile: InterviewSkillProfile) {
        InterviewSkillProfileStore.save(profile)
        withAnimation(.easeInOut(duration: 0.24)) {
            self.profile = profile
        }
    }

    private func resetProfile() {
        InterviewSkillProfileStore.clear()
        withAnimation(.easeInOut(duration: 0.24)) {
            profile = nil
        }
    }
}

private struct SkillProfileSetupView: View {
    let onSave: (InterviewSkillProfile) -> Void
    @State private var roleFamily: SkillRoleFamily = .engineering
    @State private var targetRole = "Software Engineer"
    @State private var currentSkills = SkillProfileCatalog.defaultSkills(for: "Software Engineer")
    @State private var experienceLevel = "Mid-level"
    @State private var growthDirection = "Cloud & scale"
    @State private var showSkillLibrary = false

    private var roles: [SkillRoleOption] { SkillProfileCatalog.roles(in: roleFamily) }
    private var recommendedSkills: [SkillProfileOption] { SkillProfileCatalog.recommendedSkills(for: targetRole) }
    private var directions: [String] { SkillProfileCatalog.growthDirections(for: targetRole) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                SkillProfileIntro()
                SkillRoleSection(
                    family: $roleFamily,
                    targetRole: $targetRole,
                    experienceLevel: $experienceLevel,
                    roles: roles,
                    onFamilyChange: selectFamily
                )
                SkillProfileMultiChoiceSection(
                    title: "2. What can you already use confidently?",
                    choices: recommendedSkills,
                    selection: $currentSkills,
                    recommendationLabel: "Recommended for \(targetRole) — adjust anything that is not true for you.",
                    onBrowseAll: { showSkillLibrary = true }
                )
                SkillProfileChoiceSection(
                    title: "3. What do you want to build next?",
                    choices: directions,
                    selection: $growthDirection,
                    paletteOffset: 3
                )
                AnimatedBuildTreeButton(action: buildTree)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, CVLayout.floatingTabContentPadding)
        }
        .sheet(isPresented: $showSkillLibrary) {
            SkillLibrarySheet(selection: $currentSkills)
        }
        .onChange(of: targetRole) { _, role in
            let availableDirections = SkillProfileCatalog.growthDirections(for: role)
            withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
                currentSkills = SkillProfileCatalog.defaultSkills(for: role)
                if !availableDirections.contains(growthDirection), let first = availableDirections.first {
                    growthDirection = first
                }
            }
        }
    }

    private func selectFamily(_ family: SkillRoleFamily) {
        let firstRole = SkillProfileCatalog.roles(in: family).first?.title ?? targetRole
        let firstDirection = SkillProfileCatalog.growthDirections(for: firstRole).first ?? growthDirection
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            roleFamily = family
            targetRole = firstRole
            growthDirection = firstDirection
        }
        cvImpactHaptic(.light)
    }

    private func buildTree() {
        cvImpactHaptic(.medium)
        onSave(
            InterviewSkillProfile(
                targetRole: targetRole,
                currentSkills: currentSkills,
                growthDirection: growthDirection,
                experienceLevel: experienceLevel
            )
        )
    }
}

private struct SkillProfileIntro: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SkillTreeAnimatedMark()
            VStack(alignment: .leading, spacing: 7) {
                Text("Build the skills your next role needs")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.cvInk)
                Text("Choose your profile. Vivid will turn real company interviews into a focused challenge path.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.cvInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .background(Color.cvSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.cvHairline, lineWidth: 1))
    }
}

private struct SkillTreeAnimatedMark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let rotation = reduceMotion ? 0 : time.truncatingRemainder(dividingBy: 5) / 5 * 360
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: SkillTreePalette.accents + [SkillTreePalette.accents[0]],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [20, 8])
                    )
                    .rotationEffect(.degrees(rotation))
                Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.cvStudioAccent)
            }
            .frame(width: 54, height: 54)
            .background(Color.cvStudioAccentSoft, in: Circle())
        }
    }
}

private struct SkillRoleSection: View {
    @Binding var family: SkillRoleFamily
    @Binding var targetRole: String
    @Binding var experienceLevel: String
    let roles: [SkillRoleOption]
    let onFamilyChange: (SkillRoleFamily) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("1. Who are you becoming?")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.cvInk)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(Array(SkillRoleFamily.allCases.enumerated()), id: \.element.id) { index, item in
                        SkillFamilyChip(
                            family: item,
                            isSelected: family == item,
                            paletteIndex: index,
                            action: { onFamilyChange(item) }
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            SkillChoiceGrid(
                choices: roles.map(\.title),
                icons: Dictionary(uniqueKeysWithValues: roles.map { ($0.title, $0.systemImage) }),
                selected: { $0 == targetRole },
                paletteOffset: SkillRoleFamily.allCases.firstIndex(of: family) ?? 0,
                onTap: { role in
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                        targetRole = role
                    }
                    cvImpactHaptic(.light)
                }
            )

            Text("Your experience")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.cvInkSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(SkillProfileCatalog.experienceLevels.enumerated()), id: \.element) { index, level in
                        ColorChoicePill(
                            title: level,
                            isSelected: experienceLevel == level,
                            paletteIndex: index + 1,
                            action: {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.74)) { experienceLevel = level }
                                cvImpactHaptic(.light)
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct SkillFamilyChip: View {
    let family: SkillRoleFamily
    let isSelected: Bool
    let paletteIndex: Int
    let action: () -> Void

    var body: some View {
        let accent = SkillTreePalette.accent(at: paletteIndex)
        Button(action: action) {
            Label(family.rawValue, systemImage: family.systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? accent : Color.cvInkSecondary)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(isSelected ? SkillTreePalette.soft(at: paletteIndex) : Color.cvSurface, in: Capsule())
                .overlay(Capsule().stroke(isSelected ? accent.opacity(0.36) : Color.cvHairline, lineWidth: 1))
                .scaleEffect(isSelected ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: isSelected)
    }
}

private struct ColorChoicePill: View {
    let title: String
    let isSelected: Bool
    let paletteIndex: Int
    let action: () -> Void

    var body: some View {
        let accent = SkillTreePalette.accent(at: paletteIndex)
        Button(action: action) {
            HStack(spacing: 6) {
                Circle().fill(accent).frame(width: 7, height: 7)
                Text(title)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(isSelected ? accent : Color.cvInkSecondary)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(isSelected ? SkillTreePalette.soft(at: paletteIndex) : Color.cvSurface, in: Capsule())
            .overlay(Capsule().stroke(isSelected ? accent.opacity(0.34) : Color.cvHairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct SkillProfileChoiceSection: View {
    let title: String
    let choices: [String]
    @Binding var selection: String
    var paletteOffset = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.cvInk)
            SkillChoiceGrid(
                choices: choices,
                selected: { $0 == selection },
                paletteOffset: paletteOffset,
                onTap: { value in
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { selection = value }
                    cvImpactHaptic(.light)
                }
            )
        }
    }
}

private struct SkillProfileMultiChoiceSection: View {
    let title: String
    let choices: [SkillProfileOption]
    @Binding var selection: Set<String>
    let recommendationLabel: String
    let onBrowseAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.cvInk)
                Spacer()
                if !selection.isEmpty {
                    Text("\(selection.count) selected")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.cvStudioAccent)
                }
            }
            Text(recommendationLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.cvInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            SkillChoiceGrid(
                choices: choices.map(\.title),
                icons: Dictionary(uniqueKeysWithValues: choices.map { ($0.title, $0.systemImage) }),
                selected: selection.contains,
                paletteOffset: 1,
                onTap: toggle
            )
            Button(action: onBrowseAll) {
                Label("Explore all \(SkillProfileCatalog.skills.count) skills", systemImage: "square.grid.2x2.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.cvStudioAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.cvStudioAccentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func toggle(_ value: String) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            if selection.contains(value) {
                selection.remove(value)
            } else {
                selection.insert(value)
            }
        }
        cvImpactHaptic(.light)
    }
}

private struct SkillChoiceGrid: View {
    let choices: [String]
    var icons: [String: String] = [:]
    let selected: (String) -> Bool
    var paletteOffset = 0
    let onTap: (String) -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(choices.enumerated()), id: \.element) { index, choice in
                let isSelected = selected(choice)
                let paletteIndex = index + paletteOffset
                let accent = SkillTreePalette.accent(at: paletteIndex)
                Button { onTap(choice) } label: {
                    HStack(spacing: 7) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : (icons[choice] ?? "circle"))
                        Text(choice)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? accent : Color.cvInkSecondary)
                    .padding(.horizontal, 11)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(isSelected ? SkillTreePalette.soft(at: paletteIndex) : Color.cvSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? accent.opacity(0.34) : Color.cvHairline, lineWidth: 1)
                    )
                    .scaleEffect(isSelected ? 1.015 : 1)
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.38, dampingFraction: 0.72), value: isSelected)
            }
        }
    }
}

private struct SkillLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: Set<String>
    @State private var query = ""

    private var filteredSkills: [SkillProfileOption] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return SkillProfileCatalog.skills }
        return SkillProfileCatalog.skills.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.category.localizedCaseInsensitiveContains(query)
        }
    }

    private var categories: [String] {
        Array(Set(filteredSkills.map(\.category))).sorted()
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(categories.enumerated()), id: \.element) { categoryIndex, category in
                        let items = filteredSkills.filter { $0.category == category }
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Circle()
                                    .fill(SkillTreePalette.accent(at: categoryIndex))
                                    .frame(width: 9, height: 9)
                                Text(category)
                                    .font(.headline.weight(.bold))
                                Spacer()
                                Text("\(items.count)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.cvInkTertiary)
                            }
                            SkillChoiceGrid(
                                choices: items.map(\.title),
                                icons: Dictionary(uniqueKeysWithValues: items.map { ($0.title, $0.systemImage) }),
                                selected: selection.contains,
                                paletteOffset: categoryIndex,
                                onTap: toggle
                            )
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.cvAppBackground)
            .navigationTitle("Skill library")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search skills or categories")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func toggle(_ value: String) {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
            if selection.contains(value) { selection.remove(value) } else { selection.insert(value) }
        }
        cvImpactHaptic(.light)
    }
}

private struct AnimatedBuildTreeButton: View {
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let pulse = reduceMotion ? 1 : 1 + sin(time * 2.2) * 0.008
            Button(action: action) {
                Label("Build my challenge tree", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(colors: [Color.cvStudioAccent, Color.cvPurple, Color.cvBlue], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .shadow(color: Color.cvStudioAccent.opacity(0.20), radius: 12, y: 6)
                    .scaleEffect(pulse)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct SkillTreePathView: View {
    let profile: InterviewSkillProfile
    let onEditProfile: () -> Void
    @State private var progressRefreshID = UUID()

    private var challenges: [SkillChallenge] {
        SkillChallengeTreeBuilder.challenges(for: profile)
    }

    private var completion: [Bool] {
        _ = progressRefreshID
        return challenges.map { challenge in
            guard let progressID = challenge.route.skillTreeProgressID else { return false }
            return SkillTreeChallengeProgressStore.progress(for: progressID).isCleared
        }
    }

    private var activeIndex: Int {
        completion.firstIndex(of: false) ?? max(challenges.count - 1, 0)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SkillTreeHeader(
                    profile: profile,
                    completedCount: completion.filter { $0 }.count,
                    totalCount: challenges.count,
                    onEditProfile: onEditProfile
                )

                if challenges.indices.contains(activeIndex) {
                    SkillTreeCurrentChallenge(challenge: challenges[activeIndex], step: activeIndex + 1, total: challenges.count)
                }

                VStack(spacing: 0) {
                    ForEach(Array(challenges.enumerated()), id: \.element.id) { index, challenge in
                        SkillTreeNodeRow(
                            challenge: challenge,
                            index: index,
                            state: nodeState(at: index)
                        )
                    }
                }
            }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, CVLayout.floatingTabContentPadding)
        .onAppear { progressRefreshID = UUID() }
        }
    }

    private func nodeState(at index: Int) -> SkillTreeNodeState {
        if completion.indices.contains(index), completion[index] { return .complete }
        if index == activeIndex { return .active }
        return .locked
    }

}

private struct SkillTreeHeader: View {
    let profile: InterviewSkillProfile
    let completedCount: Int
    let totalCount: Int
    let onEditProfile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR CHALLENGE PATH")
                        .font(.caption2.weight(.bold))
                        .tracking(1.8)
                        .foregroundStyle(Color.cvStudioAccent)
                    Text(profile.targetRole)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.cvInk)
                    HStack(spacing: 7) {
                        Label(profile.resolvedExperienceLevel, systemImage: "bolt.fill")
                        Text("•")
                        Text(profile.growthDirection)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.cvInkSecondary)
                }
                Spacer()
                Button(action: onEditProfile) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color.cvStudioAccent)
                        .frame(width: 40, height: 40)
                        .background(Color.cvStudioAccentSoft, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit skill profile")
            }

            HStack {
                Text("\(completedCount) of \(totalCount) challenges complete")
                Spacer()
                Text("Built from real company interviews")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.cvInkSecondary)

            ProgressView(value: Double(completedCount), total: Double(max(totalCount, 1)))
                .tint(Color.cvStudioAccent)

            HStack(spacing: 8) {
                ForEach(Array(profile.currentSkills.sorted().prefix(3).enumerated()), id: \.element) { index, skill in
                    Text(skill)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(SkillTreePalette.accent(at: index))
                        .padding(.horizontal, 9)
                        .frame(height: 26)
                        .background(SkillTreePalette.soft(at: index), in: Capsule())
                }
                if profile.currentSkills.count > 3 {
                    Text("+\(profile.currentSkills.count - 3)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.cvInkSecondary)
                }
            }
        }
        .padding(17)
        .background(Color.cvSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.cvHairline, lineWidth: 1))
    }
}

private struct SkillTreeCurrentChallenge: View {
    let challenge: SkillChallenge
    let step: Int
    let total: Int

    var body: some View {
        let accent = SkillTreePalette.accent(at: step - 1)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("STAGE \(step) OF \(total)")
                Spacer()
                Text(challenge.skill)
            }
            .font(.caption2.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(accent)

            Text(challenge.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.cvInk)
            Text(challenge.subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.cvInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(SkillTreePalette.soft(at: step - 1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(accent.opacity(0.24), lineWidth: 1))
    }
}

private enum SkillTreeNodeState: Equatable {
    case complete, active, locked
}

private struct SkillTreeNodeRow: View {
    let challenge: SkillChallenge
    let index: Int
    let state: SkillTreeNodeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    private var isLeading: Bool { index.isMultiple(of: 2) }
    private var canOpen: Bool { state != .locked }
    private var accent: Color { SkillTreePalette.accent(at: index) }
    private var softAccent: Color { SkillTreePalette.soft(at: index) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if !isLeading { Spacer(minLength: 86) }

                Group {
                    if canOpen {
                        NavigationLink(value: challenge.route) { nodeContent }
                            .buttonStyle(.plain)
                    } else {
                        nodeContent
                    }
                }

                if isLeading { Spacer(minLength: 86) }
            }

            if !challenge.isBoss {
                SkillTreeConnector(isLeading: isLeading, index: index, isReached: state != .locked)
            }
        }
        .onAppear {
            guard state == .active, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private var nodeContent: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(nodeBackground)
                    .frame(width: challenge.isBoss ? 92 : 78, height: challenge.isBoss ? 92 : 78)
                    .overlay(Circle().stroke(nodeBorder, lineWidth: state == .active ? 8 : 2))
                    .shadow(color: state == .active ? accent.opacity(isPulsing ? 0.34 : 0.17) : .clear, radius: isPulsing ? 20 : 12, x: 0, y: 7)
                Image(systemName: state == .complete ? "checkmark" : state == .locked ? "lock.fill" : challenge.systemImage)
                    .font(.system(size: challenge.isBoss ? 28 : 24, weight: .bold))
                    .foregroundStyle(nodeForeground)
            }
            .scaleEffect(state == .active && isPulsing ? 1.045 : 1)

            VStack(spacing: 2) {
                Text(challenge.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(state == .locked ? Color.cvInkTertiary : Color.cvInk)
                    .lineLimit(1)
                Text(stateLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(state == .active ? accent : Color.cvInkTertiary)
            }
            .frame(width: 170)
        }
        .contentShape(Rectangle())
        .accessibilityLabel("\(challenge.title), \(stateLabel)")
    }

    private var nodeBackground: Color {
        switch state {
        case .complete: return Color.cvGreenSoft
        case .active: return accent
        case .locked: return softAccent.opacity(0.72)
        }
    }

    private var nodeBorder: Color {
        switch state {
        case .complete: return Color.cvGreen.opacity(0.30)
        case .active: return softAccent
        case .locked: return accent.opacity(0.14)
        }
    }

    private var nodeForeground: Color {
        switch state {
        case .complete: return Color.cvGreen
        case .active: return .white
        case .locked: return accent.opacity(0.40)
        }
    }

    private var stateLabel: String {
        switch state {
        case .complete: return "Practice again"
        case .active: return challenge.isBoss ? "Boss interview" : "Start challenge"
        case .locked: return "Complete the step above"
        }
    }
}

private struct SkillTreeConnector: View {
    let isLeading: Bool
    let index: Int
    let isReached: Bool

    var body: some View {
        HStack {
            if isLeading { Spacer().frame(width: 74) }
            Capsule()
                .fill(
                    isReached
                        ? LinearGradient(
                            colors: [SkillTreePalette.accent(at: index).opacity(0.48), SkillTreePalette.accent(at: index + 1).opacity(0.48)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        : LinearGradient(colors: [Color.cvHairline, Color.cvHairline], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 5, height: 48)
            if !isLeading { Spacer().frame(width: 74) }
        }
        .frame(maxWidth: .infinity)
    }
}
