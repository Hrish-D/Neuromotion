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

Prompt 7 separates each accepted observation into an immutable
`RawFrameCapture` and a distinct `FrameAnalysis`. `FrameCapture` is now a
composite compatibility projection used by the unchanged analyzers and
exports. `FrameProcessor` expresses the one-way raw-to-derived operation.
`raw_frames.json` is the authoritative raw historical record for new sessions;
the existing flat `frames.json` remains available for compatibility.

Prompt 8 makes onset sustain explicitly time-based: a threshold crossing must
remain observed above threshold for 0.3 seconds of source timestamp time. A
small deterministic timing utility also centralizes positive interval and
elapsed-duration validation without inventing replacement timestamps.

Prompt 9 separates hard acquisition failures from diagnostic warnings.
`NeutralCalibrationEvaluator` produces an explicit success or failure before
the existing arithmetic-mean baseline calculation, and
`SessionValidityEvaluator` evaluates calibration, protocol completeness, and
task usability separately from per-frame QC. Neutral attempts now retain an
ordered, unsampled acquisition-event stream alongside the unchanged sampled
scientific frames, so face removal cannot disappear behind the 0.1-second
scientific sampling gate.

The primary flow is setup, device readiness, neutral calibration, six guided
movement tasks, session summary, and export.

## Currently working features

- SwiftUI navigation and session metadata entry.
- TrueDepth capability and camera-permission checks.
- ARKit face preview, face-anchor updates, selected blend-shape capture, and
  optional face-mesh display on supported hardware.
- Neutral blend-shape baseline capture and baseline subtraction.
- Explicit neutral-calibration failure and retry without silently averaging
  hard-rejected observations.
- Observation-driven scientific capture at a minimum source-time interval of
  0.1 seconds, with timers retained only for countdown and phase boundaries.
- Three repetitions for each configured movement task.
- Per-frame tracking, framing, pose, timestamp, signal-plausibility, and
  neutral-activation flags.
- Blend-shape amplitude, onset, time-to-peak, velocity, hold-stability,
  symmetry, repeatability, fatigue-slope, and confidence calculations.
- Actual source timestamps drive onset sustain, velocity, frame-gap QC,
  time-to-peak, repetition boundaries, and the existing hold-duration
  validator. Capture cadence is not assumed to be 10 Hz.
- Per-repetition and per-task summaries.
- JSON, per-frame CSV, per-repetition CSV, validation-image manifest, JPEG
  validation images, ZIP packaging, and share-sheet presentation.
- Bundle-derived marketing/build identity and versioned research metadata:
  raw schema `2.0.0`, analysis algorithm `0.3.0`, and capture protocol `0.2.0`.
- Independent immutable raw acquisition persistence in `raw_frames.json`,
  including source timestamps, AR coefficients, copied transform and pose,
  face observation state/count/framing placeholders, recording context,
  separately sampled camera tracking state, and associated image references.
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
- Neutral calibration requires uninterrupted trustworthy tracking evidence
  spanning at least 2.35 seconds: the configured 2.5-second neutral interval
  minus the existing 0.15-second maximum accepted source-timestamp gap. This
  uses ordered source timestamps, not a frame count or assumed 10 Hz rate.
  Any observed no-face, multiple-face, limited-camera-tracking, missing-signal,
  non-monotonic-timestamp, or excessive-gap event fails the attempt. The strict
  interruption policy requires physical characterization for sensitivity to
  isolated one-event tracking losses; no valid-frame percentage was invented.
- Configured rest duration and contiguous hold-duration validation are not
  enforced by the current task flow.
- Compatibility `FrameAnalysis.smoothedBlendshapes` still duplicates normalized
  values at capture; smoothing is applied later during feature extraction.
- Feature-extraction smoothing deliberately remains a five-sample moving
  average. Its sample-domain semantics require a later, scientifically
  justified signal-processing decision rather than an implicit time filter.
- Validation JPEG sampling is periodic and is not guaranteed to capture the
  exact calculated peak frame.
- Validation-image capture still reads `ARSession.currentFrame` separately
  from the accepted scientific observation, so exact image/measurement
  synchronization is not guaranteed.
- `facialActivationTooHighAtNeutral` remains a diagnostic warning at its
  existing strict `> 0.15` boundary. It does not alone invalidate trustworthy
  acquisition because stable non-zero ARKit coefficients may represent
  anatomy, resting asymmetry, pathology, or model bias.
