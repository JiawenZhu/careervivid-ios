# Skill Tree Design QA

## Compared artifacts

- Reference: `/Users/jiawenzhu/Downloads/Screenshot 2026-07-18 at 17.19.27.png`
- iOS implementation: `/tmp/careervivid-skill-tree.png`
- Side-by-side comparison: `/tmp/careervivid-skill-tree-comparison.png`
- Viewport: iPhone 17 Pro, iOS 27.0

## Visible comparison

- Preserved the reference's strongest interaction model: one current challenge, a sequential path, circular nodes, visible locked states, and a persistent bottom navigation.
- Kept the first actionable challenge visually dominant and made later challenges visibly unavailable until the previous step is complete.
- Added CareerVivid-specific context above the path: target role, growth direction, progress, and a short description of the current challenge.
- Verified that the node labels, cards, progress bar, and bottom navigation do not clip horizontally at the target viewport.

## Intentional CareerVivid adaptations

- Uses CareerVivid's light neutral product shell, pale lavender support surfaces, and existing orange navigation gradient instead of Duolingo's dark game environment.
- Removes mascot art, currencies, chests, energy, leaderboards, and unrelated reward systems to keep the daily interview loop focused.
- Uses SF Symbols and existing CareerVivid tokens rather than recreating or approximating Duolingo assets.
- Converts lessons into real-company interview challenges so every unlocked node launches an existing CareerVivid practice route.

## Result

Pass. The implementation captures the path-based progression and daily-action hierarchy of the reference while remaining recognizably CareerVivid and preserving the existing Home and Mock Interview surfaces.

## Expanded profile QA

- Added six career families and 28 target roles spanning engineering, product, design, data and AI, people and recruiting, and customer and growth work.
- Kept onboarding progressive: users choose a career family before seeing the relevant roles and skills instead of receiving one overwhelming list.
- Added five experience levels and a searchable library of 44 cross-functional skills.
- Reused the Mock Interview motion palette across lavender, blue, mint, orange, pink, and yellow selector states.
- Verified in Device Hub that switching from Engineering to People immediately replaces the role and recommended-skill sets with recruiter-specific choices.
- Added continuous motion to the profile mark, build action, and active path node while respecting Reduce Motion.
