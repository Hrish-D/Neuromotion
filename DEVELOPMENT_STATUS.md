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

Prompt 12 is complete in code and adds a research-only inspector for those stored immutable artifacts.
`Previous Sessions` opens one selected raw mesh frame at a time in a SceneKit
viewport without starting ARKit. Pure value services provide deterministic
selection, topology neighbors, same-index trajectories, and explicit-neutral
displacement. Separately stored research drafts contain manually labeled
vertex landmarks, regions, lines, ordered polylines, and three-point planes.
Every draft is bound to its exact topology ID and remains lifecycle `draft`.

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
- Stored-session mesh inspection with vertex tap/search, exact raw XYZ display,
  orientation presets, explicit neutral reference selection, raw trajectories,
  and research-only displacement display.
- Separate topology-bound draft import/export for manually named landmarks,
  explicit subject-side labels, regions, lines, polylines, and planes.
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
not a TrueDepth topology measurement. Prompt 11 physical verification measured
1,220 vertices, 2,304 triangles, 6,912 triangle indices, and 1,220 texture
coordinates. The observed topology ID was
`facework-sha256-v1:7dbc22bf4074390b33db8d71059768b48a7a5199b9d3c3fc199ef4c91893376e`.

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

Prompt 12 writes annotations only to
`research_face_geometry_configuration.json`. Import rejects topology mismatch
and unknown vertices/references without remapping. Coordinates remain meters
internally; millimeters are display-only. Editable side labels are explicit
`subjectLeft`, `subjectRight`, `midline`, or `unspecified` and are never inferred
clinically. No RGB overlay is attempted because exact offline projection would
also require persisted camera projection/intrinsics and complete image
orientation, crop, and resize provenance.

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
Prompt 12 editor-correction verification executes 225 unit tests: 223 pass,
zero fail, and the same two simulator ARSession characterization tests skip.
The 27 focused mesh-inspection/editor tests all pass. All six UI test
executions pass without changing the five established UI methods.

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

Prompt 11 physical verification subsequently completed with 490 raw frames,
490 processed frames, 490 available mesh frames, zero missing mesh frames, 54
validation images, and 18/18 valid repetitions. The mesh topology and identity
matched the physical characterization documented above.

Initial Prompt 12 physical inspection confirmed that the stored session,
1,220/2,304 topology, 490 mesh frames, task/frame controls, and vertex-index
selection loaded correctly, but every SceneKit visual layer rendered blank on
the real iPhone. The renderer placed its camera only 0.35 m from the uncentered
mesh while leaving SceneKit's default near clipping plane unchanged, so the
mesh, point primitives, and selected-marker spheres could all be clipped. The
correction now computes each selected frame's bounds, centers it only in the
display node, derives orthographic scale and explicit near/far planes from the
rotated bounds and viewport aspect ratio, and uses opaque constant-lit colors
and larger point markers. Presets reframe automatically and Reset View returns
to deterministic Front framing. Raw mesh data and all scientific versions are
unchanged. Prompt 12 remains pending this focused physical rendering retest.

The index field intentionally retains the iOS number pad. Negative and
nonnumeric invalid values remain automated-test cases; the focused physical
invalid case is the dynamic upper boundary (`topology.vertexCount`, physically
1,220), with feedback displayed beside the search field. No hard-coded 1,219
validation rule was introduced.

The successful physical rendering retest exposed the next editor-layer issues:
draft-region membership and landmark selection were disconnected, geometry
creation depended on remembered landmark toggles and implicit creation order,
and saved draft objects had no useful mesh overlays. The physical draft export
contained three valid lines named `Test line` although the intended test called
for one. Static audit confirmed that each button press created one line; the
shared toggle set and name persisted, allowing three presses with different
pairs to create A–B, B–C, and A–C without visible endpoint confirmation. The
corrected editor now offers named-landmark or explicit raw-vertex point choices,
visible A/B line and A/B/C plane builders, an ordered polyline builder, current
region add/remove/clear feedback, saved-object inspection and safe deletion,
and display-only SceneKit overlays for landmarks, saved/current regions, lines,
polylines, and planes. Successful builders and saved-region creation clear
their temporary state. Imported historical drafts—including the valid
three-line physical export—retain the same Codable schema and immediately
restore overlays. Prompt 12 remains pending final corrected human workflow
verification; raw acquisition, analysis, topology binding, and all five
scientific version values are unchanged.

