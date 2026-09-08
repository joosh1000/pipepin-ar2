import ARKit
import AVFoundation
import CoreVideo
import Foundation
import RealityKit
import simd
import SwiftUI

struct DepthFrameSample: Sendable {
    let distance: Float
    let confidence: Int
}

struct AnchorFrameUpdate: Sendable {
    let markerID: UUID
    let position: SIMD3<Float>
}

enum TorchSetting: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case on = "On"
    case off = "Off"
    var id: String { rawValue }
}

@MainActor
final class ARSessionController: NSObject, ObservableObject, ARSessionDelegate {
    weak var arView: ARView?

    @Published var statusText = "Move slowly while PipePin maps the space."
    @Published var trackingText = "Starting AR…"
    @Published var mappingText = "Map starting…"
    @Published var precisionText = "SCANNING"
    @Published var precisionReady = false
    @Published var currentPosition: SIMD3<Float> = .zero
    @Published var horizontalDistance: Float?
    @Published var verticalDifference: Float?
    @Published var lidarAvailable = false
    @Published var lidarMeshVisible = false
    @Published var mappedSurfaceCount = 0
    @Published var beamLength: Float = 12.0
    @Published var depthDistance: Float?
    @Published var depthConfidence = 0
    @Published var motionSpeed: Float = 0
    @Published var ambientLight: CGFloat = 1000
    @Published var lowLight = false
    @Published var torchSetting: TorchSetting = .auto
    @Published var torchIsOn = false
    @Published var captureProgress: Double = 0
    @Published var isPrecisionCapturing = false
    @Published var markersReliable = false
    @Published var hasSavedWorldMap = false
    @Published var mapSavedAt: Date?
    @Published var accuracyResultMM: Int?
    @Published var lastPinSourceText = "—"
    @Published var interruptionCount = 0
    @Published var relocalizationCount = 0
    @Published var anchorDriftMM = 0

    var markerStore: MarkerStore?

    private var markerEntities: [UUID: AnchorEntity] = [:]
    private var serviceAnchors: [UUID: ARAnchor] = [:]
    private var runtimeMarkerPositions: [UUID: SIMD3<Float>] = [:]
    private var anchorDriftAlarm = false
    private var guideEntity: AnchorEntity?
    private var guideMarkerID: UUID?
    private var previousFramePosition: SIMD3<Float>?
    private var previousFrameTimestamp: TimeInterval?
    private var normalFrameStreak = 0
    private var loadedSavedMapForSession = false
    private var wasRelocalizing = false

    private struct PendingPin {
        let serviceType: ServiceType
        let orientation: ServiceOrientation
        let flowDirection: FlowDirection
        let area: SiteArea?
        let beamYaw: Float
    }

    private var pendingPin: PendingPin?
    private var pendingAccuracyMarker: SavedMarker?
    private var captureSamples: [(position: SIMD3<Float>, confidence: Int)] = []
    private let requiredSamples = 10

    var lidarStatusText: String { lidarAvailable ? "LiDAR active" : "AR tracking" }

    var diagnosticSummary: String {
        let depth = depthDistance.map { String(format: "%.2f m", $0) } ?? "—"
        return "Tracking: \(trackingText) · Map: \(mappingText) · Depth: \(depth) · Confidence: \(depthConfidence)/2 · Speed: \(String(format: "%.2f", motionSpeed)) m/s · Anchor drift: \(anchorDriftMM) mm"
    }

    func configure(_ view: ARView, markerStore: MarkerStore) {
        arView = view
        self.markerStore = markerStore
        view.session.delegate = self
        lidarAvailable = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        refreshSavedMapState()
        startSession(reset: true, preferSavedMap: true)
    }

