# FacialMotionBaselineApp

Baseline deterministic iOS/iPadOS app for structured facial motion capture using SwiftUI + ARKit.

## Repository layout

`Facework.xcodeproj` and the `Facework` source directory must remain beside one
another at the repository root. Open `Facework.xcodeproj` directly in Xcode;
do not create a replacement project or open only the source directory.

The app target currently has a minimum deployment target of iOS 17.6. The
camera usage description and required framework imports are already configured
by the project.

## Signing

For physical-device development, select the `Facework` target in Xcode, open
Signing & Capabilities, enable automatic signing, and choose a team available
to your Apple ID. Keep personal signing selections in Xcode's user settings
where possible. Do not commit a change that replaces the repository's
development team or bundle identifier solely for local use.

## Building and testing

The shared `Facework` scheme includes the app, unit-test target, and UI-test
target. Run tests in Xcode with Product > Test, or run unit tests from the
repository root with:

```sh
xcodebuild -project Facework.xcodeproj -scheme Facework \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -only-testing:FaceworkTests test
```

Use a simulator name and OS version installed on the development machine.
Mathematical, processing, storage, and other non-camera tests can run in the
simulator. The simulator cannot validate TrueDepth capture, AR face anchors,
blend shapes, or face geometry.

## Device-only verification

ARKit facial tracking requires a supported physical device with a TrueDepth
front camera. Connect and trust the device, select it as the run destination,
choose the appropriate local signing team, and run the `Facework` scheme.
Verify camera permission, readiness, neutral calibration, every motion task,
validation-image creation, session summary, and export on the device. Do not
use identifiable participant data for development verification.

The core workflow is:

`setup -> readiness -> neutral calibration -> structured tasks -> summary -> export`

Research/debug mode can be toggled in Settings. Capture and analysis are
performed on-device.

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
