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
- Observation-driven scientific capture at a minimum source-time interval of
  0.1 seconds, with timers retained only for countdown and phase boundaries.
- Three repetitions for each configured movement task.
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
- Validation-image capture still reads `ARSession.currentFrame` separately
  from the accepted scientific observation, so exact image/measurement
  synchronization is not guaranteed.
- Session-level QC currently treats any non-empty capture as valid for
  analysis.
- Observation timestamps sample `ARSession.currentFrame.timestamp` once per
  callback, with `CACurrentMediaTime()` as fallback; they are not timestamps
  intrinsic to `ARFaceAnchor`.
- Camera/session tracking status remains separate from face observations and
  is still consumed by the existing tracking QC compatibility path.
- Accepted cadence depends on source-observation timing. A verified device
  session produced later tasks at approximately 10.0 Hz, while earlier tasks
  commonly ran near 8.57 Hz because source timestamps were approximately
  0.11665 seconds apart. A few larger gaps also occurred. Cadence consistency
  must be revisited before relying on high-precision timing or velocity
  measurements.

These limitations describe the current baseline and are intentionally
unchanged except for the intentional move to observation-driven capture.

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
Observation-collector tests cover active capture boundaries, neutral/task
modes, repetition identity, ordered delivery, 0.1-second source-time sampling,
face loss, reacquisition, late observations, and MainActor mutation.
The suite contains 125 unit-test methods and 5 UI-test methods; two existing
`CaptureSessionViewModel` checks remain simulator-skipped because that view
model eagerly constructs `ARSession`.

Repository search confirmed that `AppConfiguration` is never encoded or
decoded. Its unused `Codable` conformance and hardcoded app-version field were
removed without changing any scientific configuration value.

## Physical-device verification

Prompt 6 end-to-end verification completed successfully on an `iPhone17,3`
running iOS 26.2 with Facework 1.0 build 1. The exported session identified raw
schema `1.0.0`, analysis version `0.1.0`, and capture protocol `0.1.0`.

- Neutral calibration completed successfully.
- All six facial tasks completed with three repetitions each.
- Scientific frame construction and repetition isolation worked.
- The session exported 515 scientific frames with no duplicate or decreasing
  timestamps and no accepted interval below the intended 0.1-second gate.
- Later tasks ran at approximately 10.0 Hz accepted capture. Earlier tasks
  commonly ran near 8.57 Hz because accepted source timestamps were about
  0.11665 seconds apart.
- A few larger source-timestamp gaps occurred, including during the invalid
  Smile Showing Teeth repetition.
- Validation images were generated at frame indexes 0, 10, and 20, and 54
  validation images were exported.
- Session JSON, merged CSV files, task-specific CSV files, images, ZIP
  packaging, and sharing all succeeded.
- Overall session QC reported 97.67% passing frames and valid for analysis.
- Seventeen of eighteen task repetitions were valid. Smile Showing Teeth
  repetition 1 was correctly reported as partial/invalid with `signalSpike`
  and `invalidTimestampGap`.

Exact validation-image/measurement synchronization and accepted-cadence
consistency remain outstanding scientific limitations rather than failed
device-verification steps.

Use synthetic or consenting non-identifiable data during development. Exported
participant sessions, research data, facial images, and local logs must remain
outside version control.

## Next implementation phase

Prompt 7 should separate immutable raw frames from processed analysis data,
including truthful baseline-corrected and smoothed-value semantics while
preserving legacy-session readability.
