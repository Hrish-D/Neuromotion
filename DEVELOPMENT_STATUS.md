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

Prompt 10 creates each tracking measurement and optional RGB validation-image
source from one `ARFrame` snapshot. `SynchronizedFaceObservation` carries the
copied face observation, same-frame camera tracking context, and transient RGB
source through the unchanged sampling gate. Only accepted indexes 0, 10, 20,
and so on are synchronously encoded. Persisted raw frames and the additive
validation manifest record raw-frame identity, measurement/image timestamps,
and synchronization status without persisting ARKit reference objects.

Prompt 11 extends that envelope with a complete, fully owned face-mesh snapshot
copied synchronously from the same selected `ARFaceAnchor.geometry` before the
AR session callback returns. The copied snapshot crosses the existing
0.1-second collector gate; only accepted observations become
`RawFaceMeshFrame` values. Each mesh frame links to exactly one
`RawFrameCapture` UUID and preserves unmodified face-local Float XYZ positions.
Constant topology is stored separately and identified by a Facework SHA-256
digest over canonical little-endian counts, triangle indices, and texture
coordinates. Missing, invalid, or incompatible geometry never removes the
numerical raw frame and never produces fabricated vertices.

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
  raw schema `4.0.0`, analysis algorithm `0.3.0`, capture protocol `0.4.0`,
  mesh capture `1.0.0`, and landmarks `not-active`.
- Independent immutable raw acquisition persistence in `raw_frames.json`,
  including source timestamps, AR coefficients, copied transform and pose,
  face observation state/count/framing placeholders, recording context,
  same-frame camera tracking context, and explicitly versioned validation-image
  association provenance.
- Immutable raw face-mesh positions for each accepted observation with usable
  geometry, one session topology, exact raw-frame linkage, explicit
  missing/incompatible records, and pre-export association validation.
- Generic topology-bound versionable landmark definitions and exact mesh-index
  extraction, with no production anatomical configuration active.
- Legacy metadata decoding that preserves historical fields without assigning
  current analysis or capture versions to old sessions.
- Generic physical-device application builds.

## Confirmed placeholders and unused components

- Legacy compatibility `FrameCapture.meshVertices` remains decodeable but is
  not populated by active capture and is not the Prompt 11 raw mesh stream.
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
- No production named facial-landmark indices or geometric range-of-motion
  algorithm are implemented. Generic index extraction exists only as a
  topology-validated foundation.
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
- New validation images, numerical measurements, and raw mesh snapshots
  originate from the same `ARFrame`/selected face anchor and share its
  timestamp. This does not establish simultaneous RGB/infrared or RGB/depth
  hardware exposure, depth synchronization, or clinical validity. Historical
  image associations remain `legacyUnverified`.
- `facialActivationTooHighAtNeutral` remains a diagnostic warning at its
  existing strict `> 0.15` boundary. It does not alone invalidate trustworthy
  acquisition because stable non-zero ARKit coefficients may represent
  anatomy, resting asymmetry, pathology, or model bias.
- Session validity requires established calibration, scientific frames for all
  six configured tasks, all configured repetition attempts, and at least one
  valid repetition per task. This permits an isolated failed repetition while
  rejecting missing or wholly unusable tasks.
- New tracking observations use the single selected `ARFrame.timestamp`; their
  blendshapes and transform come from that frame's face anchor and their RGB
  validation source comes from that frame's `capturedImage`.
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
version, and the centralized research version identity. Raw mesh capture is
active at `1.0.0`. Operational landmarks remain inactive, so
`landmarkConfigurationVersion` remains `not-active`; infrastructure alone does
not activate an unvalidated mapping.

Historical metadata without the versioned schema decodes with
`legacy-unknown`, `not-recorded`, and `not-active` values as appropriate.
Current version numbers are never imputed into legacy sessions. The in-memory
`wasLoadedFromLegacySchema` marker is not written to exports.

