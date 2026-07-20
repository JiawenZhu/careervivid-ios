import XCTest
@testable import CareerVividMobileMVP

final class CareerVividMobileMVPTests: XCTestCase {
    func testCapturedLinkedInJobUsesImportCompany() {
        let job = makeCapturedJob(
            from: "https://www.linkedin.com/jobs/view/123",
            existingCount: 3
        )

        XCTAssertEqual(job.title, "Captured role 4")
        XCTAssertEqual(job.company, "LinkedIn Import")
        XCTAssertEqual(job.stage, .saved)
    }

    func testSampleDataHasMVPContent() {
        XCTAssertGreaterThanOrEqual(SampleCareerVividData.jobs.count, 3)
        XCTAssertGreaterThanOrEqual(SampleCareerVividData.interviews.count, 2)
        XCTAssertEqual(SampleCareerVividData.resume.matchScore, 92)
        XCTAssertFalse(SampleCareerVividData.actions.isEmpty)
    }

    func testQuestionFocusedReportPromptIncludesExactQuestionAndAvoidsForcedFramework() {
        let question = "Tell me about a time you resolved a difficult conflict with a teammate."
        let config = InterviewLiveConfig(
            job: JobLead(
                title: "Interview candidate",
                company: "SAP",
                matchScore: 100,
                stage: .interview,
                nextStep: "Practice"
            ),
            category: .behavioral,
            questions: [question],
            questionContext: question,
            remediationContextId: nil
        )

        XCTAssertTrue(config.prompt.contains(question))
        XCTAssertTrue(config.prompt.contains("specific to SAP"))
        XCTAssertTrue(config.prompt.contains("Do not force a prescribed answer framework"))
    }

    func testOnlyCodingAndSystemDesignUseWebWorkspaceRouting() {
        XCTAssertEqual(QuestionWebQuestStage.resolve(stageTitle: "Coding round", category: .technical), .coding)
        XCTAssertEqual(QuestionWebQuestStage.resolve(stageTitle: "System design", category: .systemDesign), .systemDesign)

        ["Recruiter screen", "Behavioral round", "Values round", "Final round"].forEach { stage in
            XCTAssertNil(QuestionWebQuestStage.resolve(stageTitle: stage, category: .behavioral))
        }
    }
}
