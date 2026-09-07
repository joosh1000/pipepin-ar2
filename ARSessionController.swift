import ARKit
import RealityKit
import SwiftUI

@MainActor
final class ARSessionController: NSObject, ObservableObject, ARSessionDelegate {
    weak var arView: ARView?

    @Published var statusText = "Move the phone slowly to map the room."
    @Published var trackingText = "Starting AR…"
    @Published var currentPosition: SIMD3<Float> = .zero
    @Published var horizontalDistance: Float?
    @Published var verticalDifference: Float?
    @Published var lidarAvailable = false
    @Published var lidarMeshVisible = false
    @Published var mappedSurfaceCount = 0

    var markerStore: MarkerStore?
    private var markerEntities: [UUID: AnchorEntity] = [:]
    private var guideEntity: AnchorEntity?

    var lidarStatusText: String {
        lidarAvailable ? "LiDAR active" : "AR tracking"
    }

    func configure(_ view: ARView, markerStore: MarkerStore) {
        arView = view
        self.markerStore = markerStore
        view.session.delegate = self
        lidarAvailable = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        startSession(reset: true)
    }

    func startSession(reset: Bool = false) {
        guard let arView else { return }

        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
            lidarAvailable = true
        }

        let options: ARSession.RunOptions = reset ? [.resetTracking, .removeExistingAnchors] : []
        arView.session.run(config, options: options)

        if lidarAvailable {
            statusText = "LiDAR mapping active. Aim the crosshair and mark a service."
        } else {
            statusText = "Aim the crosshair at a visible surface and mark a service."
        }

        rebuildMarkerEntities()
    }

    func placeMarkerAtCenter(serviceType: ServiceType) {
        guard let arView else { return }
        let screenPoint = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        placeMarker(screenPoint: screenPoint, serviceType: serviceType)
    }

    private func placeMarker(screenPoint: CGPoint, serviceType: ServiceType) {
        guard let arView, let markerStore else { return }

        let results = arView.raycast(from: screenPoint, allowing: .estimatedPlane, alignment: .any)
        guard let hit = results.first else {
            statusText = "No surface found. Scan the area slowly and try again."
            return
        }

        let matrix = hit.worldTransform
        let position = SIMD3<Float>(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
        let number = markerStore.markers.filter { $0.serviceType == serviceType }.count + 1
        let marker = SavedMarker(
            name: "\(serviceType.title) \(number)",
            serviceType: serviceType,
            position: position
        )

        markerStore.add(marker)
        addMarkerEntity(marker)
        selectMarker(marker)
        statusText = "Pinned \(marker.name). Keep PipePin open while moving through the building."
    }

    func undoLastMarker() {
        guard let markerStore, let last = markerStore.markers.last else { return }
        if let anchor = markerEntities[last.id] {
            arView?.scene.removeAnchor(anchor)
            markerEntities[last.id] = nil
        }
        markerStore.deleteLast()
        updateGuide()
        statusText = "Last pin removed."
    }

    func rebuildMarkerEntities() {
        guard let arView, let markerStore else { return }
        markerEntities.values.forEach { arView.scene.removeAnchor($0) }
        markerEntities.removeAll()
        markerStore.markers.forEach(addMarkerEntity)
        updateGuide()
    }

    func selectMarker(_ marker: SavedMarker?) {
        markerStore?.selectedMarkerID = marker?.id
        updateGuide()
    }

    func toggleLiDARMesh() {
        guard let arView else { return }
        guard lidarAvailable else {
            statusText = "LiDAR scene reconstruction is not available on this iPhone."
            return
        }

        lidarMeshVisible.toggle()
        if lidarMeshVisible {
            arView.debugOptions.insert(.showSceneUnderstanding)
        } else {
            arView.debugOptions.remove(.showSceneUnderstanding)
        }
    }

    private func addMarkerEntity(_ marker: SavedMarker) {
        guard let arView else { return }

        let anchor = AnchorEntity(world: marker.position)
        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.035),
            materials: [SimpleMaterial()]
        )
        sphere.name = marker.name
        anchor.addChild(sphere)

        let stem = ModelEntity(
            mesh: .generateBox(width: 0.012, height: 0.20, depth: 0.012),
            materials: [SimpleMaterial()]
        )
        stem.position.y = 0.10
        anchor.addChild(stem)

        arView.scene.addAnchor(anchor)
        markerEntities[marker.id] = anchor
    }

    private func updateGuide() {
        guard let arView, let marker = markerStore?.selectedMarker else {
            horizontalDistance = nil
            verticalDifference = nil
            if let guideEntity {
                arView?.scene.removeAnchor(guideEntity)
            }
            guideEntity = nil
            return
        }

        let delta = marker.position - currentPosition
        horizontalDistance = sqrt(delta.x * delta.x + delta.z * delta.z)
        verticalDifference = delta.y

        let guidePosition = SIMD3<Float>(marker.position.x, currentPosition.y, marker.position.z)
        if let guideEntity {
            guideEntity.position = guidePosition
        } else {
            let anchor = AnchorEntity(world: guidePosition)
            let target = ModelEntity(
                mesh: .generateSphere(radius: 0.07),
                materials: [SimpleMaterial()]
            )
            target.scale = SIMD3<Float>(1.0, 0.12, 1.0)
            anchor.addChild(target)
            arView.scene.addAnchor(anchor)
            guideEntity = anchor
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let transform = frame.camera.transform
        let position = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        let trackingState = frame.camera.trackingState
        let surfaceCount = frame.anchors.filter { anchor in
            anchor is ARMeshAnchor || anchor is ARPlaneAnchor
        }.count

        Task { @MainActor in
            self.currentPosition = position
            self.mappedSurfaceCount = surfaceCount

            switch trackingState {
            case .normal:
                self.trackingText = "Tracking good"
            case .notAvailable:
                self.trackingText = "Tracking unavailable"
            case .limited(let reason):
                switch reason {
                case .initializing:
                    self.trackingText = "Initializing"
                case .excessiveMotion:
                    self.trackingText = "Move slower"
                case .insufficientFeatures:
                    self.trackingText = "Scan more detail"
                case .relocalizing:
                    self.trackingText = "Relocalizing"
                @unknown default:
                    self.trackingText = "Tracking limited"
                }
            }

            self.updateGuide()
        }
    }
}
