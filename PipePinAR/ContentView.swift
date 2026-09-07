import SwiftUI

struct ContentView: View {
    @StateObject private var markerStore = MarkerStore()
    @StateObject private var arController = ARSessionController()

    @State private var selectedType: ServiceType = .pipe
    @State private var showMarkers = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            ARViewContainer(controller: arController, markerStore: markerStore)
                .ignoresSafeArea()

            Color.black.opacity(0.08)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 12) {
                topBar
                Spacer()
                reticle
                Spacer()
                if markerStore.selectedMarker != nil {
                    locateCard
                }
                controlDock
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showMarkers) {
            MarkerListView(store: markerStore, controller: arController)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(controller: arController, markerStore: markerStore)
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Image(systemName: "scope")
                        .font(.headline.weight(.bold))
                    Text("PipePin")
                        .font(.headline.weight(.bold))
                    Text("AR")
                        .font(.caption2.weight(.heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.14), in: Capsule())
                }

                Text(arController.statusText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                StatusPill(
                    text: arController.trackingText,
                    systemImage: arController.trackingText == "Tracking good" ? "checkmark.circle.fill" : "viewfinder"
                )

                StatusPill(
                    text: arController.lidarStatusText,
                    systemImage: arController.lidarAvailable ? "move.3d" : "arkit"
                )
            }
        }
        .padding(13)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var reticle: some View {
        ZStack {
            Circle()
                .stroke(selectedType.tint.opacity(0.95), lineWidth: 2)
                .frame(width: 42, height: 42)
            Circle()
                .fill(selectedType.tint)
                .frame(width: 7, height: 7)
            Rectangle()
                .fill(selectedType.tint)
                .frame(width: 14, height: 2)
            Rectangle()
                .fill(selectedType.tint)
                .frame(width: 2, height: 14)
        }
        .shadow(radius: 4)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var locateCard: some View {
        if let marker = markerStore.selectedMarker,
           let horizontal = arController.horizontalDistance,
           let vertical = arController.verticalDifference {
            HStack(spacing: 12) {
                Image(systemName: marker.serviceType.systemImage)
                    .font(.title2)
                    .foregroundStyle(marker.serviceType.tint)
                    .frame(width: 42, height: 42)
                    .background(marker.serviceType.tint.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(marker.name)
                        .font(.subheadline.weight(.semibold))
                    Text(horizontal < 0.15 ? "Directly above / below" : "Locate selected pin")
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var controlDock: some View {
        VStack(spacing: 11) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ServiceType.allCases) { type in
                        Button {
                            selectedType = type
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: type.systemImage)
                                    .font(.system(size: 17, weight: .semibold))
                                Text(type.title)
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(selectedType == type ? .black : .white)
                            .frame(width: 66, height: 54)
                            .background(
                                selectedType == type ? type.tint : .white.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }

            HStack(spacing: 9) {
                Button {
                    showMarkers = true
                } label: {
                    DockButtonLabel(
                        title: "Pins",
                        systemImage: "mappin.and.ellipse",
                        badge: markerStore.markers.isEmpty ? nil : "\(markerStore.markers.count)"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    arController.placeMarkerAtCenter(serviceType: selectedType)
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text("Mark \(selectedType.title)")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(selectedType.tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    showSettings = true
                } label: {
                    DockButtonLabel(title: "Scan", systemImage: arController.lidarAvailable ? "move.3d" : "slider.horizontal.3")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(11)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct StatusPill: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.black.opacity(0.28), in: Capsule())
    }
}

private struct DockButtonLabel: View {
    let title: String
    let systemImage: String
    var badge: String? = nil

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                if let badge {
                    Text(badge)
                        .font(.system(size: 8, weight: .bold))
                        .padding(3)
                        .background(.red, in: Circle())
                        .offset(x: 8, y: -7)
                }
            }
            Text(title)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(width: 58, height: 52)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct MarkerListView: View {
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
                        description: Text("Choose a service type, aim the centre crosshair and tap Mark.")
                    )
                } else {
                    Section("Current AR session") {
                        ForEach(store.markers) { marker in
                            Button {
                                controller.selectMarker(marker)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: marker.serviceType.systemImage)
                                        .foregroundStyle(marker.serviceType.tint)
                                        .frame(width: 30, height: 30)
                                        .background(marker.serviceType.tint.opacity(0.12), in: Circle())

                                    VStack(alignment: .leading, spacing: 2) {
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

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var controller: ARSessionController
    @ObservedObject var markerStore: MarkerStore

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

                Section("Session tools") {
                    Button {
                        controller.undoLastMarker()
                    } label: {
                        Label("Undo last pin", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(markerStore.markers.isEmpty)

                    Button {
                        controller.startSession(reset: false)
                    } label: {
                        Label("Refresh AR configuration", systemImage: "arrow.clockwise")
                    }
                }

                Section {
                    Text("LiDAR scene reconstruction is used for the room mesh, depth and real-world occlusion. ARKit still provides world tracking on supported non-LiDAR iPhones. Service type is currently user-selected; automatic pipe/cable/joist recognition would be a later computer-vision feature.")
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