Use synthetic or consenting non-identifiable data during development. Exported
participant sessions, research data, facial images, and local logs must remain
outside version control.

## Prompt 13 candidate geometry measurement engine

Prompt 13 is implemented in code and awaits physical offline verification. It
keeps immutable Prompt 11 raw meshes, editable Prompt 12 drafts, frozen research
candidates, measurement definitions, and derived results as separate layers.
Freezing creates a new `CandidateFaceGeometryConfiguration` with status
`candidateForReview`, the required topology identity, source-draft provenance,
explicit bilateral landmark/region pairs, an optional scale-reference line, and
a deterministic SHA-256 hash of measurement-relevant content. Candidate labels
remain researcher supplied; the app ships no anatomical vertex map and makes no
clinical-validation claim.

Offline analysis uses an explicitly selected set of mesh frames known by the
researcher to belong to the final successful neutral attempt. This is necessary
because historical Prompt 9 raw data preserve `isNeutralPhase` but not a durable
calibration-attempt/success identifier. The engine never guesses across retries.
For every required vertex it computes a component-wise median of the selected
raw face-local coordinates. The median is deterministic and less sensitive to
isolated outliers than a mean, but is a research estimator, not a clinically
validated baseline. Neutral provenance records contributing mesh/raw UUIDs,
source timestamps, count, span, missing/excluded counts, reasons, and sparse-data
warnings. With no usable reference, analysis reports `missingNeutralReference`;
it never substitutes zeros.

All geometry calculations are pure, offline, and use `Double` derived math while
leaving raw `Float` vertices unchanged. Coordinates remain ARKit face-local
metres: +X is viewer-right/subject-left, +Y superior, and +Z anterior toward the
viewer. Subject-left outward movement is +dx; subject-right outward movement is
-dx; midline/unspecified outward movement is unavailable. Bilateral comparisons
mirror only the right displacement's X component across the YZ plane.

Frame results include raw/baseline/delta landmark coordinates, magnitude and
subject-oriented components; bilateral magnitude difference, mirrored-vector
mismatch, and bounded asymmetry when its denominator is nonzero; current,
neutral, changed, percent, and optionally normalized line/polyline lengths;
region current/neutral centroids, centroid vector/magnitude, RMS vertex motion,
mean vertex magnitude, and maximum vertex magnitude; bilateral regional
centroid/RMS differences and mirrored-vector mismatch without vertex-to-vertex
correspondence; and plane normals, triangle areas, and unsigned orientation
change. RMS captures deformation that can cancel in a centroid. Plane-normal
sign is ignored for geometric orientation. None of these quantities is a
clinical score.

Every derived frame retains source session, recording, raw-frame, mesh-frame,
timestamp, task/repetition/frame, topology, candidate ID/version/hash, neutral
reference, measurement schema, and analysis-version provenance. Repetition
summaries use exact stored timestamps and preserve individual measurement
series. Task exports retain every repetition and deliberately omit a single
aggregate across unlike units. Non-finite and unavailable quantities use
explicit statuses/optional values; JSON never receives fabricated zero, NaN, or
Infinity.

Derived artifacts are separate from raw acquisition:
`candidate_face_geometry_configuration.json`,
`face_geometry_measurements.json`,
`face_geometry_measurement_summary.json`, and
`face_geometry_neutral_reference.json`. Draft and matching candidate artifacts
reload in the stored-session inspector. The research UI adds side-aware pairing,
optional scale selection, candidate freezing/review identity, explicit neutral
frame selection, offline analysis/export, selected-frame landmark/bilateral/
region inspection, and a display-only neutral-to-current vector. No AR session,
raw capture, raw schema, capture protocol, mesh schema, existing movement metric,
machine learning, virtual point, or clinical score was changed.

Current identity is raw schema `4.0.0`, analysis algorithm `0.4.0`, capture
protocol `0.4.0`, mesh capture `1.0.0`, and landmark configuration
`not-active`. Derived face-geometry measurement schema is `1.0.0`. Historical
Prompt 11/12 source metadata remains `0.3.0`; new Prompt 13 exports separately
state measurement analysis `0.4.0`. A production clinician-validated landmark
configuration still does not exist.

Automated Prompt 13 verification now executes 251 unit tests: 249 pass, zero
fail, and the same two simulator ARSession characterization tests skip. The 18
focused measurement-engine tests and seven Prompt 13 workflow/reachability and
region-side compatibility regressions pass, as do all six UI executions. A
representative sequential synthetic workload containing 490 frames with 1,220
stored vertices per frame completed in 0.019 seconds on the development host;
this is development evidence, not a physical-iPhone runtime claim. The generic
unsigned iOS build succeeds. Physical offline measurement verification remains
required.