- Session validity requires established calibration, scientific frames for all
  six configured tasks, all configured repetition attempts, and at least one
  valid repetition per task. This permits an isolated failed repetition while
  rejecting missing or wholly unusable tasks.
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

The Prompt 8 onset change intentionally removes the former truncated-end
behavior: a final qualifying suffix is not sustained unless its observed
timestamps span the full configured duration. Other listed scientific
limitations remain unchanged.

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

Raw schema `2.0.0` identifies sessions with the independent authoritative raw
record. Existing metadata that explicitly records raw schema `1.0.0` retains
that identity, and metadata predating version fields remains `legacy-unknown`.
Legacy flat `FrameCapture` JSON still decodes without inventing observation
facts that were not historically stored. New analysis uses `0.3.0`; historical
sessions explicitly marked `0.1.0` retain that identity and unversioned sessions
remain `legacy-unknown`. Raw schema remains `2.0.0`, capture protocol remains
`0.2.0`, and mesh and landmark states remain `not-active`. Historical analysis
`0.2.0` and capture protocol `0.1.0` values remain unchanged when decoded. The
analysis increment records warning-aware calibration and protocol validity;
the capture-protocol increment records mandatory retry after failed calibration.

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
Raw-separation tests cover observation-to-raw copying, dictionary and transform
independence, structural exclusion of derived values, non-mutating deterministic
processing, legacy flat-frame decoding, current raw round trips, camera-state
context separation, and the authoritative raw export projection.
Timestamp tests cover duration-based onset with regular, irregular, mixed, and
approximately 8.57 Hz cadence; floating-point boundaries; invalid intervals;
and existing real-delta velocity semantics. The conservative UI pass retains
the five established UI test methods.
Prompt 9 adds deterministic coverage for warning-versus-hard failure
semantics, removal of the invalid-neutral fallback, irregular-time calibration
diagnostics, ordered unsampled face-loss events, full-duration evidence,
retry isolation, raw-frame immutability, protocol completeness, live
acquisition-event priority over stale sampled-frame QC, and the
17/18-valid-repetition case. The suite now contains 169 unit tests: 167 pass
and two existing direct `CaptureSessionViewModel` checks skip in the simulator
because that view model eagerly constructs `ARSession`. All five UI-test
methods pass across six executions.

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

Measurement / image synchronization.

Prompt 9 calibration/QC is complete in code pending physical retry
verification. Zero eligible frames now fail; no zero or hard-invalid fallback
baseline is produced; task navigation waits for explicit calibration success;
and retry uses a fresh candidate set. The physical failure in which a face was
briefly visible and then absent was traced to a no-face transition being able
to fall inside the scientific sampling gate, followed by an evaluator that
accepted any remaining eligible frame. Attempt events now bypass that sampling
gate for calibration evidence only, and the evaluator requires the continuous
2.35-second trustworthy interval described above. Live calibration status is
published through the calibration view's observed view model and prioritizes
the latest ordered attempt event, so no-face, multiple-face, and limited
tracking states replace stale sampled-frame `QC Passing` immediately. Failed-attempt frames remain truthful historical
captures in the in-memory session record, but Prompt 9 adds no persisted
attempt-group schema. The formerly incomplete physical run with four missing
tasks would now fail. A complete 17/18-valid run remains valid when all
configured attempts exist and each task retains at least one valid repetition.

Prompt 8 timestamp-aware processing remains active. Physical cadence remains
variable around 8.57–10 Hz, five-sample smoothing is unchanged, and symmetry,
signed velocity, and hold-stability interpretation remain future scientific
issues. Exact measurement/image synchronization, absolute image paths, and the
`private` ZIP-prefix issue remain unresolved. Mesh and landmarks remain
inactive; empirical calibration thresholds require broader participant data;
no clinical validation is claimed. The Prompt 8 capture-button label overlap
was corrected without changing actions, timing, or capture state.

## Presentation status

A conservative presentation-only polish pass introduced adaptive solid
backgrounds, restrained cards and borders, consistent action styles, clearer
status badges, and stronger hierarchy across setup, readiness, calibration,
task capture, session summary, and previous sessions. It uses no gradients and
changes no routes, workflows, capture behavior, scientific processing, export
actions, or data-entry behavior.
