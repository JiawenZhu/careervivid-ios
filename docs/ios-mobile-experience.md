# CareerVivid iOS product walkthrough

CareerVivid iOS turns interview preparation into a daily practice loop. The product has three connected surfaces: **Home** for evidence of improvement, **Skill Tree** for a personalized challenge path, and **Mock Interview** for company-specific practice.

This guide documents the current mobile experience with the supplied iPhone 17 Pro screens.

## 1. Home makes every attempt useful

Home starts with practice history, not empty productivity metrics. The activity grid makes consistency legible over thirteen weeks; the summary cards show report count, current streak, and average score. The coaching cards reduce a report to one strength to carry forward and one concrete improvement to make next.

![Interview activity grid, active-day badge, report count, streak, average score, and coaching insight](screenshots/ios/home-interview-activity.png)

Every report stays available independently. A new attempt on the same question becomes a new result, so candidates can compare progress rather than lose prior evidence.

![Strength, focus-next guidance, and a scrollable history of independently saved reports](screenshots/ios/report-history-and-coaching.png)

## 2. Skill Tree starts with the candidate, not a preset curriculum

The Skill Tree begins with a short, editable profile. A candidate selects a career family, then a specific target role and experience level. The setup covers engineering, product, design, data and AI, people, and customer-growth paths rather than assuming every candidate is a software engineer.

![Skill Tree introduction, career family tabs, role choices, and experience selection](screenshots/ios/skill-tree-profile-setup.png)

Role selection changes the recommended starting skills. The candidate can choose from a broad skill catalog and set a growth goal; the distinct chip colors make selections fast to scan without implying that one skill family is always better.

![Frontend Engineer role-specific skills, selected skill chips, expansion to 44 skills, and growth-direction choices](screenshots/ios/skill-selector.png)

## 3. The profile becomes a challenge path

The generated path states the role, level, goal, relevant skill tags, completed count, and its source: real company interview themes. The first step is actionable while later nodes are intentionally locked until the previous challenge is completed.

![Frontend Engineer challenge summary and the first role-story stage](screenshots/ios/skill-tree-overview.png)

The visual path uses alternating nodes, soft color families, and connecting routes to make progression feel game-like while keeping the next required step unambiguous.

![Skill Tree route with the active role-story challenge and color-coded locked skill nodes](screenshots/ios/skill-tree-locked-path.png)

## 4. Personalized challenges still use a disciplined interview format

Skill Tree challenges create a role-and-skill-specific behavioral question. The question names the target role and the skill theme, then gives concise structure guidance. A source label explains when the prompt is personalized from a company interview theme instead of being a direct company-stage question.

![Personalized Frontend Engineer accessibility question, source label, and live recording experience](screenshots/ios/personalized-challenge-recording.png)

Candidates can also type an answer. Native spoken challenges use a timed circular recorder: tap once to start and again to stop.

![Active recording state with elapsed time, listening status, live transcript panel, and record-progress ring](screenshots/ios/recording-progress-10s.png)

The next question retains the same personalized provenance and makes the remaining time obvious before recording begins.

![Second personalized Accessibility question with ready-to-record state](screenshots/ios/personalized-question-ready.png)

![A follow-up personalized question that advances the same role-specific practice sequence](screenshots/ios/personalized-question-next.png)

## 5. Record, transcribe, review, then analyze

When recording ends, the UI moves into a dedicated transcription state rather than showing an ambiguous loading spinner. It keeps the answer duration, explains the handoff, and uses an animated multi-color progress ring around the transcription state.

![Vivid transcription state with secure-recording explanation, progress status, and animated circular treatment](screenshots/ios/transcription-state.png)

The transcript is editable before it is sent. Vivid also provides short, practical suggestions that the candidate can apply immediately or use as a reason to record again. The user explicitly sends the reviewed answer with **Send for Deep AI Analysis**.

![Editable transcript, strengthening suggestions, record-again control, and Deep AI Analysis action](screenshots/ios/transcript-review-suggestions.png)

## 6. The report evaluates the exact answer

The resulting interview report breaks down communication, confidence, and answer relevance — described as the connection to the specific question. It retains the original question so candidates can relate each score and recommendation to the answer they actually gave.

![Interview report metric breakdown, strengths, practice-next guidance, and the exact personalized question](screenshots/ios/personalized-report.png)

## 7. Mock Interview makes company data approachable

Mock Interview is the catalog for the company-guide experience. It exposes sourced interview-stage counts, company search, filters, real-company topic previews, difficulty, and each candidate's quest progress.

![Mock Interview header, source attribution, company search, filters, and SAP quest card](screenshots/ios/mock-interview-catalog.png)

Companies make progress easy to understand: a visible interview-loop meter, attempt count, best score, and a direct Continue quest action. Users can compare active and not-started companies in the same scroll.

![Figma and Scale AI company cards with source themes, scores, quest progress, and continue actions](screenshots/ios/mock-interview-company-cards.png)

## 8. Company Quests normalize the real interview loop

Some source guides have only one or two reported stages. CareerVivid expands them into a consistent six-stage preparation loop, keeping the result predictable for candidates: recruiter screen, coding, system design, behavioral, values, and final round.

![Figma quest summary, progress meter, recruiter screen, and coding round](screenshots/ios/company-quest-overview.png)

Coding and system-design stages lead to the dedicated web coding or whiteboard experiences. Recruiter, behavioral, values, and final rounds remain in the native speech-and-report loop.

![Company Quest coding, system design, and behavioral stages](screenshots/ios/company-quest-middle-stages.png)

![Company Quest behavioral, values, and final stages](screenshots/ios/company-quest-final-stages.png)

## Data and service contract

| Step | Source of truth | Result |
| --- | --- | --- |
| Company question selection | Authenticated `mobileInterviewQuestions` Cloud Function | Exact guide-and-stage questions shared with CareerVivid's mobile/web question flow |
| Native audio practice | AVFoundation WAV capture; Apple speech recognition when available | Timed recording and optional live draft |
| Transcript review | `mobileInterviewTranscribe` Cloud Function in `us-west1` | Editable transcript and up to three user-facing suggestions |
| Deep feedback | `mobileInterviewAnalyze` Cloud Function in `us-west1` | Score, metric breakdown, strengths, practice-next guidance, and transcript context |
| Long-term progress | Device report cache and quest/Skill Tree progress, plus authenticated remote report history when available | New attempts remain visible instead of replacing prior reports |

## Design principles

- **One repeatable loop.** Each screen leads to the next useful action instead of exposing every possible career task.
- **Personalization with provenance.** Skill Tree prompts explain their role and source context; company-stage prompts preserve the official source guide.
- **User control before AI evaluation.** Candidates can edit recognition output before sending it for analysis.
- **Progress is evidence, not decoration.** Scores, activity, cleared stages, locked nodes, and saved reports all correspond to persisted practice work.
- **Warm, accessible feedback.** Soft lavender, blue, green, peach, and orange states differentiate actions without relying on severe error red for normal practice.