    func startSession(reset: Bool = false, preferSavedMap: Bool = true) {
        guard let arView else { return }

        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        config.isLightEstimationEnabled = true

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        }

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
            lidarAvailable = true
        }

        loadedSavedMapForSession = false
        if preferSavedMap, let siteID = markerStore?.activeSiteID, let savedMap = loadWorldMap(siteID: siteID) {
            config.initialWorldMap = savedMap
            loadedSavedMapForSession = true
            markersReliable = false
            trackingText = "Relocalizing"
            statusText = "Saved site map loaded · scan the room until PipePin relocks."
        } else {
            markersReliable = false
            statusText = lidarAvailable
                ? "LiDAR mapping active · scan the room before precision pinning."
                : "AR tracking active · scan the room before pinning."
        }

        let options: ARSession.RunOptions = reset ? [.resetTracking, .removeExistingAnchors] : []
        arView.session.run(config, options: options)

        previousFramePosition = nil
        previousFrameTimestamp = nil
        normalFrameStreak = 0
        anchorDriftAlarm = false
        anchorDriftMM = 0
        runtimeMarkerPositions.removeAll()
        captureSamples.removeAll()
        pendingPin = nil
        pendingAccuracyMarker = nil
        isPrecisionCapturing = false
        captureProgress = 0
        accuracyResultMM = nil

        rebuildMarkerEntities()
    }

    func placeMarkerAtCenter(
        serviceType: ServiceType,
        orientation: ServiceOrientation,
        flowDirection: FlowDirection,
        area: SiteArea?
    ) {
        guard markerStore?.activeSiteID != nil else {
            statusText = "Select a site before placing services."
            return
        }
        guard !isPrecisionCapturing else { return }

        guard precisionReady else {
            statusText = precisionBlockReason()
            return
        }

        let yaw = currentHorizontalBeamYaw()

        if lidarAvailable, depthDistance != nil, depthConfidence >= 1 {
            pendingPin = PendingPin(
                serviceType: serviceType,
                orientation: orientation,
                flowDirection: flowDirection,
                area: area,
                beamYaw: yaw
            )
            pendingAccuracyMarker = nil
            captureSamples.removeAll()
            captureProgress = 0
            isPrecisionCapturing = true
            statusText = "Precision capture · hold the reticle still for a moment."
        } else {
            placeRaycastFallback(
                serviceType: serviceType,
                orientation: orientation,
                flowDirection: flowDirection,
                area: area,
                beamYaw: yaw
            )
        }
    }

    private func placeRaycastFallback(
        serviceType: ServiceType,
        orientation: ServiceOrientation,
        flowDirection: FlowDirection,
        area: SiteArea?,
        beamYaw: Float
    ) {
        guard let arView else { return }
        let screenPoint = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        let results = arView.raycast(from: screenPoint, allowing: .estimatedPlane, alignment: .any)
        guard let hit = results.first else {
            statusText = "No surface found · scan more detail and try again."
            return
        }
        let m = hit.worldTransform
        let p = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
        commitMarker(
            position: p,
            confidence: 0,
            source: .raycast,
            serviceType: serviceType,
            orientation: orientation,
            flowDirection: flowDirection,
            area: area,
            beamYaw: beamYaw
        )
    }

    private func commitMarker(
        position: SIMD3<Float>,
        confidence: Int,
        source: PinSource,
        serviceType: ServiceType,
        orientation: ServiceOrientation,
        flowDirection: FlowDirection,
        area: SiteArea?,
        beamYaw: Float
    ) {
        guard let markerStore, let activeSiteID = markerStore.activeSiteID else { return }

        let number = markerStore.visibleMarkers.filter { $0.serviceType == serviceType }.count + 1
        let marker = SavedMarker(
            siteID: activeSiteID,
            areaID: area?.id,
            floorName: area?.floorName ?? "",
            roomName: area?.roomName ?? "",
            name: "\(serviceType.title) \(number)",
            serviceType: serviceType,
            orientation: orientation,
            flowDirection: flowDirection,
            beamYaw: beamYaw,
            position: position,
            pinSource: source,
            captureConfidence: confidence
        )

        markerStore.add(marker)
        addMarkerEntity(marker)
        selectMarker(nil)
        lastPinSourceText = source.title
        statusText = "\(marker.name) precision-locked · \(source.title)."
        saveReferenceSnapshot(markerID: marker.id)
        saveSiteWorldMap(silent: true)
    }

    func beginAccuracyCheck(marker: SavedMarker) {
        guard !isPrecisionCapturing else { return }
        guard precisionReady else {
            statusText = precisionBlockReason()
            return
        }
        guard lidarAvailable, depthDistance != nil, depthConfidence >= 1 else {
            statusText = "Accuracy check needs a confident LiDAR depth reading at the reticle."
            return
        }

        pendingPin = nil
        pendingAccuracyMarker = marker
        captureSamples.removeAll()
        captureProgress = 0
        isPrecisionCapturing = true
        accuracyResultMM = nil
        statusText = "Accuracy check · aim at the original physical point and hold still."
    }

    func cancelPrecisionCapture() {
        pendingPin = nil
        pendingAccuracyMarker = nil
        captureSamples.removeAll()
        captureProgress = 0
        isPrecisionCapturing = false
        statusText = "Precision capture cancelled."
    }

    private func finishPrecisionCapture() {
        guard captureSamples.count >= requiredSamples else { return }

        let positions = captureSamples.map(\.position)
        let finalPosition = robustCentre(of: positions)
        let confidence = captureSamples.map(\.confidence).sorted()[captureSamples.count / 2]

        if let pin = pendingPin {
            commitMarker(
                position: finalPosition,
                confidence: confidence,
                source: .lidarDepth,
                serviceType: pin.serviceType,
                orientation: pin.orientation,
                flowDirection: pin.flowDirection,
                area: pin.area,
                beamYaw: pin.beamYaw
            )
        } else if let marker = pendingAccuracyMarker {
            let error = simd_distance(marker.position, finalPosition)
            accuracyResultMM = Int((error * 1000).rounded())
            statusText = "Return accuracy: \(accuracyResultMM ?? 0) mm from the saved pin."
        }

        pendingPin = nil
        pendingAccuracyMarker = nil
        captureSamples.removeAll()
        captureProgress = 1
        isPrecisionCapturing = false
    }

    private func robustCentre(of positions: [SIMD3<Float>]) -> SIMD3<Float> {
        guard !positions.isEmpty else { return .zero }
        let xs = positions.map(\.x).sorted()
        let ys = positions.map(\.y).sorted()
        let zs = positions.map(\.z).sorted()
        let mid = positions.count / 2
        return SIMD3<Float>(xs[mid], ys[mid], zs[mid])
    }

    private func precisionBlockReason() -> String {
        if trackingText != "Tracking good" { return "Precision blocked · \(trackingText.lowercased())." }
        if motionSpeed > 0.25 { return "Precision blocked · hold the phone steadier." }
        if lowLight && !torchIsOn { return "Low light · switch the torch on or use Auto." }
        if lidarAvailable && depthConfidence < 1 { return "LiDAR confidence is low · move closer or aim at a clearer surface." }
        if mappingText == "Map unavailable" { return "Scan more of the room before precision pinning." }
        return "Keep scanning the surroundings until Precision Ready appears."
    }

    private func currentHorizontalBeamYaw() -> Float {
        guard let cameraTransform = arView?.session.currentFrame?.camera.transform else { return 0 }
        let forward = SIMD3<Float>(-cameraTransform.columns.2.x, 0, -cameraTransform.columns.2.z)
        let length = simd_length(forward)
        guard length > 0.001 else { return 0 }
        let direction = forward / length
        return atan2(-direction.z, direction.x)
    }

    func undoLastMarker() {
        guard let markerStore, let last = markerStore.visibleMarkers.last else { return }
        removeMarkerEntity(last.id)
        markerStore.deleteLastVisible()
        updateGuide()
        statusText = "Last pin removed."
    }

    private func removeMarkerEntity(_ id: UUID) {
        if let anchor = markerEntities[id] {
            arView?.scene.removeAnchor(anchor)
            markerEntities[id] = nil
        }
        if let sessionAnchor = serviceAnchors[id] {
            arView?.session.remove(anchor: sessionAnchor)
            serviceAnchors[id] = nil
        }
        runtimeMarkerPositions[id] = nil
    }

    func rebuildMarkerEntities() {
        guard let arView, let markerStore else { return }
        markerEntities.values.forEach { arView.scene.removeAnchor($0) }
        markerEntities.removeAll()
        serviceAnchors.values.forEach { arView.session.remove(anchor: $0) }
        serviceAnchors.removeAll()
        runtimeMarkerPositions.removeAll()
        markerStore.visibleMarkers.forEach(addMarkerEntity)
        setMarkerVisibility(markersReliable)
        updateGuide()
    }

    func selectMarker(_ marker: SavedMarker?) {
        markerStore?.selectedMarkerID = marker?.id
        updateGuide()
    }

    func stopLocating() {
        selectMarker(nil)
        statusText = "Locate target cleared · ready to map or pin services."
    }

    func setBeamLength(_ length: Float) {
        beamLength = min(max(length, 4.0), 20.0)
        rebuildMarkerEntities()
        statusText = "Locator beams set to \(Int(beamLength)) m."
    }

    func toggleLiDARMesh() {
        guard let arView else { return }
        guard lidarAvailable else {
            statusText = "LiDAR scene reconstruction is not available on this iPhone."
            return
        }
        lidarMeshVisible.toggle()
        if lidarMeshVisible { arView.debugOptions.insert(.showSceneUnderstanding) }
        else { arView.debugOptions.remove(.showSceneUnderstanding) }
    }

    func setTorch(_ setting: TorchSetting) {
        torchSetting = setting
        switch setting {
        case .on: applyTorch(on: true)
        case .off: applyTorch(on: false)
        case .auto: updateAutoTorch()
        }
    }

    private func updateAutoTorch() {
        guard torchSetting == .auto else { return }
        if lowLight && !torchIsOn { applyTorch(on: true) }
        if !lowLight && ambientLight > 350 && torchIsOn { applyTorch(on: false) }
    }

    private func applyTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if on {
                try device.setTorchModeOn(level: min(0.55, AVCaptureDevice.maxAvailableTorchLevel))
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
            torchIsOn = on
        } catch {
            statusText = "Torch could not be changed while AR is active."
        }
    }

    func saveSiteWorldMap(silent: Bool = false) {
        guard let arView, let siteID = markerStore?.activeSiteID else { return }
        if anchorDriftAlarm {
            if !silent { statusText = "Map save blocked · resolve the anchor-shift warning first." }
            return
        }
        for (id, position) in runtimeMarkerPositions {
            markerStore?.updatePosition(markerID: id, position: position)
        }
        let url = worldMapURL(siteID: siteID)
        arView.session.getCurrentWorldMap { [weak self] worldMap, error in
            guard let self else { return }
            guard let worldMap, error == nil else {
                Task { @MainActor in
                    if !silent { self.statusText = "Site map not ready yet · keep scanning and try again." }
                }
                return
            }

            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                try data.write(to: url, options: .atomic)
                Task { @MainActor in
                    self.hasSavedWorldMap = true
                    self.mapSavedAt = Date()
                    if !silent { self.statusText = "Site spatial map saved for relocalisation." }
                }
            } catch {
                Task { @MainActor in
                    if !silent { self.statusText = "Could not save the site spatial map." }
                }
            }
        }
    }

    func relockToSavedMap() {
        refreshSavedMapState()
        guard hasSavedWorldMap else {
            statusText = "No saved site map yet · scan the area and save a Site Map first."
            return
        }
        relocalizationCount += 1
        anchorDriftAlarm = false
        anchorDriftMM = 0
        startSession(reset: true, preferSavedMap: true)
    }

    func clearSavedWorldMap() {
        guard let siteID = markerStore?.activeSiteID else { return }
        try? FileManager.default.removeItem(at: worldMapURL(siteID: siteID))
        hasSavedWorldMap = false
        mapSavedAt = nil
        statusText = "Saved site map removed."
    }

    func refreshSavedMapState() {
        guard let siteID = markerStore?.activeSiteID else {
            hasSavedWorldMap = false
            return
        }
        hasSavedWorldMap = FileManager.default.fileExists(atPath: worldMapURL(siteID: siteID).path)
    }

    private func worldMapURL(siteID: UUID) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("PipePinMaps", isDirectory: true)
            .appendingPathComponent("\(siteID.uuidString).worldmap")
    }

    private func loadWorldMap(siteID: UUID) -> ARWorldMap? {
        let url = worldMapURL(siteID: siteID)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
    }

    private func referenceSnapshotURL(markerID: UUID) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("PipePinSnapshots", isDirectory: true)
            .appendingPathComponent("\(markerID.uuidString).jpg")
    }

    private func saveReferenceSnapshot(markerID: UUID) {
        guard let arView else { return }
        let url = referenceSnapshotURL(markerID: markerID)
        arView.snapshot(saveToHDR: false) { image in
            guard let image, let data = image.jpegData(compressionQuality: 0.72) else { return }
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try? data.write(to: url, options: .atomic)
        }
    }

    private func solidMaterial(for type: ServiceType) -> SimpleMaterial {
        SimpleMaterial(color: type.uiColor, roughness: 0.12, isMetallic: false)
    }

    private func glowMaterial(for type: ServiceType) -> SimpleMaterial {
        SimpleMaterial(color: type.uiColor.withAlphaComponent(0.30), roughness: 0.08, isMetallic: false)
    }

    private func arrowMaterial() -> SimpleMaterial {
        SimpleMaterial(color: UIColor.white.withAlphaComponent(0.98), roughness: 0.08, isMetallic: false)
    }

    private func addMarkerEntity(_ marker: SavedMarker) {
        guard let arView else { return }

        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4<Float>(marker.position.x, marker.position.y, marker.position.z, 1)
        let sessionAnchor = ARAnchor(name: "PipePinService-\(marker.id.uuidString)", transform: transform)
        arView.session.add(anchor: sessionAnchor)
        serviceAnchors[marker.id] = sessionAnchor
        runtimeMarkerPositions[marker.id] = marker.position

        let anchor = AnchorEntity(world: marker.position)
        let solid = solidMaterial(for: marker.serviceType)
        let glow = glowMaterial(for: marker.serviceType)

        let pointGlow = ModelEntity(mesh: .generateSphere(radius: 0.115), materials: [glow])
        anchor.addChild(pointGlow)
        let point = ModelEntity(mesh: .generateSphere(radius: 0.072), materials: [solid])
        point.name = marker.name
        anchor.addChild(point)
        let centre = ModelEntity(
            mesh: .generateSphere(radius: 0.019),
            materials: [SimpleMaterial(color: .white, roughness: 0.08, isMetallic: false)]
        )
        anchor.addChild(centre)

        let beamRoot = Entity()
        if marker.orientation == .horizontal {
            beamRoot.orientation = simd_quatf(angle: marker.beamYaw, axis: SIMD3<Float>(0, 1, 0))
        }
        anchor.addChild(beamRoot)

        let beam: ModelEntity
        let halo: ModelEntity
        if marker.orientation == .vertical {
            beam = ModelEntity(mesh: .generateBox(width: 0.060, height: beamLength, depth: 0.060), materials: [solid])
            halo = ModelEntity(mesh: .generateBox(width: 0.145, height: beamLength, depth: 0.145), materials: [glow])
        } else {
            beam = ModelEntity(mesh: .generateBox(width: beamLength, height: 0.060, depth: 0.060), materials: [solid])
            halo = ModelEntity(mesh: .generateBox(width: beamLength, height: 0.145, depth: 0.145), materials: [glow])
        }
        beamRoot.addChild(halo)
        beamRoot.addChild(beam)
        addDirectionArrows(to: beamRoot, marker: marker)

        let crossX = ModelEntity(mesh: .generateBox(width: 0.38, height: 0.014, depth: 0.028), materials: [solid])
        anchor.addChild(crossX)
        let crossZ = ModelEntity(mesh: .generateBox(width: 0.028, height: 0.014, depth: 0.38), materials: [solid])
        anchor.addChild(crossZ)

        arView.scene.addAnchor(anchor)
        markerEntities[marker.id] = anchor
        anchor.isEnabled = markersReliable
    }

    private func addDirectionArrows(to beamRoot: Entity, marker: SavedMarker) {
        guard marker.flowDirection != .none else { return }
        let arrowCount = max(3, min(7, Int(beamLength / 2.0)))
        let usableLength = beamLength * 0.72
        let spacing = usableLength / Float(max(1, arrowCount - 1))
        let start = -usableLength / 2
        for index in 0..<arrowCount {
            let offset = start + Float(index) * spacing
            let arrow = makeChevron(orientation: marker.orientation, flowDirection: marker.flowDirection)
            arrow.position = marker.orientation == .vertical
                ? SIMD3<Float>(0, offset, 0.090)
                : SIMD3<Float>(offset, 0, 0.090)
            beamRoot.addChild(arrow)
        }
    }

    private func makeChevron(orientation: ServiceOrientation, flowDirection: FlowDirection) -> Entity {
        let root = Entity()
        let material = arrowMaterial()
        let upper = ModelEntity(mesh: .generateBox(width: 0.20, height: 0.020, depth: 0.026), materials: [material])
        let lower = ModelEntity(mesh: .generateBox(width: 0.20, height: 0.020, depth: 0.026), materials: [material])
        upper.position = SIMD3<Float>(-0.045, 0.050, 0)
        lower.position = SIMD3<Float>(-0.045, -0.050, 0)
        upper.orientation = simd_quatf(angle: -.pi / 4, axis: SIMD3<Float>(0, 0, 1))
        lower.orientation = simd_quatf(angle: .pi / 4, axis: SIMD3<Float>(0, 0, 1))
        root.addChild(upper)
        root.addChild(lower)
        var angle: Float = orientation == .vertical ? .pi / 2 : 0
        if flowDirection == .reverse { angle += .pi }
        root.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 0, 1))
        return root
    }

    private func setMarkerVisibility(_ visible: Bool) {
        markerEntities.values.forEach { $0.isEnabled = visible }
        if !visible, let guideEntity { guideEntity.isEnabled = false }
        else { guideEntity?.isEnabled = true }
    }

    private func updateGuide() {
        guard let arView, let marker = markerStore?.selectedMarker else {
            horizontalDistance = nil
            verticalDifference = nil
            if let guideEntity { arView?.scene.removeAnchor(guideEntity) }
            guideEntity = nil
            guideMarkerID = nil
            return
        }

        let targetPosition = runtimeMarkerPositions[marker.id] ?? marker.position
        let delta = targetPosition - currentPosition
        horizontalDistance = sqrt(delta.x * delta.x + delta.z * delta.z)
        verticalDifference = delta.y
        let guidePosition = SIMD3<Float>(targetPosition.x, currentPosition.y, targetPosition.z)

        if let guideEntity, guideMarkerID == marker.id {
            guideEntity.position = guidePosition
            guideEntity.isEnabled = markersReliable
            return
        }
        if let guideEntity { arView.scene.removeAnchor(guideEntity) }

        let anchor = AnchorEntity(world: guidePosition)
        let material = solidMaterial(for: marker.serviceType)
        let glow = glowMaterial(for: marker.serviceType)
        anchor.addChild(ModelEntity(mesh: .generateSphere(radius: 0.15), materials: [glow]))
        anchor.addChild(ModelEntity(mesh: .generateBox(width: 0.78, height: 0.024, depth: 0.056), materials: [material]))
        anchor.addChild(ModelEntity(mesh: .generateBox(width: 0.056, height: 0.024, depth: 0.78), materials: [material]))
        anchor.addChild(ModelEntity(mesh: .generateSphere(radius: 0.085), materials: [material]))
        anchor.isEnabled = markersReliable
        arView.scene.addAnchor(anchor)
        guideEntity = anchor
        guideMarkerID = marker.id
    }

    nonisolated private static func centreDepthSample(from frame: ARFrame) -> DepthFrameSample? {
        guard let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth else { return nil }
        let depthMap = depthData.depthMap
        let confidenceMap = depthData.confidenceMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard width > 8, height > 8 else { return nil }

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        if let confidenceMap { CVPixelBufferLockBaseAddress(confidenceMap, .readOnly) }
        defer {
            if let confidenceMap { CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly) }
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
        }

        guard let depthBase = CVPixelBufferGetBaseAddress(depthMap) else { return nil }

        let depthRow = CVPixelBufferGetBytesPerRow(depthMap) / MemoryLayout<Float32>.size
        let depthPtr = depthBase.assumingMemoryBound(to: Float32.self)
        let confidenceBase = confidenceMap.flatMap { CVPixelBufferGetBaseAddress($0) }
        let confidenceRow = confidenceMap.map { CVPixelBufferGetBytesPerRow($0) } ?? 0
        let confidencePtr = confidenceBase?.assumingMemoryBound(to: UInt8.self)
        let cx = width / 2
        let cy = height / 2

        var high: [Float] = []
        var medium: [Float] = []
        for dy in -3...3 {
            for dx in -3...3 {
                let x = min(max(cx + dx, 0), width - 1)
                let y = min(max(cy + dy, 0), height - 1)
                let d = depthPtr[y * depthRow + x]
                let c = confidencePtr.map { Int($0[y * confidenceRow + x]) } ?? 1
                guard d.isFinite, d > 0.10, d < 6.0 else { continue }
                if c >= 2 { high.append(d) }
                else if c >= 1 { medium.append(d) }
            }
        }

        var values = high.isEmpty ? medium : high
        guard !values.isEmpty else { return nil }
        values.sort()
        return DepthFrameSample(distance: values[values.count / 2], confidence: high.isEmpty ? 1 : 2)
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let transform = frame.camera.transform
        let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let forwardRaw = SIMD3<Float>(-transform.columns.2.x, -transform.columns.2.y, -transform.columns.2.z)
        let forwardLength = simd_length(forwardRaw)
        let forward = forwardLength > 0.001 ? forwardRaw / forwardLength : SIMD3<Float>(0, 0, -1)
        let trackingState = frame.camera.trackingState
        let mappingStatus = frame.worldMappingStatus
        let timestamp = frame.timestamp
        let surfaceCount = frame.anchors.filter { $0 is ARMeshAnchor || $0 is ARPlaneAnchor }.count
        let light = frame.lightEstimate?.ambientIntensity ?? 1000
        let depthSample = Self.centreDepthSample(from: frame)
        let depthWorldPosition = depthSample.map { position + forward * $0.distance }
        let anchorUpdates: [AnchorFrameUpdate] = frame.anchors.compactMap { anchor in
            guard let name = anchor.name, name.hasPrefix("PipePinService-") else { return nil }
            let uuidText = String(name.dropFirst("PipePinService-".count))
            guard let id = UUID(uuidString: uuidText) else { return nil }
            let t = anchor.transform
            return AnchorFrameUpdate(
                markerID: id,
                position: SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
            )
        }

        Task { @MainActor in
            let previousPosition = self.previousFramePosition
            let previousTimestamp = self.previousFrameTimestamp
            if let previousPosition, let previousTimestamp {
                let dt = max(0.001, Float(timestamp - previousTimestamp))
                self.motionSpeed = simd_distance(position, previousPosition) / dt
            } else {
                self.motionSpeed = 0
            }
            self.previousFramePosition = position
            self.previousFrameTimestamp = timestamp
            self.currentPosition = position
            self.mappedSurfaceCount = surfaceCount
            self.ambientLight = light
            self.lowLight = light < 220
            self.depthDistance = depthSample?.distance
            self.depthConfidence = depthSample?.confidence ?? 0

            var maxDrift: Float = 0
            var suddenShift = false
            for update in anchorUpdates {
                guard let saved = self.markerStore?.visibleMarkers.first(where: { $0.id == update.markerID }) else { continue }
                let prior = self.runtimeMarkerPositions[update.markerID] ?? saved.position
                let step = simd_distance(prior, update.position)
                let total = simd_distance(saved.position, update.position)
                maxDrift = max(maxDrift, total)
                if step > 0.08 || total > 0.18 {
                    suddenShift = true
                    continue
                }
                self.runtimeMarkerPositions[update.markerID] = update.position
                self.markerEntities[update.markerID]?.position = update.position
            }
            self.anchorDriftMM = Int((maxDrift * 1000).rounded())
            if suddenShift {
                self.anchorDriftAlarm = true
                self.markersReliable = false
                self.setMarkerVisibility(false)
                self.statusText = "ANCHOR SHIFT DETECTED · beams hidden. Re-lock to the saved Site Map."
            }

            switch mappingStatus {
            case .notAvailable: self.mappingText = "Map unavailable"
            case .limited: self.mappingText = "Map limited"
            case .extending: self.mappingText = "Map extending"
            case .mapped: self.mappingText = "Map mapped"
            @unknown default: self.mappingText = "Map unknown"
            }

            var trackingNormal = false
            switch trackingState {
            case .normal:
                self.trackingText = "Tracking good"
                trackingNormal = true
                self.normalFrameStreak += 1
                if self.wasRelocalizing {
                    self.wasRelocalizing = false
                    self.statusText = "Site position relocked. Precision services are visible again."
                }
            case .notAvailable:
                self.trackingText = "Tracking unavailable"
                self.normalFrameStreak = 0
            case .limited(let reason):
                self.normalFrameStreak = 0
                switch reason {
                case .initializing:
                    self.trackingText = "Initializing"
                case .excessiveMotion:
                    self.trackingText = "Move slower"
                case .insufficientFeatures:
                    self.trackingText = "Scan more detail"
                case .relocalizing:
                    self.trackingText = "Relocalizing"
                    self.wasRelocalizing = true
                @unknown default:
                    self.trackingText = "Tracking limited"
                }
            }

            let mappingUseful = mappingStatus == .extending || mappingStatus == .mapped || (mappingStatus == .limited && surfaceCount >= 3)
            let depthUseful = !self.lidarAvailable || (self.depthConfidence >= 1 && (self.depthDistance ?? 99) < 5.0)
            let lightUseful = !self.lowLight || self.torchIsOn
            let motionUseful = self.motionSpeed < 0.25
            self.precisionReady = trackingNormal && mappingUseful && depthUseful && lightUseful && motionUseful
            self.precisionText = self.precisionReady ? "PRECISION READY" : "SCANNING"

            let reliableNow = trackingNormal && self.normalFrameStreak >= 5 && (!self.loadedSavedMapForSession || !self.wasRelocalizing) && !self.anchorDriftAlarm
            if reliableNow != self.markersReliable {
                self.markersReliable = reliableNow
                self.setMarkerVisibility(reliableNow)
                if !reliableNow {
                    self.statusText = "POSITION UNCERTAIN · beams hidden until tracking relocks."
                }
            }

            self.updateAutoTorch()

            if self.isPrecisionCapturing,
               trackingNormal,
               self.motionSpeed < 0.18,
               let depthSample,
               depthSample.confidence >= 1,
               let depthWorldPosition {
                self.captureSamples.append((depthWorldPosition, depthSample.confidence))
                self.captureProgress = min(1, Double(self.captureSamples.count) / Double(self.requiredSamples))
                if self.captureSamples.count >= self.requiredSamples {
                    self.finishPrecisionCapture()
                }
            }

            self.updateGuide()
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            self.interruptionCount += 1
            self.markersReliable = false
            self.setMarkerVisibility(false)
            self.statusText = "AR interrupted · precision beams hidden."
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in
            self.relocalizationCount += 1
            self.statusText = "AR resumed · scan surroundings to relock position."
            self.markersReliable = false
            self.normalFrameStreak = 0
        }
    }
}
