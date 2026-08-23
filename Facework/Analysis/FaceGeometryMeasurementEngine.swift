import CryptoKit
import Foundation
import simd

nonisolated struct GeometryVector3: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let z: Double
    init(x: Double, y: Double, z: Double) { self.x = x; self.y = y; self.z = z }
    init(_ vertex: FaceMeshVertex) { self.init(x: Double(vertex.x), y: Double(vertex.y), z: Double(vertex.z)) }
    static let zero = GeometryVector3(x: 0, y: 0, z: 0)
    var magnitude: Double { sqrt(x * x + y * y + z * z) }
    var millimetres: GeometryVector3 { .init(x: x * 1_000, y: y * 1_000, z: z * 1_000) }
    var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
    static func - (lhs: Self, rhs: Self) -> Self { .init(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z) }
    static func + (lhs: Self, rhs: Self) -> Self { .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z) }
    static func / (lhs: Self, rhs: Double) -> Self { .init(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs) }
}

nonisolated enum FaceGeometryMath {
    static let epsilon = 1e-12
    static func distance(_ a: GeometryVector3, _ b: GeometryVector3) -> Double { (a - b).magnitude }
    static func mirrorAcrossYZ(_ value: GeometryVector3) -> GeometryVector3 { .init(x: -value.x, y: value.y, z: value.z) }
    static func centroid(_ values: [GeometryVector3]) -> GeometryVector3? {
        guard !values.isEmpty, values.allSatisfy(\.isFinite) else { return nil }
        return values.reduce(.zero, +) / Double(values.count)
    }
    static func median(_ values: [Double]) -> Double? {
        let sorted = values.filter(\.isFinite).sorted()
        guard sorted.count == values.count, !sorted.isEmpty else { return nil }
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
    static func componentMedian(_ values: [GeometryVector3]) -> GeometryVector3? {
        guard let x = median(values.map(\.x)), let y = median(values.map(\.y)), let z = median(values.map(\.z)) else { return nil }
        return .init(x: x, y: y, z: z)
    }
    static func pathLength(_ values: [GeometryVector3]) -> Double? {
        guard values.count >= 2, values.allSatisfy(\.isFinite) else { return nil }
        return zip(values, values.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
    }
    static func cross(_ a: GeometryVector3, _ b: GeometryVector3) -> GeometryVector3 {
        .init(x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x)
    }
    static func dot(_ a: GeometryVector3, _ b: GeometryVector3) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }
    static func normalized(_ value: GeometryVector3) -> GeometryVector3? {
        let length = value.magnitude
        guard length.isFinite, length > epsilon else { return nil }
        return value / length
    }
    static func asymmetryIndex(_ left: Double, _ right: Double) -> Double? {
        let denominator = left + right
        guard left.isFinite, right.isFinite, denominator > epsilon else { return nil }
        return abs(left - right) / denominator
    }
}

nonisolated struct FaceGeometryNeutralReference: Codable, Equatable, Sendable {
    let neutralReferenceID: String
    let sourceSessionID: String
    let topologyID: String
    let contributingRawFrameIDs: [UUID]
    let contributingMeshFrameIDs: [UUID]
    let contributingSourceTimestamps: [TimeInterval]
    let neutralFrameCount: Int
    let neutralTimeSpanSeconds: TimeInterval
    let missingMeshFrameCount: Int
    let excludedFrameCount: Int
    let exclusionReasons: [String]
    let baselineByVertexIndex: [Int: GeometryVector3]
    let researchQCWarnings: [String]
}

nonisolated enum FaceGeometryMeasurementStatus: String, Codable, Sendable {
    case available, missingNeutralReference, missingMeshFrame, missingVertex, topologyMismatch
    case invalidPointReference, degeneratePlane, invalidScaleReference, nonFiniteInput
}

nonisolated struct LandmarkFrameMeasurement: Codable, Equatable, Identifiable, Sendable {
    let landmarkID: String
    var id: String { landmarkID }
    let status: FaceGeometryMeasurementStatus
    let raw: GeometryVector3?
    let baseline: GeometryVector3?
    let delta: GeometryVector3?
    let displacementMagnitudeMeters: Double?
    let outwardLateralDisplacementMeters: Double?
    let superiorDisplacementMeters: Double?
    let anteriorDisplacementMeters: Double?
}

nonisolated struct BilateralLandmarkFrameMeasurement: Codable, Equatable, Identifiable, Sendable {
    let pairID: String
    var id: String { pairID }
    let status: FaceGeometryMeasurementStatus
    let leftMagnitudeMeters: Double?
    let rightMagnitudeMeters: Double?
    let magnitudeDifferenceMeters: Double?
    let vectorMismatchMeters: Double?
    let asymmetryIndex: Double?
}

nonisolated struct LengthFrameMeasurement: Codable, Equatable, Identifiable, Sendable {
    let definitionID: String
    var id: String { definitionID }
    let status: FaceGeometryMeasurementStatus
    let currentLengthMeters: Double?
    let neutralLengthMeters: Double?
    let lengthChangeMeters: Double?
    let percentChange: Double?
    let normalizedCurrentLength: Double?
}

nonisolated struct RegionFrameMeasurement: Codable, Equatable, Identifiable, Sendable {
    let regionID: String
    var id: String { regionID }
    let status: FaceGeometryMeasurementStatus
    let centroidCurrent: GeometryVector3?
    let centroidNeutral: GeometryVector3?
    let centroidDelta: GeometryVector3?
    let centroidDisplacementMagnitudeMeters: Double?
    let rmsVertexDisplacementMeters: Double?
    let meanVertexDisplacementMagnitudeMeters: Double?
    let maximumVertexDisplacementMagnitudeMeters: Double?
}

nonisolated struct BilateralRegionFrameMeasurement: Codable, Equatable, Identifiable, Sendable {
    let pairID: String
    var id: String { pairID }
    let status: FaceGeometryMeasurementStatus
    let leftCentroidMagnitudeMeters: Double?
    let rightCentroidMagnitudeMeters: Double?
    let absoluteCentroidDifferenceMeters: Double?
    let leftRMSMeters: Double?
    let rightRMSMeters: Double?
    let absoluteRMSDifferenceMeters: Double?
    let centroidVectorMismatchMeters: Double?
    let centroidAsymmetryIndex: Double?
    let rmsAsymmetryIndex: Double?
}

nonisolated struct PlaneFrameMeasurement: Codable, Equatable, Identifiable, Sendable {
    let planeID: String
    var id: String { planeID }
    let status: FaceGeometryMeasurementStatus
    let currentNormal: GeometryVector3?
    let neutralNormal: GeometryVector3?
    let currentTriangleAreaSquareMeters: Double?
    let neutralTriangleAreaSquareMeters: Double?
    let orientationChangeDegrees: Double?
}

nonisolated struct FaceGeometryFrameMeasurements: Codable, Equatable, Identifiable, Sendable {
    let measurementSchemaVersion: String
    let measurementAnalysisAlgorithmVersion: String
    let sourceSessionAnalysisAlgorithmVersion: String
    let sourceSessionID: String
    let recordingID: UUID
    let rawFrameID: UUID
    let rawFaceMeshFrameID: UUID
    var id: UUID { rawFaceMeshFrameID }
    let sourceTimestamp: TimeInterval
    let taskType: TaskType
    let repetitionIndex: Int
    let frameIndex: Int
    let topologyID: String
    let candidateConfigurationID: String
    let candidateConfigurationVersion: String
    let candidateConfigurationHash: String
    let neutralReferenceID: String
    let measurementStatus: FaceGeometryMeasurementStatus
    let landmarks: [LandmarkFrameMeasurement]
    let bilateralLandmarks: [BilateralLandmarkFrameMeasurement]
    let lines: [LengthFrameMeasurement]
    let polylines: [LengthFrameMeasurement]
    let regions: [RegionFrameMeasurement]
    let bilateralRegions: [BilateralRegionFrameMeasurement]
    let planes: [PlaneFrameMeasurement]
}

nonisolated struct FaceGeometrySeriesSummary: Codable, Equatable, Identifiable, Sendable {
    let measurementID: String
    var id: String { "\(taskType.rawValue)|\(repetitionIndex)|\(measurementID)" }
    let taskType: TaskType
    let repetitionIndex: Int
    let sampleCount: Int
    let availableSampleCount: Int
    let unavailableSampleCount: Int
    let firstTimestamp: TimeInterval?
    let lastTimestamp: TimeInterval?
    let durationSeconds: TimeInterval?
    let neutralValue: Double?
    let minimumValue: Double?
    let maximumValue: Double?
    let peakAbsoluteChangeFromNeutral: Double?
    let peakTimestamp: TimeInterval?
    let timeToPeakSeconds: TimeInterval?
}

nonisolated struct FaceGeometryTaskSummary: Codable, Equatable, Identifiable, Sendable {
    let taskType: TaskType
    var id: TaskType { taskType }
    let repetitions: [FaceGeometrySeriesSummary]
    let medianPeak: Double?
    let minimumPeak: Double?
    let maximumPeak: Double?
}

nonisolated struct FaceGeometryMeasurementPackage: Codable, Equatable, Sendable {
    let measurementSchemaVersion: String
    let measurementAnalysisAlgorithmVersion: String
    let sourceSessionAnalysisAlgorithmVersion: String
    let sourceSessionID: String
    let topologyID: String
    let candidateConfigurationID: String
    let candidateConfigurationVersion: String
    let candidateConfigurationHash: String
    let neutralReference: FaceGeometryNeutralReference
    let frames: [FaceGeometryFrameMeasurements]
    let unavailableMeshFrames: [FaceGeometryUnavailableMeshFrameMeasurement]
    let repetitionSummaries: [FaceGeometrySeriesSummary]
    let taskSummaries: [FaceGeometryTaskSummary]
}

nonisolated struct FaceGeometryUnavailableMeshFrameMeasurement: Codable, Equatable, Identifiable, Sendable {
    var id: UUID { rawFrameID }
    let sourceSessionID: String
    let rawFrameID: UUID
    let recordingID: UUID?
    let sourceTimestamp: TimeInterval
    let taskType: TaskType
    let repetitionIndex: Int
    let frameIndex: Int
    let topologyID: String
    let candidateConfigurationID: String
    let candidateConfigurationHash: String
    let neutralReferenceID: String
    let measurementStatus: FaceGeometryMeasurementStatus
    let sourceMeshAvailability: RawFaceMeshAvailability
}

nonisolated enum FaceGeometryMeasurementIdentity {
    static let schemaVersion = "1.0.0"
    static let analysisAlgorithmVersion = "0.4.0"
}

nonisolated enum FaceGeometryMeasurementEngineError: Error, Equatable, Sendable {
    case topologyMismatch
    case invalidConfiguration([CandidateConfigurationIssue])
    case missingNeutralReference
}

nonisolated struct FaceGeometryMeasurementEngine {
    func analyze(session: StoredFaceMeshSession, candidate: CandidateFaceGeometryConfiguration,
                 selectedNeutralMeshFrameIDs: Set<UUID>) -> Result<FaceGeometryMeasurementPackage, FaceGeometryMeasurementEngineError> {
        guard candidate.requiredTopologyID == session.topology.topologyID else { return .failure(.topologyMismatch) }
        let issues = CandidateConfigurationValidator.validate(candidate, topology: session.topology, frame: session.meshExport.frames.first)
        guard issues.isEmpty else { return .failure(.invalidConfiguration(issues)) }
        guard let neutral = buildNeutralReference(session: session, candidate: candidate, selectedMeshFrameIDs: selectedNeutralMeshFrameIDs) else {
            return .failure(.missingNeutralReference)
        }
        let frames = session.meshExport.frames.sorted { lhs, rhs in
            (lhs.sourceTimestamp, lhs.id.uuidString) < (rhs.sourceTimestamp, rhs.id.uuidString)
        }.map { measure(frame: $0, session: session, candidate: candidate, neutral: neutral) }
        let unavailable = session.meshExport.unavailableFrames.sorted {
            ($0.sourceTimestamp, $0.rawFrameID.uuidString) < ($1.sourceTimestamp, $1.rawFrameID.uuidString)
        }.map {
            FaceGeometryUnavailableMeshFrameMeasurement(
                sourceSessionID: session.metadata.sessionID, rawFrameID: $0.rawFrameID,
                recordingID: $0.recordingID, sourceTimestamp: $0.sourceTimestamp,
                taskType: $0.taskType, repetitionIndex: $0.repetitionIndex, frameIndex: $0.frameIndex,
                topologyID: session.topology.topologyID,
                candidateConfigurationID: candidate.configurationID,
                candidateConfigurationHash: candidate.configurationHash,
                neutralReferenceID: neutral.neutralReferenceID, measurementStatus: .missingMeshFrame,
                sourceMeshAvailability: $0.reason
            )
        }
        let summaries = summarize(frames: frames)
        let tasks = summarizeTasks(summaries)
        return .success(.init(
            measurementSchemaVersion: FaceGeometryMeasurementIdentity.schemaVersion,
            measurementAnalysisAlgorithmVersion: FaceGeometryMeasurementIdentity.analysisAlgorithmVersion,
            sourceSessionAnalysisAlgorithmVersion: session.metadata.analysisAlgorithmVersion,
            sourceSessionID: session.metadata.sessionID, topologyID: session.topology.topologyID,
            candidateConfigurationID: candidate.configurationID,
            candidateConfigurationVersion: candidate.configurationVersion,
            candidateConfigurationHash: candidate.configurationHash,
            neutralReference: neutral, frames: frames, unavailableMeshFrames: unavailable,
            repetitionSummaries: summaries, taskSummaries: tasks
        ))
    }

    func buildNeutralReference(session: StoredFaceMeshSession, candidate: CandidateFaceGeometryConfiguration,
                               selectedMeshFrameIDs: Set<UUID>) -> FaceGeometryNeutralReference? {
        let selected = session.meshExport.frames.filter { selectedMeshFrameIDs.contains($0.id) }
        let rawByID = Dictionary(uniqueKeysWithValues: session.rawFrames.map { ($0.id, $0) })
        let eligible = selected.filter { frame in
            frame.taskType == .neutralRest && rawByID[frame.rawFrameID]?.isNeutralPhase == true &&
            frame.vertices.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }
        }.sorted { $0.sourceTimestamp < $1.sourceTimestamp }
        guard !eligible.isEmpty else { return nil }
        let required = requiredVertexIndices(candidate)
        var baseline: [Int: GeometryVector3] = [:]
        for index in required {
            guard eligible.allSatisfy({ $0.vertices.indices.contains(index) }),
                  let median = FaceGeometryMath.componentMedian(eligible.map { GeometryVector3($0.vertices[index]) }) else { return nil }
            baseline[index] = median
        }
        let excluded = selected.count - eligible.count
        let firstTimestamp = eligible.first?.sourceTimestamp ?? 0
        let lastTimestamp = eligible.last?.sourceTimestamp ?? firstTimestamp
        let span = max(0, lastTimestamp - firstTimestamp)
        // Explicit selections define the successful-reference time window. Missing mesh
        // observations inside that window are reported, never filled or borrowed.
        let missing = session.meshExport.unavailableFrames.filter {
            $0.taskType == .neutralRest && $0.sourceTimestamp >= firstTimestamp && $0.sourceTimestamp <= lastTimestamp &&
            rawByID[$0.rawFrameID]?.isNeutralPhase == true
        }.count
        let warning = eligible.count < 3 ? ["Sparse neutral reference: fewer than three usable mesh frames."] : []
        let identityMaterial = eligible.map { "\($0.id.uuidString)|\($0.rawFrameID.uuidString)|\($0.sourceTimestamp)" }.joined(separator: "\n")
        let referenceID = "facework-neutral-v1:" + SHA256Digest.hex(identityMaterial)
        return .init(neutralReferenceID: referenceID, sourceSessionID: session.metadata.sessionID,
                     topologyID: session.topology.topologyID,
                     contributingRawFrameIDs: eligible.map(\.rawFrameID), contributingMeshFrameIDs: eligible.map(\.id),
                     contributingSourceTimestamps: eligible.map(\.sourceTimestamp), neutralFrameCount: eligible.count,
                     neutralTimeSpanSeconds: span, missingMeshFrameCount: missing, excludedFrameCount: excluded,
                     exclusionReasons: excluded > 0 ? ["Selected frames outside final successful neutral reference eligibility."] : [],
                     baselineByVertexIndex: baseline, researchQCWarnings: warning)
    }

    private func measure(frame: RawFaceMeshFrame, session: StoredFaceMeshSession,
                         candidate: CandidateFaceGeometryConfiguration, neutral: FaceGeometryNeutralReference) -> FaceGeometryFrameMeasurements {
        let landmarkByID = Dictionary(uniqueKeysWithValues: candidate.landmarks.map { ($0.id, $0) })
        func index(_ reference: FaceGeometryPointReference) -> Int? {
            switch reference { case .meshVertex(let value): return value; case .landmark(let id):
                guard case .meshVertex(let value)? = landmarkByID[id]?.source else { return nil }; return value }
        }
        func current(_ reference: FaceGeometryPointReference) -> GeometryVector3? {
            guard let i = index(reference), frame.vertices.indices.contains(i) else { return nil }; let value = GeometryVector3(frame.vertices[i]); return value.isFinite ? value : nil
        }
        func base(_ reference: FaceGeometryPointReference) -> GeometryVector3? { index(reference).flatMap { neutral.baselineByVertexIndex[$0] } }

        let landmarks = candidate.landmarks.map { landmark -> LandmarkFrameMeasurement in
            guard case .meshVertex(let i) = landmark.source, frame.vertices.indices.contains(i),
                  let baseline = neutral.baselineByVertexIndex[i] else {
                return .init(landmarkID: landmark.id, status: .missingVertex, raw: nil, baseline: nil, delta: nil,
                             displacementMagnitudeMeters: nil, outwardLateralDisplacementMeters: nil,
                             superiorDisplacementMeters: nil, anteriorDisplacementMeters: nil)
            }
            let raw = GeometryVector3(frame.vertices[i]), delta = raw - baseline
            guard raw.isFinite, baseline.isFinite, delta.isFinite, delta.magnitude.isFinite else {
                return .init(landmarkID: landmark.id, status: .nonFiniteInput, raw: nil, baseline: nil, delta: nil,
                             displacementMagnitudeMeters: nil, outwardLateralDisplacementMeters: nil,
                             superiorDisplacementMeters: nil, anteriorDisplacementMeters: nil)
            }
            let outward: Double? = landmark.side == .subjectLeft ? delta.x : landmark.side == .subjectRight ? -delta.x : nil
            return .init(landmarkID: landmark.id, status: .available, raw: raw, baseline: baseline, delta: delta,
                         displacementMagnitudeMeters: delta.magnitude, outwardLateralDisplacementMeters: outward,
                         superiorDisplacementMeters: delta.y, anteriorDisplacementMeters: delta.z)
        }
        let landmarkMeasurementByID = Dictionary(uniqueKeysWithValues: landmarks.map { ($0.landmarkID, $0) })
        let bilateralLandmarks = candidate.bilateralLandmarkPairs.map { pair -> BilateralLandmarkFrameMeasurement in
            guard let left = landmarkMeasurementByID[pair.subjectLeftLandmarkID], let right = landmarkMeasurementByID[pair.subjectRightLandmarkID],
                  let dl = left.delta, let dr = right.delta, let lm = left.displacementMagnitudeMeters, let rm = right.displacementMagnitudeMeters else {
                return .init(pairID: pair.id, status: .invalidPointReference, leftMagnitudeMeters: nil, rightMagnitudeMeters: nil,
                             magnitudeDifferenceMeters: nil, vectorMismatchMeters: nil, asymmetryIndex: nil)
            }
            let mismatch = (dl - FaceGeometryMath.mirrorAcrossYZ(dr)).magnitude
            return .init(pairID: pair.id, status: .available, leftMagnitudeMeters: lm, rightMagnitudeMeters: rm,
                         magnitudeDifferenceMeters: abs(lm - rm), vectorMismatchMeters: mismatch,
                         asymmetryIndex: FaceGeometryMath.asymmetryIndex(lm, rm))
        }
        let scaleNeutral: Double? = candidate.scaleReferenceLineID.flatMap { id in candidate.lines.first { $0.id == id } }.flatMap { line -> Double? in
            guard let a = base(line.endpointA), let b = base(line.endpointB) else { return nil }; return FaceGeometryMath.distance(a, b)
        }
        func length(_ id: String, _ references: [FaceGeometryPointReference]) -> LengthFrameMeasurement {
            let currentPoints = references.compactMap(current), neutralPoints = references.compactMap(base)
            guard currentPoints.count == references.count, neutralPoints.count == references.count,
                  let currentLength = FaceGeometryMath.pathLength(currentPoints), let neutralLength = FaceGeometryMath.pathLength(neutralPoints) else {
                return .init(definitionID: id, status: .invalidPointReference, currentLengthMeters: nil, neutralLengthMeters: nil,
                             lengthChangeMeters: nil, percentChange: nil, normalizedCurrentLength: nil)
            }
            let change = currentLength - neutralLength
            return .init(definitionID: id, status: .available, currentLengthMeters: currentLength, neutralLengthMeters: neutralLength,
                         lengthChangeMeters: change, percentChange: neutralLength > FaceGeometryMath.epsilon ? change / neutralLength : nil,
                         normalizedCurrentLength: scaleNeutral.flatMap { $0 > FaceGeometryMath.epsilon ? currentLength / $0 : nil })
        }
        let lines = candidate.lines.map { length($0.id, [$0.endpointA, $0.endpointB]) }
        let polylines = candidate.polylines.map { length($0.id, $0.points) }
        let regions = candidate.regions.map { region -> RegionFrameMeasurement in
            let currentPoints = region.vertexIndices.compactMap { frame.vertices.indices.contains($0) ? GeometryVector3(frame.vertices[$0]) : nil }
            let baselines = region.vertexIndices.compactMap { neutral.baselineByVertexIndex[$0] }
            guard currentPoints.count == region.vertexIndices.count, baselines.count == region.vertexIndices.count,
                  let currentCentroid = FaceGeometryMath.centroid(currentPoints), let neutralCentroid = FaceGeometryMath.centroid(baselines) else {
                return .init(regionID: region.id, status: .missingVertex, centroidCurrent: nil, centroidNeutral: nil, centroidDelta: nil,
                             centroidDisplacementMagnitudeMeters: nil, rmsVertexDisplacementMeters: nil,
                             meanVertexDisplacementMagnitudeMeters: nil, maximumVertexDisplacementMagnitudeMeters: nil)
            }
            let deltas = zip(currentPoints, baselines).map { $0.0 - $0.1 }, magnitudes = deltas.map(\.magnitude)
            let centroidDelta = currentCentroid - neutralCentroid
            let rms = sqrt(magnitudes.reduce(0) { $0 + $1 * $1 } / Double(magnitudes.count))
            return .init(regionID: region.id, status: .available, centroidCurrent: currentCentroid, centroidNeutral: neutralCentroid,
                         centroidDelta: centroidDelta, centroidDisplacementMagnitudeMeters: centroidDelta.magnitude,
                         rmsVertexDisplacementMeters: rms,
                         meanVertexDisplacementMagnitudeMeters: magnitudes.reduce(0, +) / Double(magnitudes.count),
                         maximumVertexDisplacementMagnitudeMeters: magnitudes.max())
        }
        let regionByID = Dictionary(uniqueKeysWithValues: regions.map { ($0.regionID, $0) })
        let bilateralRegions = candidate.bilateralRegionPairs.map { pair -> BilateralRegionFrameMeasurement in
            guard let left = regionByID[pair.subjectLeftRegionID], let right = regionByID[pair.subjectRightRegionID],
                  let ld = left.centroidDelta, let rd = right.centroidDelta,
                  let lm = left.centroidDisplacementMagnitudeMeters, let rm = right.centroidDisplacementMagnitudeMeters,
                  let lr = left.rmsVertexDisplacementMeters, let rr = right.rmsVertexDisplacementMeters else {
                return .init(pairID: pair.id, status: .invalidPointReference, leftCentroidMagnitudeMeters: nil,
                             rightCentroidMagnitudeMeters: nil, absoluteCentroidDifferenceMeters: nil, leftRMSMeters: nil,
                             rightRMSMeters: nil, absoluteRMSDifferenceMeters: nil, centroidVectorMismatchMeters: nil,
                             centroidAsymmetryIndex: nil, rmsAsymmetryIndex: nil)
            }
            return .init(pairID: pair.id, status: .available, leftCentroidMagnitudeMeters: lm, rightCentroidMagnitudeMeters: rm,
                         absoluteCentroidDifferenceMeters: abs(lm - rm), leftRMSMeters: lr, rightRMSMeters: rr,
                         absoluteRMSDifferenceMeters: abs(lr - rr), centroidVectorMismatchMeters: (ld - FaceGeometryMath.mirrorAcrossYZ(rd)).magnitude,
                         centroidAsymmetryIndex: FaceGeometryMath.asymmetryIndex(lm, rm), rmsAsymmetryIndex: FaceGeometryMath.asymmetryIndex(lr, rr))
        }
        func planeGeometry(_ points: [GeometryVector3]) -> (normal: GeometryVector3, area: Double)? {
            guard points.count == 3 else { return nil }
            let cross = FaceGeometryMath.cross(points[1] - points[0], points[2] - points[0])
            guard let normal = FaceGeometryMath.normalized(cross) else { return nil }
            return (normal, 0.5 * cross.magnitude)
        }
        let planes = candidate.planes.map { plane -> PlaneFrameMeasurement in
            let refs = [plane.pointA, plane.pointB, plane.pointC]
            guard let currentGeometry = planeGeometry(refs.compactMap(current)), let neutralGeometry = planeGeometry(refs.compactMap(base)) else {
                return .init(planeID: plane.id, status: .degeneratePlane, currentNormal: nil, neutralNormal: nil,
                             currentTriangleAreaSquareMeters: nil, neutralTriangleAreaSquareMeters: nil, orientationChangeDegrees: nil)
            }
            let dot = min(1, max(-1, abs(FaceGeometryMath.dot(currentGeometry.normal, neutralGeometry.normal))))
            return .init(planeID: plane.id, status: .available, currentNormal: currentGeometry.normal, neutralNormal: neutralGeometry.normal,
                         currentTriangleAreaSquareMeters: currentGeometry.area, neutralTriangleAreaSquareMeters: neutralGeometry.area,
                         orientationChangeDegrees: acos(dot) * 180 / .pi)
        }
        return .init(measurementSchemaVersion: FaceGeometryMeasurementIdentity.schemaVersion,
                     measurementAnalysisAlgorithmVersion: FaceGeometryMeasurementIdentity.analysisAlgorithmVersion,
                     sourceSessionAnalysisAlgorithmVersion: session.metadata.analysisAlgorithmVersion,
                     sourceSessionID: session.metadata.sessionID, recordingID: frame.recordingID, rawFrameID: frame.rawFrameID,
                     rawFaceMeshFrameID: frame.id, sourceTimestamp: frame.sourceTimestamp, taskType: frame.taskType,
                     repetitionIndex: frame.repetitionIndex, frameIndex: frame.frameIndex, topologyID: frame.topologyID,
                     candidateConfigurationID: candidate.configurationID, candidateConfigurationVersion: candidate.configurationVersion,
                     candidateConfigurationHash: candidate.configurationHash, neutralReferenceID: neutral.neutralReferenceID,
                     measurementStatus: .available, landmarks: landmarks, bilateralLandmarks: bilateralLandmarks,
                     lines: lines, polylines: polylines, regions: regions, bilateralRegions: bilateralRegions, planes: planes)
    }

    private func requiredVertexIndices(_ candidate: CandidateFaceGeometryConfiguration) -> Set<Int> {
        let landmarkByID = Dictionary(uniqueKeysWithValues: candidate.landmarks.map { ($0.id, $0) })
        func index(_ reference: FaceGeometryPointReference) -> Int? {
            switch reference { case .meshVertex(let index): return index; case .landmark(let id):
                guard case .meshVertex(let index)? = landmarkByID[id]?.source else { return nil }; return index }
        }
        var result = Set(candidate.landmarks.compactMap { if case .meshVertex(let i) = $0.source { i } else { nil } })
        result.formUnion(candidate.regions.flatMap(\.vertexIndices))
        for reference in candidate.lines.flatMap({ [$0.endpointA, $0.endpointB] }) + candidate.polylines.flatMap(\.points) + candidate.planes.flatMap({ [$0.pointA, $0.pointB, $0.pointC] }) {
            if let i = index(reference) { result.insert(i) }
        }
        return result
    }

    private func summarize(frames: [FaceGeometryFrameMeasurements]) -> [FaceGeometrySeriesSummary] {
        struct Key: Hashable { let task: TaskType; let repetition: Int; let id: String }
        var values: [Key: [(TimeInterval, Double?)]] = [:]
        for frame in frames {
            for value in frame.landmarks { values[.init(task: frame.taskType, repetition: frame.repetitionIndex, id: "landmark:\(value.landmarkID):magnitude"), default: []].append((frame.sourceTimestamp, value.displacementMagnitudeMeters)) }
            for value in frame.bilateralLandmarks {
                values[.init(task: frame.taskType, repetition: frame.repetitionIndex, id: "bilateralLandmark:\(value.pairID):magnitudeDifference"), default: []].append((frame.sourceTimestamp, value.magnitudeDifferenceMeters))
                values[.init(task: frame.taskType, repetition: frame.repetitionIndex, id: "bilateralLandmark:\(value.pairID):vectorMismatch"), default: []].append((frame.sourceTimestamp, value.vectorMismatchMeters))
                values[.init(task: frame.taskType, repetition: frame.repetitionIndex, id: "bilateralLandmark:\(value.pairID):asymmetryIndex"), default: []].append((frame.sourceTimestamp, value.asymmetryIndex))
            }
            for value in frame.lines { values[.init(task: frame.taskType, repetition: frame.repetitionIndex, id: "line:\(value.definitionID):lengthChange"), default: []].append((frame.sourceTimestamp, value.lengthChangeMeters)) }
            for value in frame.polylines { values[.init(task: frame.taskType, repetition: frame.repetitionIndex, id: "polyline:\(value.definitionID):lengthChange"), default: []].append((frame.sourceTimestamp, value.lengthChangeMeters)) }
            for value in frame.regions {
                values[.init(task: frame.taskType, repetition: frame.repetitionIndex, id: "region:\(value.regionID):centroidMagnitude"), default: []].append((frame.sourceTimestamp, value.centroidDisplacementMagnitudeMeters))
                values[.init(task: frame.taskType, repetition: frame.repetitionIndex, id: "region:\(value.regionID):rms"), default: []].append((frame.sourceTimestamp, value.rmsVertexDisplacementMeters))
                values[.init(task: frame.taskType, repetition: frame.repetitionIndex, id: "region:\(value.regionID):meanMagnitude"), default: []].append((frame.sourceTimestamp, value.meanVertexDisplacementMagnitudeMeters))
                values[.init(task: frame.taskType, repetition: frame.repetitionIndex, id: "region:\(value.regionID):maximumMagnitude"), default: []].append((frame.sourceTimestamp, value.maximumVertexDisplacementMagnitudeMeters))
            }
            for value in frame.bilateralRegions {
                values[.init(task: frame.taskType, repetition: frame.repetitionIndex, id: "bilateralRegion:\(value.pairID):absoluteCentroidDifference"), default: []].append((frame.sourceTimestamp, value.absoluteCentroidDifferenceMeters))
                values[.init(task: frame.taskType, repetition: frame.repetitionIndex, id: "bilateralRegion:\(value.pairID):centroidVectorMismatch"), default: []].append((frame.sourceTimestamp, value.centroidVectorMismatchMeters))
                values[.init(task: frame.taskType, repetition: frame.repetitionIndex, id: "bilateralRegion:\(value.pairID):centroidAsymmetryIndex"), default: []].append((frame.sourceTimestamp, value.centroidAsymmetryIndex))
                values[.init(task: frame.taskType, repetition: frame.repetitionIndex, id: "bilateralRegion:\(value.pairID):absoluteRMSDifference"), default: []].append((frame.sourceTimestamp, value.absoluteRMSDifferenceMeters))
                values[.init(task: frame.taskType, repetition: frame.repetitionIndex, id: "bilateralRegion:\(value.pairID):rmsAsymmetryIndex"), default: []].append((frame.sourceTimestamp, value.rmsAsymmetryIndex))
            }
            for value in frame.planes {
                let areaChange = value.currentTriangleAreaSquareMeters.flatMap { current in value.neutralTriangleAreaSquareMeters.map { current - $0 } }
                values[.init(task: frame.taskType, repetition: frame.repetitionIndex, id: "plane:\(value.planeID):areaChange"), default: []].append((frame.sourceTimestamp, areaChange))
                values[.init(task: frame.taskType, repetition: frame.repetitionIndex, id: "plane:\(value.planeID):orientationChangeDegrees"), default: []].append((frame.sourceTimestamp, value.orientationChangeDegrees))
            }
        }
        return values.keys.sorted { ($0.task.rawValue, $0.repetition, $0.id) < ($1.task.rawValue, $1.repetition, $1.id) }.map { key in
            let samples = values[key]!.sorted { $0.0 < $1.0 }, available = samples.compactMap { timestamp, value in value.map { (timestamp, $0) } }
            let first = samples.first?.0, last = samples.last?.0
            let peak = available.max { abs($0.1) < abs($1.1) }
            return .init(measurementID: key.id, taskType: key.task, repetitionIndex: key.repetition,
                         sampleCount: samples.count, availableSampleCount: available.count,
                         unavailableSampleCount: samples.count - available.count, firstTimestamp: first, lastTimestamp: last,
                         durationSeconds: first.flatMap { start in last.map { $0 - start } }, neutralValue: 0,
                         minimumValue: available.map(\.1).min(), maximumValue: available.map(\.1).max(),
                         peakAbsoluteChangeFromNeutral: peak.map { abs($0.1) }, peakTimestamp: peak?.0,
                         timeToPeakSeconds: peak.flatMap { p in first.map { p.0 - $0 } })
        }
    }

    private func summarizeTasks(_ repetitions: [FaceGeometrySeriesSummary]) -> [FaceGeometryTaskSummary] {
        Dictionary(grouping: repetitions, by: \.taskType).keys.sorted { $0.rawValue < $1.rawValue }.map { task in
            let items = repetitions.filter { $0.taskType == task }
            // Preserve every measurement/repetition series. A task-wide aggregate would mix
            // unlike quantities (for example metres and unitless indices), so it is intentionally absent.
            return .init(taskType: task, repetitions: items, medianPeak: nil,
                         minimumPeak: nil, maximumPeak: nil)
        }
    }
}

private nonisolated enum SHA256Digest {
    static func hex(_ string: String) -> String {
        CryptoKit.SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
