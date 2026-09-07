import SwiftUI

struct ContentView: View {
    @StateObject private var markerStore = MarkerStore()
    @StateObject private var arController = ARSessionController()
    @State private var selectedType: ServiceType = .pipe
    @State private var showPins = false
    @State private var showScan = false

    var body: some View {
        ZStack {
            ARViewContainer(controller: arController, markerStore: markerStore)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                topBar
                Spacer()
                reticle
                Spacer()
                locateCard
                bottomDock
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPins) {
            PinsView(store: markerStore, controller: arController)
        }
        .sheet(isPresented: $showScan) {
            ScanView(store: markerStore, controller: arController)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Image(systemName: "scope")
                    Text("PipePin")
                        .font(.headline.bold())
                    Text("AR")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.12), in: Capsule())
                }

                Text(arController.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Label(arController.trackingText, systemImage: "viewfinder")
                    .font(.caption2.bold())
                Label(arController.lidarStatusText, systemImage: "move.3d")
                    .font(.caption2.bold())
            }
        }
        .padding(13)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var reticle: some View {
        ZStack {
            Circle()
                .stroke(selectedType.tint, lineWidth: 2)
                .frame(width: 46, height: 46)
            Circle()
                .fill(selectedType.tint)
                .frame(width: 7, height: 7)
            Rectangle()
                .fill(selectedType.tint)
                .frame(width: 16, height: 2)
            Rectangle()
                .fill(selectedType.tint)
                .frame(width: 2, height: 16)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var locateCard: some View {
        if let marker = markerStore.selectedMarker,
           let horizontal = arController.horizontalDistance,
           let vertical = arController.verticalDifference {
            HStack(spacing: 12) {
                Image(systemName: marker.serviceType.systemImage)
                    .foregroundStyle(marker.serviceType.tint)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(marker.name)
                        .font(.subheadline.bold())
                    Text(horizontal < 0.15 ? "Directly above / below" : "Move toward selected pin")
                        .font(.caption)
                        .foregroundStyle(horizontal < 0.15 ? Color.green : Color.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2f m", horizontal))
                        .font(.headline.monospacedDigit())
                    Text(String(format: "%+.2f m vertical", vertical))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var bottomDock: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ServiceType.allCases) { type in
                        Button {
                            selectedType = type
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: type.systemImage)
                                    .font(.system(size: 17, weight: .semibold))
                                Text(type.title)
                                    .font(.caption2.bold())
                            }
                            .foregroundStyle(selectedType == type ? Color.black : Color.white)
                            .frame(width: 68, height: 54)
                            .background(
                                selectedType == type ? type.tint : Color.white.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 9) {
                Button {
                    showPins = true
                } label: {
                    sideButton(title: "Pins", image: "mappin.and.ellipse")
                }
                .buttonStyle(.plain)

                Button {
                    arController.placeMarkerAtCenter(serviceType: selectedType)
                } label: {
                    Label("Mark \(selectedType.title)", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(selectedType.tint, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Button {
                    showScan = true
                } label: {
                    sideButton(title: "Scan", image: "move.3d")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(11)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private func sideButton(title: String, image: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: image)
                .font(.system(size: 18, weight: .semibold))
            Text(title)
                .font(.caption2.bold())
        }
        .foregroundStyle(.white)
        .frame(width: 58, height: 52)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
    }
}

private extension ServiceType {
    var systemImage: String {
        switch self {
        case .pipe: return "line.diagonal"
        case .cable: return "cable.connector"
        case .joist: return "rectangle.split.3x1"
        case .duct: return "wind"
        case .drain: return "drop.fill"
        case .gas: return "flame.fill"
        case .structure: return "building.columns.fill"
        case .fixing: return "scope"
        case .other: return "mappin"
        }
    }

    var tint: Color {
        switch self {
        case .pipe: return .cyan
        case .cable: return .orange
        case .joist: return .brown
        case .duct: return .mint
        case .drain: return .blue
        case .gas: return .yellow
        case .structure: return .purple
        case .fixing: return .pink
        case .other: return .gray
        }
    }
}

struct PinsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: MarkerStore
    @ObservedObject var controller: ARSessionController

    var body: some View {
        NavigationStack {
            List {
                if store.markers.isEmpty {
                    ContentUnavailableView(
                        "No pins yet",
                        systemImage: "mappin.slash",
                        description: Text("Choose a service type, aim the crosshair and tap Mark.")
                    )
                } else {
                    ForEach(store.markers) { marker in
                        Button {
                            controller.selectMarker(marker)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: marker.serviceType.systemImage)
                                    .foregroundStyle(marker.serviceType.tint)
                                VStack(alignment: .leading) {
                                    Text(marker.name)
                                        .foregroundStyle(.primary)
                                    Text(marker.createdAt, format: .dateTime.hour().minute().day().month())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if marker.id == store.selectedMarkerID {
                                    Image(systemName: "scope")
                                        .foregroundStyle(marker.serviceType.tint)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        store.delete(at: offsets)
                        controller.rebuildMarkerEntities()
                    }
                }
            }
            .navigationTitle("Pins")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: MarkerStore
    @ObservedObject var controller: ARSessionController

    var body: some View {
        NavigationStack {
            Form {
                Section("Spatial scan") {
                    LabeledContent("Tracking", value: controller.trackingText)
                    LabeledContent("LiDAR", value: controller.lidarAvailable ? "Available / active" : "Not available")
                    LabeledContent("Mapped surfaces", value: "\(controller.mappedSurfaceCount)")

                    Button {
                        controller.toggleLiDARMesh()
                    } label: {
                        Label(
                            controller.lidarMeshVisible ? "Hide LiDAR mesh" : "Show LiDAR mesh",
                            systemImage: "move.3d"
                        )
                    }
                    .disabled(!controller.lidarAvailable)
                }

                Section("Session") {
                    Button {
                        controller.undoLastMarker()
                    } label: {
                        Label("Undo last pin", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(store.markers.isEmpty)

                    Button {
                        controller.startSession(reset: false)
                    } label: {
                        Label("Refresh AR configuration", systemImage: "arrow.clockwise")
                    }
                }

                Section {
                    Text("0.2.2 deliberately uses the same proven ARKit world-tracking foundation as the working 0.1 build. LiDAR mesh reconstruction is enabled where supported; service recognition is still selected manually.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Scan & LiDAR")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
