import ARKit
import RealityKit
import SwiftUI
import UIKit

@MainActor
final class ARSessionController: NSObject, ObservableObject, ARSessionDelegate {
    weak var arView: ARView?

    @Published var statusText = "Move the phone slowly to map the room."
    @Published var trackingText = "Starting AR…"
    @Published var currentPosition: SIMD3<Float> = .zero
    @Published var horizontalDistance: Float?
    @Published var verticalDifference: Float?
    @Published var isRelocalizing = false
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
        self.arView = view
        self.markerStore = markerStore
        view.session.delegate = self

        lidarAvailable = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        configureSceneUnderstanding()
        startSession(reset: true)
    }

    private func configureSceneUnderstanding() {
        guard let arView else { return }
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        arView.environment.sceneUnderstanding.options.insert(.collision)
        arView.environment.sceneUnderstanding.options.insert(.receivesLighting)
        updateMeshDebugOverlay()
    }

    func startSession(reset: Bool = false) {
        guard let arView else { return }

        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
            lidarAvailable = true
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
            lidarAvailable = true
        }

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }

        let options: ARSession.RunOptions = reset ? [.resetTracking, .removeExistingAnchors] : []
        arView.session.run(config, options: options)

        statusText = lidarAvailable
            ? "LiDAR is mapping the room. Aim the crosshair at a service and place a pin."
            : "Aim the crosshair at a visible surface and place a pin."

        rebuildMarkerEntities()
    }

    func placeMarkerAtCenter(serviceType: ServiceType) {
        guard let arView else { return }
        let point = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        placeMarker(screenPoint: point, serviceType: serviceType)
    }

    func placeMarker(screenPoint: CGPoint, serviceType: ServiceType) {
        guard let arView, let markerStore else { return }

        // Prefer detected real plane geometry, then fall back to an estimated plane.
        let exactResults = arView.raycast(from: screenPoint, allowing: .existingPlaneGeometry, alignment: .any)
        let results = exactResults.isEmpty
            ? arView.raycast(from: screenPoint, allowing: .estimatedPlane, alignment: .any)
            : exactResults

        guard let hit = results.first else {
            statusText = "No surface found at the crosshair. Scan the area for a moment and try again."
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }

        let matrix = hit.worldTransform
        let position = SIMD3<Float>(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
        let countForType = markerStore.markers.filter { $0.serviceType == serviceType }.count + 1
        let markerName = "\(serviceType.title) \(countForType)"
        let saved = SavedMarker(name: markerName, serviceType: serviceType, position: position)

        markerStore.add(saved)
        addMarkerEntity(saved)
        selectMarker(saved)

        statusText = "Pinned \(markerName). Keep this AR session running while you move through the building."
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func undoLastMarker() {
        guard let store = markerStore, let last = store.markers.last else { return }
        if let anchor = markerEntities[last.id] {
            arView?.scene.removeAnchor(anchor)
            markerEntities[last.id] = nil
        }
        store.deleteLast()
        updateGuide()
        statusText = "Last pin removed."
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        guard lidarAvailable else {
            statusText = "This iPhone doesn't expose LiDAR scene reconstruction. AR world tracking still works."
            return
        }
        lidarMeshVisible.toggle()
        updateMeshDebugOverlay()
    }

    private func updateMeshDebugOverlay() {
        guard let arView else { return }
        if lidarMeshVisible {
            arView.debugOptions.insert(.showSceneUnderstanding)
        } else {
            arView.debugOptions.remove(.showSceneUnderstanding)
        }
    }

    private func addMarkerEntity(_ marker: SavedMarker) {
        guard let arView else { return }

        let anchor = AnchorEntity(world: marker.position)
        anchor.name = marker.id.uuidString

        let material = SimpleMaterial(color: marker.serviceType.uiColor, isMetallic: false)

        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.035),
            materials: [material]
        )
        sphere.name = marker.name
        anchor.addChild(sphere)

        let ring = ModelEntity(
            mesh: .generateCylinder(height: 0.006, radius: 0.072),
            materials: [material]
        )
        ring.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
        anchor.addChild(ring)

        let stem = ModelEntity(
            mesh: .generateBox(width: 0.010, height: 0.16, depth: 0.010),
            materials: [material]
        )
        stem.position.y = 0.08
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

        // Floating target at the user's current height, directly above/below the selected pin.
        let guidePosition = SIMD3<Float>(marker.position.x, currentPosition.y, marker.position.z)
        let guideMaterial = SimpleMaterial(color: marker.serviceType.uiColor.withAlphaComponent(0.72), isMetallic: false)

        if let guideEntity {
            guideEntity.position = guidePosition
        } else {
            let anchor = AnchorEntity(world: guidePosition)
            let ring = ModelEntity(mesh: .generateCylinder(height: 0.012, radius: 0.10), materials: [guideMaterial])
            ring.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
            anchor.addChild(ring)
            arView.scene.addAnchor(anchor)
            guideEntity = anchor
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let transform = frame.camera.transform
        let pos = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let tracking = frame.camera.trackingState
        let surfaceCount = frame.anchors.reduce(into: 0) { count, anchor in
            if anchor is ARMeshAnchor || anchor is ARPlaneAnchor { count += 1 }
        }

        Task { @MainActor in
            self.currentPosition = pos
            self.mappedSurfaceCount = surfaceCount

            switch tracking {
            case .normal:
                self.trackingText = "Tracking good"
                self.isRelocalizing = false
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
                    self.isRelocalizing = true
                @unknown default:
                    self.trackingText = "Tracking limited"
                }
            }

            self.updateGuide()
        }
    }
}
