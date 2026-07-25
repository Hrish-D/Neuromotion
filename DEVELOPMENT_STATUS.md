# Facework Development Status

## Current architecture

Facework is a SwiftUI iOS/iPadOS application with an MVVM-style organization.
`AppState` owns navigation and the active `CaptureSessionViewModel`.
`FaceTrackingManager` and `ARSessionCoordinator` wrap ARKit face tracking.
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
- The unit and UI tests are Xcode-generated placeholders and contain no
  scientific assertions.

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

These limitations describe the current baseline and are intentionally
unchanged by the repository-preparation phase.

## Test status

The application compiles, but automated coverage is effectively absent.
`FaceworkTests` has one empty Swift Testing test. UI tests only launch the app
and record the default launch/performance behavior. Pure mathematical and
non-camera tests can be added and run in an iOS simulator. TrueDepth behavior
cannot be meaningfully tested in the simulator.

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

The next phase should establish deterministic synthetic test fixtures and
tests for baseline, normalization, task signals, timing, velocity, symmetry,
QC, summary aggregation, CSV output, and ZIP contents. After those characterize
the current behavior, address atomic AR-frame sampling, actor-safe state
updates, real readiness/framing measurements, scientifically defined landmark
or blend-shape outcomes, contiguous hold/rest enforcement, exact peak-image
linkage, and asynchronous hardened export.
