# FacialMotionBaselineApp

Baseline deterministic iOS/iPadOS app for structured facial motion capture using SwiftUI + ARKit.

## Notes
- Designed for TrueDepth-supported devices.
- Uses on-device ARKit face tracking only.
- Core workflow: setup -> readiness -> neutral calibration -> structured tasks -> summary -> export.
- Research/debug mode can be toggled in Settings.

## Important Xcode setup
1. Create a new **iOS App** in Xcode named `FacialMotionBaselineApp`.
2. Replace the generated source tree with the files in this folder.
3. Add camera usage description in Info.plist:
   - `NSCameraUsageDescription`: `Camera access is required for structured facial motion capture.`
4. Deployment target: iOS 17+ recommended.
5. Required frameworks:
   - SwiftUI
   - ARKit
   - RealityKit
   - AVFoundation
   - Combine
6. Run on a TrueDepth-supported iPhone/iPad only. The simulator does not support face tracking.

## Folder structure
Matches the requested architecture:
- App
- Models
- AR
- Processing
- QualityControl
- Storage
- ViewModels
- Views
- Utilities
- Tests

