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
    @Published var beamLength: Float = 12.0

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

    func placeMarkerAtCenter(
        serviceType: ServiceType,
        orientation: ServiceOrientation,
        flowDirection: FlowDirection
    ) {
        guard let arView else { return }
        let screenPoint = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        placeMarker(
            screenPoint: screenPoint,
            serviceType: serviceType,
            orientation: orientation,
            flowDirection: flowDirection
        )
    }

    private func placeMarker(
        screenPoint: CGPoint,
        serviceType: ServiceType,
        orientation: ServiceOrientation,
        flowDirection: FlowDirection
    ) {
        guard let arView, let markerStore, let activeSiteID = markerStore.activeSiteID else {
            statusText = "Select a site before placing services."
            return
        }

        let results = arView.raycast(from: screenPoint, allowing: .estimatedPlane, alignment: .any)
        guard let hit = results.first else {
            statusText = "No surface found · scan the area slowly and try again."
            return
        }

        let matrix = hit.worldTransform
        let position = SIMD3<Float>(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
        let beamYaw = currentHorizontalBeamYaw()
        let number = markerStore.visibleMarkers.filter { $0.serviceType == serviceType }.count + 1
        let marker = SavedMarker(
            siteID: activeSiteID,
            name: "\(serviceType.title) \(number)",
            serviceType: serviceType,
            orientation: orientation,
            flowDirection: flowDirection,
            beamYaw: beamYaw,
            position: position
        )

        markerStore.add(marker)
        addMarkerEntity(marker)
        selectMarker(marker)

        let directionText = flowDirection == .none ? "no direction arrows" : "direction arrows on"
        statusText = "\(marker.name) pinned · \(orientation.title.lowercased()) beam · \(directionText)."
    }

    private func currentHorizontalBeamYaw() -> Float {
        guard let cameraTransform = arView?.session.currentFrame?.camera.transform else { return 0 }
        let right = SIMD3<Float>(
            cameraTransform.columns.0.x,
            0,
            cameraTransform.columns.0.z
        )
        let length = simd_length(right)
        guard length > 0.001 else { return 0 }
        let direction = right / length
        return atan2(-direction.z, direction.x)
    }

    func undoLastMarker() {
        guard let markerStore, let last = markerStore.visibleMarkers.last else { return }
        if let anchor = markerEntities[last.id] {
            arView?.scene.removeAnchor(anchor)
            markerEntities[last.id] = nil
        }
        markerStore.deleteLastVisible()
        updateGuide()
        statusText = "Last pin removed."
    }

    func rebuildMarkerEntities() {
        guard let arView, let markerStore else { return }
        markerEntities.values.forEach { arView.scene.removeAnchor($0) }
        markerEntities.removeAll()
        markerStore.visibleMarkers.forEach(addMarkerEntity)
        updateGuide()
    }

    func selectMarker(_ marker: SavedMarker?) {
        markerStore?.selectedMarkerID = marker?.id
        updateGuide()
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
        if lidarMeshVisible {
            arView.debugOptions.insert(.showSceneUnderstanding)
        } else {
            arView.debugOptions.remove(.showSceneUnderstanding)
        }
    }

    private func solidMaterial(for serviceType: ServiceType) -> SimpleMaterial {
        SimpleMaterial(
            color: serviceType.uiColor,
            roughness: 0.12,
            isMetallic: false
        )
    }

    private func glowMaterial(for serviceType: ServiceType) -> SimpleMaterial {
        SimpleMaterial(
            color: serviceType.uiColor.withAlphaComponent(0.30),
            roughness: 0.08,
            isMetallic: false
        )
    }

    private func arrowMaterial() -> SimpleMaterial {
        SimpleMaterial(
            color: UIColor.white.withAlphaComponent(0.98),
            roughness: 0.08,
            isMetallic: false
        )
    }

    private func addMarkerEntity(_ marker: SavedMarker) {
        guard let arView else { return }

        let anchor = AnchorEntity(world: marker.position)
        let solid = solidMaterial(for: marker.serviceType)
        let glow = glowMaterial(for: marker.serviceType)

        let pointGlow = ModelEntity(
            mesh: .generateSphere(radius: 0.115),
            materials: [glow]
        )
        anchor.addChild(pointGlow)

        let point = ModelEntity(
            mesh: .generateSphere(radius: 0.072),
            materials: [solid]
        )
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
            beam = ModelEntity(
                mesh: .generateBox(width: 0.060, height: beamLength, depth: 0.060),
                materials: [solid]
            )
            halo = ModelEntity(
                mesh: .generateBox(width: 0.145, height: beamLength, depth: 0.145),
                materials: [glow]
            )
        } else {
            beam = ModelEntity(
                mesh: .generateBox(width: beamLength, height: 0.060, depth: 0.060),
                materials: [solid]
            )
            halo = ModelEntity(
                mesh: .generateBox(width: beamLength, height: 0.145, depth: 0.145),
                materials: [glow]
            )
        }
        beamRoot.addChild(halo)
        beamRoot.addChild(beam)

        addDirectionArrows(to: beamRoot, marker: marker)

        // Exact service point cross. It stays independent of beam orientation so the
        // original picked point remains obvious even with a long horizontal run.
        let crossX = ModelEntity(
            mesh: .generateBox(width: 0.38, height: 0.014, depth: 0.028),
            materials: [solid]
        )
        anchor.addChild(crossX)

        let crossZ = ModelEntity(
            mesh: .generateBox(width: 0.028, height: 0.014, depth: 0.38),
            materials: [solid]
        )
        anchor.addChild(crossZ)

        arView.scene.addAnchor(anchor)
        markerEntities[marker.id] = anchor
    }

    private func addDirectionArrows(to beamRoot: Entity, marker: SavedMarker) {
        guard marker.flowDirection != .none else { return }

        let arrowCount = max(3, min(7, Int(beamLength / 2.0)))
        let usableLength = beamLength * 0.72
        let spacing = usableLength / Float(max(1, arrowCount - 1))
        let start = -usableLength / 2

        for index in 0..<arrowCount {
            let offset = start + Float(index) * spacing
            let arrow = makeChevron(
                orientation: marker.orientation,
                flowDirection: marker.flowDirection
            )

            if marker.orientation == .vertical {
                arrow.position = SIMD3<Float>(0, offset, 0.090)
            } else {
                arrow.position = SIMD3<Float>(offset, 0, 0.090)
            }
            beamRoot.addChild(arrow)
        }
    }

    private func makeChevron(
        orientation: ServiceOrientation,
        flowDirection: FlowDirection
    ) -> Entity {
        let root = Entity()
        let material = arrowMaterial()
        let segmentLength: Float = 0.20
        let thickness: Float = 0.020
        let depth: Float = 0.026

        let upper = ModelEntity(
            mesh: .generateBox(width: segmentLength, height: thickness, depth: depth),
            materials: [material]
        )
        let lower = ModelEntity(
            mesh: .generateBox(width: segmentLength, height: thickness, depth: depth),
            materials: [material]
        )

        // Build a > chevron in local X/Y, then rotate the complete chevron for
        // vertical or reverse direction. Only box meshes are used for compile safety.
        upper.position = SIMD3<Float>(-0.045, 0.050, 0)
        lower.position = SIMD3<Float>(-0.045, -0.050, 0)
        upper.orientation = simd_quatf(angle: -.pi / 4, axis: SIMD3<Float>(0, 0, 1))
        lower.orientation = simd_quatf(angle: .pi / 4, axis: SIMD3<Float>(0, 0, 1))
        root.addChild(upper)
        root.addChild(lower)

        var angle: Float = orientation == .vertical ? .pi / 2 : 0
        if flowDirection == .reverse {
            angle += .pi
        }
        root.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 0, 1))
        return root
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

        // The selected pin always gets an above/below target at the user's current
        // height, regardless of whether the service beam itself is vertical/horizontal.
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
        let glow = glowMaterial(for: marker.serviceType)

        let targetGlow = ModelEntity(
            mesh: .generateSphere(radius: 0.15),
            materials: [glow]
        )
        anchor.addChild(targetGlow)

        let targetX = ModelEntity(
            mesh: .generateBox(width: 0.78, height: 0.024, depth: 0.056),
            materials: [material]
        )
        anchor.addChild(targetX)

        let targetZ = ModelEntity(
            mesh: .generateBox(width: 0.056, height: 0.024, depth: 0.78),
            materials: [material]
        )
        anchor.addChild(targetZ)

        let targetPoint = ModelEntity(
            mesh: .generateSphere(radius: 0.085),
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
