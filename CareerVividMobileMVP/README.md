# CareerVivid Mobile MVP

`CareerVividMobileMVP` is the SwiftUI iOS app for daily interview practice. It pairs the CareerVivid company-guide catalog with a role-aware Skill Tree, timed voice answers, editable transcription, Deep AI Analysis, and persisted report history.

![CareerVivid mobile voice practice with a personalized question, live transcript state, and a tap-to-stop recorder](../docs/screenshots/ios/personalized-challenge-recording.png)

## What the app does

- **Home** keeps every completed report visible, along with a 13-week activity map, a score summary, strengths to retain, and one coaching focus.
- **Skill Tree** asks for a role, experience level, existing skills, and a growth direction; it turns that profile into a role-specific challenge path.
- **Mock Interview** presents company guides, topic filters, source links, quest progress, and six focused practice stages per company.
- **Native spoken stages** cover recruiter, behavioral, values, and final-round responses with a native record → transcribe → review → analyze loop.
- **Specialized web stages** send coding and system-design exercises to their purpose-built web workspaces.

## The answer-to-report contract

1. The app loads company and stage questions from `mobileInterviewQuestions`; it does not substitute a generic fallback question.
2. A user records a timed WAV response. Apple speech recognition may provide an on-device live draft when available.
3. `mobileInterviewTranscribe` in `us-west1` returns a reviewable transcript and up to three immediate suggestions.
4. The user can edit that text or record again before selecting **Send for Deep AI Analysis**.
5. `mobileInterviewAnalyze` receives the exact question, company, stage, transcript, and duration, then returns a report with communication, confidence, relevance, strengths, and practice-next guidance.
6. Every completed report is stored independently. A retry on the same question adds a report instead of replacing the earlier attempt.

```text
official company question
        ↓
tap to record → WAV capture → optional live draft
        ↓
Vivid transcription + suggestions → editable answer
        ↓
Deep AI Analysis → saved report → Home and quest progress
```

## Services and persistence

| Concern | Current implementation |
| --- | --- |
| Interview questions | `mobileInterviewQuestions` in CareerVivid Cloud Functions (`us-west1`) |
| Audio transcription | `mobileInterviewTranscribe` in CareerVivid Cloud Functions (`us-west1`) |
| Report analysis | `mobileInterviewAnalyze` in CareerVivid Cloud Functions (`us-west1`) |
| Live interview token | `mobileInterviewLiveToken` in CareerVivid Cloud Functions (`us-west1`) |
| Company and Skill Tree progress | On-device stores; progress updates only after a score of 75 or higher |
| Report history | Device cache plus authenticated remote report loading when available |
| Authentication | Firebase-authenticated CareerVivid session when a user signs in |

The app presents the model experience as **Vivid**. Vendor/model configuration stays on the controlled backend rather than in the iOS client.

## Project layout

| Path | Purpose |
| --- | --- |
| `App/` | App entry point and iOS configuration |
| `Sources/CareerVividMobileMVP/InterviewDashboardView.swift` | Interview-first Home and saved report history |
| `Sources/CareerVividMobileMVP/SkillTreeModels.swift` | Role families, skills, defaults, and challenge progress |
| `Sources/CareerVividMobileMVP/SkillTreeView.swift` | Profile selection and visual challenge path |
| `Sources/CareerVividMobileMVP/PracticeCatalogView.swift` | Mock Interview company-guide catalog and Company Quest entry points |
| `Sources/CareerVividMobileMVP/QuestionMockInterviewView.swift` | Exact-question native practice flow and report handoff |
| `Sources/CareerVividMobileMVP/QuestionAudioSession.swift` | Timed audio capture and Apple native speech draft support |
| `Sources/CareerVividMobileMVP/InterviewPracticeService.swift` | Cloud Function calls, report cache, and quest progress |

## Open and run

```bash
cd /Users/jiawenzhu/Developer/careervivid-ios/CareerVividMobileMVP
xcodegen generate
open CareerVividMobileMVP.xcodeproj
```

Select `CareerVividMobileMVP` and an iPhone simulator in Xcode, then Run. The app targets iOS 17.0+.

### Terminal validation

```bash
cd /Users/jiawenzhu/Developer/careervivid-ios/CareerVividMobileMVP
xcodebuild -project CareerVividMobileMVP.xcodeproj \
  -scheme CareerVividMobileMVP \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
swift test
```

If you use the Xcode 27 beta installed at `/Applications/Xcode-beta.app`, select it before the build:

```bash
sudo xcode-select --switch /Applications/Xcode-beta.app/Contents/Developer
xcodebuild -version
```

## Product walkthrough

See the repository-level [iOS experience guide](../docs/ios-mobile-experience.md) for the full documented journey, including Skill Tree setup, company catalog, recording, transcription, review suggestions, reports, and Company Quest progression.