Prompt 13 physical correction 1 remains pending focused device retest. The
measurement engine and its model tests existed, but the physical inspector
showed two correctly side-labelled landmarks while exposing only Prompt 12
draft controls. The original Prompt 13 SwiftUI was a single collapsed
`Candidate measurement configuration` disclosure nested inside the already
long Prompt 12 card; candidate export happened implicitly during freeze and
the other derived exports happened implicitly during analysis. There was no
mesh-inspector UI reachability test, so the prior report overstated the
physical workflow contract.

The inspector now presents a separate `Prompt 13 Analysis Configuration` card
after the Prompt 12 editor. Its independently reachable disclosures are
Bilateral Landmark Pairs, Bilateral Region Pairs, Scale Reference, Candidate
Configuration, Neutral Reference, Analysis, and Prompt 13 Analysis Exports.
Pair builders show subject-side metadata and vertex/region context, remain
available before freezing, list saved pairs, and support deletion/recreation.
Candidate review shows draft/topology/count provenance before freezing and the
frozen ID/version/hash/topology/source afterward. Neutral and analysis controls
remain visible with explicit prerequisites; neutral creation records selected
frame count/span/reference provenance. Each of the four Prompt 13 artifacts
has a separate export action. This correction changes UI organization and
workflow state only: raw acquisition, median baseline, bilateral/region/plane
math, timestamps, hashing, schemas, and all scientific version values are
unchanged. Prompt 13 is not physically complete.

Prompt 13 physical correction 2 addresses the next device-discovered workflow
blocker: draft regions stored side metadata, but the only side picker was placed
in the landmark form and shared implicitly with region creation. The region form
now has its own explicit `Region side` selector, saved-region rows show side and
vertex count, and mutable draft regions can have side metadata corrected before
candidate freezing. Bilateral region selectors continue to admit only explicit
subject-left and subject-right regions; no coordinate, centroid, screen-position,
or vertex-index inference is performed. Draft JSON with an explicit unspecified
side remains unchanged, and a missing historical region-side key now decodes
conservatively as `unspecified`. Candidate immutability, hashes, measurement
mathematics, schemas, and scientific versions are unchanged. Focused physical
region-side verification remains required.

Prompt 13 physical correction 3 completes the candidate measurement inspector
and repetition-summary coverage after physical/export audit. Frame JSON already
contained bilateral-region results, but the on-device panel omitted them and
used UUIDs as primary labels. The panel now resolves immutable candidate display
names, exposes candidate-landmark raw/neutral/delta and subject-oriented values,
and displays individual regions plus complete bilateral landmark and bilateral
region quantities. Scientific IDs remain in the derived exports.

Repetition summaries now retain all primary scalar identities: landmark
magnitude; region centroid magnitude, RMS, mean magnitude, and maximum
magnitude; bilateral landmark difference, mismatch, and asymmetry; bilateral
region centroid difference, centroid mismatch, centroid asymmetry, RMS
difference, and RMS asymmetry; line/polyline length change; and plane area and
orientation change. Records remain present when every sample is unavailable.
Units are deterministic from the metric identity: distance quantities are
metres, region/plane area change is square metres, plane orientation is degrees,
and asymmetry indices are dimensionless. Unlike units are never aggregated
together. This completes the unreleased measurement schema `1.0.0`; equations,
candidate hashes, raw data, and all scientific versions remain unchanged.

## Next implementation phase

Prompt 13 physical offline measurement verification, followed by a separately
scoped clinician-review/reliability phase. Prompt 14 has not begun.

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
custom model, new clinical score, or clinical validation exists. Prompt 12
creates draft-only research annotations and does not activate a production
landmark configuration or change raw, capture, analysis, or mesh versions. Empirical
calibration thresholds require broader participant data. The Prompt 8 capture-button label overlap
was corrected without changing actions, timing, or capture state.

## Presentation status

A conservative presentation-only polish pass introduced adaptive solid
backgrounds, restrained cards and borders, consistent action styles, clearer
status badges, and stronger hierarchy across setup, readiness, calibration,
task capture, session summary, and previous sessions. It uses no gradients and
changes no routes, workflows, capture behavior, scientific processing, export
actions, or data-entry behavior.