Raw schema `4.0.0` identifies sessions that add the authoritative linked raw
mesh stream and topology provenance. Raw schema `3.0.0` continues to identify
Prompt 10 sessions whose validation-image association
semantics record same-ARFrame provenance. Existing metadata that explicitly
records raw schema `1.0.0` or `2.0.0` retains
that identity, and metadata predating version fields remains `legacy-unknown`.
Legacy flat `FrameCapture` JSON still decodes without inventing observation
facts that were not historically stored. New analysis uses `0.3.0`; historical
sessions explicitly marked `0.1.0` retain that identity and unversioned sessions
remain `legacy-unknown`. Capture protocol `0.4.0` records same-ARFrame
measurement, mesh, and optional RGB acquisition without changing participant
workflow, task timing, or sampling cadence. Capture protocol `0.3.0` records same-ARFrame paired
measurement/RGB acquisition while preserving accepted sampling cadence.
Historical raw schema `2.0.0`, analysis `0.3.0`, and capture protocol `0.2.0`
remain unchanged when decoded. Mesh and landmark states remain `not-active`.

The installed iPhoneOS 26.2 SDK declares runtime vertex, triangle-index, and
texture-coordinate arrays plus triangle count, and documents constant
triangle/vertex counts with only positions changing frame-to-frame. It does not
publish numeric physical-device counts. The simulator neutral-geometry
constructor reports 0 vertices, 0 triangles, and 0 texture coordinates and is
not a TrueDepth topology measurement; actual device counts and topology ID must
be recorded during Prompt 11 physical verification.

Raw positions use ARKit face-anchor coordinates and meter/Float semantics with
no transform, centering, smoothing, denoising, interpolation, or side reversal.
Positive X is viewer-right / subject-left, positive Y is up, and native ARKit
right-handed orientation is preserved. The existing same-frame face transform
supports future derived world-coordinate conversion without duplicating
world-space vertices.

`raw_frames.json` remains authoritative for general observations.
`raw_face_mesh_frames.json` contains linked dynamic frames plus explicit
unavailable-frame records; `face_mesh_topology.json` contains the topology once;
and `face_mesh_summary.json` contains only counts and topology identity. Existing
Prompt 10 files, CSVs, images, ZIP, and sharing remain additive and unchanged.
No vertex arrays are added to merged CSVs or session summary. No virtual or
interpolated points, custom vision model, pixel projection, or clinical anatomy
mapping is introduced by Prompt 11.

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
17/18-valid-repetition case. Prompt 10 adds same-source envelope, close-frame
identity, unchanged sampling/stride, repetition isolation, write-failure,
manifest provenance, raw round-trip, and legacy-unverified coverage. The suite
also contains Prompt 11 deterministic coverage for same-source
measurement/mesh/image identity, accepted-sample and repetition isolation,
raw linkage, missing/incompatible geometry, topology identity and round trips,
structured export separation, QC independence, generic topology-bound
landmark validation/extraction, current identity, and historical truthfulness.
Exact final Prompt 11 suite totals are recorded in the implementation report.

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

Prompt 10 physical verification subsequently completed on a real TrueDepth
iPhone: 512 raw and processed frames, 18/18 valid repetitions, 54/54 JPEG and
manifest associations linked to real raw UUIDs, exact measurement/image
timestamp equality, `sameARFrame` status throughout, no duplicate/decreasing
timestamps, no non-finite values, approximately 8.57 Hz accepted cadence, and
Prompt 9 retry-baseline isolation preserved. Accepted-cadence consistency
remains an outstanding scientific limitation.

Use synthetic or consenting non-identifiable data during development. Exported
participant sessions, research data, facial images, and local logs must remain
outside version control.

## Next implementation phase

Face-mesh inspection, research landmark mapping, and regional geometry definitions.

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
issues. Absolute image paths and the `private` ZIP-prefix issue remain
unresolved. Prompt 11 guarantees same-ARFrame RGB/measurement/mesh provenance.
Depth and infrared synchronization remain unimplemented. No production
landmark mapping, virtual/interpolated point, physician configuration UI,
custom model, new clinical score, or clinical validation exists. Empirical
calibration thresholds require broader participant data. The Prompt 8 capture-button label overlap
was corrected without changing actions, timing, or capture state.

## Presentation status

A conservative presentation-only polish pass introduced adaptive solid
backgrounds, restrained cards and borders, consistent action styles, clearer
status badges, and stronger hierarchy across setup, readiness, calibration,
task capture, session summary, and previous sessions. It uses no gradients and
changes no routes, workflows, capture behavior, scientific processing, export
actions, or data-entry behavior.
