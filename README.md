# CareerVivid iOS

Standalone iOS workspace for CareerVivid mobile prototypes and companion apps.

## Apps

- `CareerVividMobileMVP`: CareerVivid mobile companion app.
- `GreenCardInterviewMVP`: green card interview practice app.
- `VisaInterviewPrepMVP`: visa interview preparation app.

Each app currently ships as an independent SwiftUI/XcodeGen project with its own `Package.swift`, generated Xcode project, source tree, and tests.

## Repository Split

This repository was split from the `ios/` directory of `JiawenZhu/CareerVivid` so the web application and mobile apps can evolve independently.

## Local Development

Open one of the app `.xcodeproj` files directly, or regenerate it from the app folder with XcodeGen if needed:

```bash
cd VisaInterviewPrepMVP
xcodegen generate
open VisaInterviewPrepMVP.xcodeproj
```

The apps target iOS 17.0+.
