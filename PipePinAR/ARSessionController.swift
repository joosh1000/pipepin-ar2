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
    @Published var isRelocalizing = false

    var markerStore: MarkerStore?
    private var markerEntities: [UUID: AnchorEntity] = [:]
    private var guideEntity: AnchorEntity?

    func configure(_ view: ARView, markerStore: MarkerStore) {
        self.arView = view
        self.markerStore = markerStore
        view.session.delegate = self
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
        }

        let options: ARSession.RunOptions = reset ? [.resetTracking, .removeExistingAnchors] : []
        arView.session.run(config, options: options)
        statusText = "Tap a visible surface to pin the pipe/cable point."
        rebuildMarkerEntities()
    }

    func placeMarker(screenPoint: CGPoint, name: String? = nil) {
        guard let arView, let markerStore else { return }

        let results = arView.raycast(from: screenPoint, allowing: .estimatedPlane, alignment: .any)
        guard let hit = results.first else {
            statusText = "No surface found. Point at a wall, floor or object and try again."
            return
        }

        let matrix = hit.worldTransform
        let position = SIMD3<Float>(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
        let markerName = name ?? "Marker \(markerStore.markers.count + 1)"
        let saved = SavedMarker(name: markerName, position: position)
        markerStore.add(saved)
        addMarkerEntity(saved)
        statusText = "Pinned \(markerName). Keep AR running and walk to the other floor."
    }

    func rebuildMarkerEntities() {
        guard let arView, let markerStore else { return }
        markerEntities.values.forEach { arView.scene.removeAnchor($0) }
        markerEntities.removeAll()
        markerStore.markers.forEach(addMarkerEntity)
    }

    func selectMarker(_ marker: SavedMarker?) {
        markerStore?.selectedMarkerID = marker?.id
        updateGuide()
    }

    private func addMarkerEntity(_ marker: SavedMarker) {
        guard let arView else { return }
        let anchor = AnchorEntity(world: marker.position)

        let sphere = ModelEntity(mesh: .generateSphere(radius: 0.035), materials: [SimpleMaterial()])
        sphere.name = marker.name
        anchor.addChild(sphere)

        let stem = ModelEntity(mesh: .generateBox(width: 0.012, height: 0.22, depth: 0.012), materials: [SimpleMaterial()])
        stem.position.y = 0.11
        anchor.addChild(stem)

        arView.scene.addAnchor(anchor)
        markerEntities[marker.id] = anchor
    }

    private func updateGuide() {
        guard let arView, let marker = markerStore?.selectedMarker else {
            horizontalDistance = nil
            verticalDifference = nil
            if let guideEntity { arView?.scene.removeAnchor(guideEntity) }
            guideEntity = nil
            return
        }

        let delta = marker.position - currentPosition
        horizontalDistance = sqrt(delta.x * delta.x + delta.z * delta.z)
        verticalDifference = delta.y

        // A floating target directly above/below the saved point helps with floor-to-floor alignment.
        let guidePosition = SIMD3<Float>(marker.position.x, currentPosition.y, marker.position.z)
        if let guideEntity {
            guideEntity.position = guidePosition
        } else {
            let anchor = AnchorEntity(world: guidePosition)
            let ring = ModelEntity(mesh: .generateSphere(radius: 0.07), materials: [SimpleMaterial()])
            ring.scale = SIMD3<Float>(1.0, 0.12, 1.0)
            anchor.addChild(ring)
            arView.scene.addAnchor(anchor)
            guideEntity = anchor
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let transform = frame.camera.transform
        let pos = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let tracking = frame.camera.trackingState

        Task { @MainActor in
            self.currentPosition = pos
            switch tracking {
            case .normal:
                self.trackingText = "Tracking: good"
                self.isRelocalizing = false
            case .notAvailable:
                self.trackingText = "Tracking unavailable"
            case .limited(let reason):
                switch reason {
                case .initializing:
                    self.trackingText = "Tracking: initializing"
                case .excessiveMotion:
                    self.trackingText = "Tracking limited: move more slowly"
                case .insufficientFeatures:
                    self.trackingText = "Tracking limited: point at textured surfaces"
                case .relocalizing:
                    self.trackingText = "Relocalizing…"
                    self.isRelocalizing = true
                @unknown default:
                    self.trackingText = "Tracking limited"
                }
            }
            self.updateGuide()
        }
    }
}
