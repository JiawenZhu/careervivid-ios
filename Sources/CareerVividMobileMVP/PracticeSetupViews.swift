import SwiftUI

struct PracticeSetupScreen: View {
    @Binding var selectedJob: JobLead
    @Binding var selectedCategory: PracticeCategory
    let questions: [String]
    let errorMessage: String?
    let savedReports: [InterviewReportSnapshot]
    let isLoadingReports: Bool
    let reportHistoryError: String?
    let onRefreshReports: () -> Void
    let onOpenReport: (InterviewReportSnapshot) -> Void
    let onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let errorMessage {
                    PracticeErrorBanner(message: errorMessage)
                }

                InterviewSetupIntro()

                RecentInterviewReportsSection(
                    reports: savedReports,
                    isLoading: isLoadingReports,
                    errorMessage: reportHistoryError,
                    onRefresh: onRefreshReports,
                    onOpenReport: onOpenReport
                )

                InterviewJobPicker(selectedJob: $selectedJob)

                InterviewCategoryPicker(selectedCategory: $selectedCategory)

                InterviewQuestionPreview(
                    role: selectedJob.title,
                    company: selectedJob.company,
                    category: selectedCategory,
                    questions: questions
                )

                Button(action: onStart) {
                    Label("Start live mock interview", systemImage: "mic.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .cvPrimaryActionButton()
            }
            .padding(20)
            .padding(.bottom, CVLayout.floatingTabContentPadding)
        }
    }
}

private struct InterviewSetupIntro: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Live interview coach", systemImage: "sparkles")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.cvBrand)
            Text("Practice with Vivid")
                .font(.title2.weight(.black))
            Text("A short, natural conversation tailored to the role. Vivid asks one question at a time, captures your answers, then creates a feedback report.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cvCard(padding: 20, radius: 24, raised: true)
    }
}

private struct RecentInterviewReportsSection: View {
    let reports: [InterviewReportSnapshot]
    let isLoading: Bool
    let errorMessage: String?
    let onRefresh: () -> Void
    let onOpenReport: (InterviewReportSnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Previous reports")
                        .font(.headline.weight(.bold))
                    Text("Review saved interview feedback without starting over.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.black))
                        .frame(width: 30, height: 30)
                        .background(Color.cvBrandSoft)
                        .foregroundStyle(Color.cvBrand)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .accessibilityLabel("Refresh interview reports")
            }

            if isLoading, reports.isEmpty {
                RecentReportLoadingRow()
            } else if reports.isEmpty {
                RecentReportEmptyRow(errorMessage: errorMessage)
            } else {
                VStack(spacing: 8) {
                    ForEach(reports.prefix(4)) { report in
                        Button {
                            onOpenReport(report)
                        } label: {
                            RecentInterviewReportRow(report: report)
                        }
                        .buttonStyle(RecentReportButtonStyle())
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .cvCard(padding: 18, radius: 24, raised: true)
    }
}

private struct RecentReportLoadingRow: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Color.cvBrand)
            VStack(alignment: .leading, spacing: 3) {
                Text("Syncing reports")
                    .font(.subheadline.weight(.bold))
                Text("Loading your Vivid practice history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.cvBrandSofter)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.cvSelectedBorder.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct RecentReportEmptyRow: View {
    let errorMessage: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.cvBrand)
                .frame(width: 38, height: 38)
                .background(Color.cvBrandSoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(errorMessage == nil ? "No saved reports yet" : "Reports unavailable")
                    .font(.subheadline.weight(.bold))
                Text(errorMessage ?? "Complete one interview, or sign in with the same account you use on the website.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.cvTertiarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct RecentInterviewReportRow: View {
    let report: InterviewReportSnapshot

    var body: some View {
        HStack(spacing: 12) {
            ScoreBadge(score: report.analysis.overallScore)

            VStack(alignment: .leading, spacing: 4) {
                Text(report.jobTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(report.company) - \(report.category.rawValue)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(report.displayDate)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.cvTertiarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ScoreBadge: View {
    let score: Int

    var body: some View {
        VStack(spacing: 0) {
            Text("\(score)")
                .font(.subheadline.weight(.black))
                .foregroundStyle(scoreColor)
            Text("score")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 52, height: 52)
        .background(scoreColor.opacity(0.10))
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(scoreColor.opacity(0.28), lineWidth: 1)
        )
    }

    private var scoreColor: Color {
        score >= 80 ? .green : score >= 60 ? Color.cvBrand : .orange
    }
}

private struct RecentReportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct InterviewJobPicker: View {
    @Binding var selectedJob: JobLead

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Target role")
                .font(.headline.weight(.bold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(SampleCareerVividData.jobs) { job in
                        Button {
                            selectedJob = job
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("\(job.matchScore)%")
                                        .font(.caption2.weight(.black))
                                        .foregroundStyle(Color.cvBrand)
                                    Spacer()
                                    if selectedJob.id == job.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.cvBrand)
                                    }
                                }
                                Text(job.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text(job.company)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 170, alignment: .leading)
                            .padding(14)
                            .background(selectedJob.id == job.id ? Color.cvBrandSoft : Color.cvTertiarySystemBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(selectedJob.id == job.id ? Color.cvBrand.opacity(0.45) : Color.cvSeparator, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .cvCard(padding: 18, radius: 24, raised: true)
    }
}

private struct InterviewCategoryPicker: View {
    @Binding var selectedCategory: PracticeCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Interview type")
                .font(.headline.weight(.bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PracticeCategory.allCases) { category in
                        PracticeCategoryChip(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
        .cvCard(padding: 18, radius: 24, raised: true)
    }
}

private struct InterviewQuestionPreview: View {
    let role: String
    let company: String
    let category: PracticeCategory
    let questions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundStyle(Color.cvBrand)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(category.rawValue) focus")
                        .font(.subheadline.weight(.bold))
                    Text("\(role) at \(company)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                PillLabel(text: "\(questions.count) prompts", color: Color.cvBrand)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(questions.prefix(3).enumerated()), id: \.offset) { index, question in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(Color.cvBrand)
                            .frame(width: 22, height: 22)
                            .background(Color.cvBrandSoft)
                            .clipShape(Circle())
                        Text(question)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if index < min(questions.count, 3) - 1 {
                        Divider()
                    }
                }
            }
        }
        .cvCard(padding: 18, radius: 24, raised: true)
    }
}

// MARK: - Live Screen

