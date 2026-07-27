# Facework Development Status

## Current architecture

Facework is a SwiftUI iOS/iPadOS application with an MVVM-style organization.
`AppState` owns navigation and the active `CaptureSessionViewModel`.
`FaceTrackingManager` and `ARSessionCoordinator` wrap ARKit face tracking.
Each relevant AR face-anchor callback now creates one immutable
`FaceTrackingObservation` containing copied values and publishes it on
`MainActor` through an explicitly configured main delegate queue.
Face-anchor removal is handled explicitly and produces an ordered no-face
observation. ARKit's default one-face tracking limit remains unchanged, so the
multiple-face callback branch is defensive.
Processing, quality-control, and export operations are implemented as small
services and value-type calculators. Session data is held in memory and
exported to JSON, CSV, validation images, and a ZIP archive in the app's
Documents directory.

The primary flow is setup, device readiness, neutral calibration, six guided
movement tasks, session summary, and export.

## Currently working features

- SwiftUI navigation and session metadata entry.
- TrueDepth capability and camera-permission checks.
- ARKit face preview, face-anchor updates, selected blend-shape capture, and
  optional face-mesh display on supported hardware.
- Neutral blend-shape baseline capture and baseline subtraction.
- Timed capture of three repetitions for each configured movement task.
- Per-frame tracking, framing, pose, timestamp, signal-plausibility, and
  neutral-activation flags.
- Blend-shape amplitude, onset, time-to-peak, velocity, hold-stability,
  symmetry, repeatability, fatigue-slope, and confidence calculations.
- Per-repetition and per-task summaries.
- JSON, per-frame CSV, per-repetition CSV, validation-image manifest, JPEG
  validation images, ZIP packaging, and share-sheet presentation.
- Bundle-derived marketing/build identity and versioned research metadata:
  raw schema `1.0.0`, analysis algorithm `0.1.0`, and capture protocol `0.1.0`.
- Legacy metadata decoding that preserves historical fields without assigning
  current analysis or capture versions to old sessions.
- Generic physical-device application builds.

## Confirmed placeholders and unused components

- `FaceGeometryExtractor` is gated by `enableMeshCaptureStub`, is not called by
  capture code, and does not currently populate `meshVertices`.
- Face center and face scale are fixed placeholder values rather than measured
  image-space geometry.
- Readiness marks face visibility, framing, pose, and tracking stability as
  ready after capability and permission checks instead of observing a stable
  interval.
- `HoldValidator`, `FrameLogWriter`, `SessionSummaryViewModel`, `Logger`, and
  `DateFormatting` are not integrated into the active workflow.
- `CaptureSessionViewModel` eagerly constructs an `ARSession`; its two direct
  session-summary characterization tests therefore skip in the simulator to
  avoid an ARKit abort and remain device checks.

## Known scientific limitations

- Movement amplitude is based on normalized ARKit blend-shape coefficients; it
  is not a physical distance, angle, or explicit landmark displacement.
- No named facial-landmark indices or geometric range-of-motion algorithm are
  implemented.
- Symmetry compares independently selected left and right peak coefficients,
  not necessarily simultaneous measurements at one shared peak frame.
- Neutral calibration falls back to all neutral frames when none pass QC.
- Configured rest duration and contiguous hold-duration validation are not
  enforced by the current task flow.
- Stored `smoothedBlendshapes` currently duplicate normalized values; smoothing
  is applied later during feature extraction.
- Validation JPEG sampling is periodic and is not guaranteed to capture the
  exact calculated peak frame.
- Session-level QC currently treats any non-empty capture as valid for
  analysis.
- Observation timestamps sample `ARSession.currentFrame.timestamp` once per
  callback, with `CACurrentMediaTime()` as fallback; they are not timestamps
  intrinsic to `ARFaceAnchor`.
- Camera/session tracking status remains separate from face observations and
  is still consumed by the existing tracking QC compatibility path.

These limitations describe the current baseline and are intentionally
unchanged by the version-identity and atomic-observation phases.

## Research-data identity

New sessions record the app marketing version and build number from the app
bundle, a public-API hardware model identifier, operating-system name and
version, and the centralized research version identity. Mesh capture and
operational landmarks remain inactive, so both corresponding version states
are `not-active`.

Historical metadata without the versioned schema decodes with
`legacy-unknown`, `not-recorded`, and `not-active` values as appropriate.
Current version numbers are never imputed into legacy sessions. The in-memory
`wasLoadedFromLegacySchema` marker is not written to exports.

## Test status

The XCTest characterization suite uses deterministic synthetic fixtures for
baseline calibration, signal preprocessing, feature extraction, velocity,
symmetry, quality-control boundaries, repetition/task analysis, current model
round trips, and JSON/CSV/manifest exports. Minimal UI coverage verifies launch,
home/setup navigation, setup-field gating, and the simulator's unsupported
TrueDepth readiness state. TrueDepth capture remains outside simulator scope.

Version and migration tests cover bundle fallbacks, centralized research
versions, deterministic device-information injection, current and legacy
metadata, malformed-session isolation, and versioned CSV output.
Atomic-observation tests cover copied callback values, source timestamps,
dictionary and transform independence, production callback cardinality,
ordered update/removal/reacquisition delivery, synthetic delivery without
ARKit, compatibility state, and MainActor publication.
The suite contains 107 unit-test methods and 5 UI-test methods; two existing
`CaptureSessionViewModel` checks remain simulator-skipped because that view
model eagerly constructs `ARSession`.

Repository search confirmed that `AppConfiguration` is never encoded or
decoded. Its unused `Codable` conformance and hardcoded app-version field were
removed without changing any scientific configuration value.

## Device-validation requirements

End-to-end verification requires a supported physical TrueDepth device with
camera permission granted. Device verification must cover:

1. Face-tracking support and camera authorization.
2. Live camera preview and optional mesh overlay.
3. Neutral calibration and each movement task.
4. AR face-anchor, blend-shape, pose, and captured-image availability.
5. Repetition completion, QC presentation, session summary, file export, ZIP
   sharing, and validation-image linkage.

Use synthetic or consenting non-identifiable data during development. Exported
participant sessions, research data, facial images, and local logs must remain
outside version control.

## Next implementation phase

The next implementation phase should replace timer polling for scientific
capture with the atomic observation stream. Timers should remain only for
countdowns and phase transitions.
