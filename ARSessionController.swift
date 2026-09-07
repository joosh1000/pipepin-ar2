import ARKit
import RealityKit
import SwiftUI

@MainActor
final class ARSessionController: NSObject, ObservableObject, ARSessionDelegate {
    weak var arView: ARView?

    @Published var statusText = "Move slowly while PipePin maps the space."
    @Published var trackingText = "Starting AR…"
    @Published var currentPosition: SIMD3<Float> = .zero
    @Published var horizontalDistance: Float?
    @Published var verticalDifference: Float?
    @Published var lidarAvailable = false
    @Published var lidarMeshVisible = false
    @Published var mappedSurfaceCount = 0
    @Published var verticalBeamLength: Float = 12.0

    var markerStore: MarkerStore?
    private var markerEntities: [UUID: AnchorEntity] = [:]
    private var guideEntity: AnchorEntity?
    private var guideMarkerID: UUID?

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
            statusText = "LiDAR mapping active · aim at a service and pin it."
        } else {
            statusText = "World tracking active · aim at a visible surface and pin it."
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
            statusText = "No surface found · scan the area slowly and try again."
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
        statusText = "\(marker.name) pinned · vertical locator beam is live."
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

    func setBeamLength(_ length: Float) {
        verticalBeamLength = min(max(length, 4.0), 20.0)
        rebuildMarkerEntities()
        statusText = "Locator beams set to \(Int(verticalBeamLength)) m."
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

    private func solidMaterial(for serviceType: ServiceType) -> SimpleMaterial {
        SimpleMaterial(
            color: serviceType.uiColor,
            roughness: 0.18,
            isMetallic: false
        )
    }

    private func glowMaterial(for serviceType: ServiceType) -> SimpleMaterial {
        SimpleMaterial(
            color: serviceType.uiColor.withAlphaComponent(0.22),
            roughness: 0.10,
            isMetallic: false
        )
    }

    private func addMarkerEntity(_ marker: SavedMarker) {
        guard let arView else { return }

        let anchor = AnchorEntity(world: marker.position)
        let solid = solidMaterial(for: marker.serviceType)
        let glow = glowMaterial(for: marker.serviceType)

        // Exact service point.
        let point = ModelEntity(
            mesh: .generateSphere(radius: 0.070),
            materials: [solid]
        )
        point.name = marker.name
        anchor.addChild(point)

        // White centre makes the exact picked point easy to identify.
        let centre = ModelEntity(
            mesh: .generateSphere(radius: 0.018),
            materials: [SimpleMaterial(color: .white, roughness: 0.1, isMetallic: false)]
        )
        anchor.addChild(centre)

        // Long vertical service beam: 12 m by default, centred on the real pin so it
        // projects above and below the marked point through floors / ceilings.
        let beam = ModelEntity(
            mesh: .generateBox(width: 0.050, height: verticalBeamLength, depth: 0.050),
            materials: [solid]
        )
        anchor.addChild(beam)

        // Softer outer beam gives the marker more visual presence in bright spaces.
        let halo = ModelEntity(
            mesh: .generateBox(width: 0.120, height: verticalBeamLength, depth: 0.120),
            materials: [glow]
        )
        anchor.addChild(halo)

        // Horizontal cross at the exact marked elevation.
        let crossX = ModelEntity(
            mesh: .generateBox(width: 0.34, height: 0.012, depth: 0.024),
            materials: [solid]
        )
        anchor.addChild(crossX)

        let crossZ = ModelEntity(
            mesh: .generateBox(width: 0.024, height: 0.012, depth: 0.34),
            materials: [solid]
        )
        anchor.addChild(crossZ)

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
            guideMarkerID = nil
            return
        }

        let delta = marker.position - currentPosition
        horizontalDistance = sqrt(delta.x * delta.x + delta.z * delta.z)
        verticalDifference = delta.y

        // A bright target cross is always drawn at the user's current height but at
        // the selected pin's X/Z position. This is the "directly above/below" target.
        let guidePosition = SIMD3<Float>(marker.position.x, currentPosition.y, marker.position.z)

        if let guideEntity, guideMarkerID == marker.id {
            guideEntity.position = guidePosition
            return
        }

        if let guideEntity {
            arView.scene.removeAnchor(guideEntity)
            self.guideEntity = nil
        }

        let anchor = AnchorEntity(world: guidePosition)
        let material = solidMaterial(for: marker.serviceType)

        let targetX = ModelEntity(
            mesh: .generateBox(width: 0.70, height: 0.020, depth: 0.050),
            materials: [material]
        )
        anchor.addChild(targetX)

        let targetZ = ModelEntity(
            mesh: .generateBox(width: 0.050, height: 0.020, depth: 0.70),
            materials: [material]
        )
        anchor.addChild(targetZ)

        let targetPoint = ModelEntity(
            mesh: .generateSphere(radius: 0.080),
            materials: [material]
        )
        anchor.addChild(targetPoint)

        arView.scene.addAnchor(anchor)
        guideEntity = anchor
        guideMarkerID = marker.id
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
