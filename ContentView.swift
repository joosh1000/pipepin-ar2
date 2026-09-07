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

            LinearGradient(
                colors: [.black.opacity(0.42), .clear, .clear, .black.opacity(0.50)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                premiumHeader
                Spacer()
                targetReticle
                Spacer()
                targetHUD
                controlDeck
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

    private var premiumHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11)
                            .fill(.white.opacity(0.10))
                            .frame(width: 38, height: 38)
                        Image(systemName: "scope")
                            .font(.system(size: 18, weight: .bold))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("PIPEPIN")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .tracking(1.8)
                        Text("SPATIAL SERVICE LOCATOR")
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .tracking(1.1)
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }

                Spacer()

                statusPill(
                    title: arController.trackingText,
                    icon: "viewfinder",
                    good: arController.trackingText == "Tracking good"
                )

                statusPill(
                    title: arController.lidarAvailable ? "LiDAR" : "AR",
                    icon: "move.3d",
                    good: arController.lidarAvailable
                )
            }

            HStack(spacing: 7) {
                Circle()
                    .fill(selectedType.tint)
                    .frame(width: 7, height: 7)
                    .shadow(color: selectedType.tint, radius: 6)

                Text(arController.statusText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)

                Spacer()

                Text("BEAM \(Int(arController.verticalBeamLength))m")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(selectedType.tint)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }

    private func statusPill(title: String, icon: String, good: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(good ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(.black.opacity(0.30), in: Capsule())
        .overlay { Capsule().stroke(.white.opacity(0.10), lineWidth: 1) }
    }

    private var targetReticle: some View {
        ZStack {
            Circle()
                .stroke(selectedType.tint.opacity(0.28), lineWidth: 1)
                .frame(width: 92, height: 92)

            Circle()
                .stroke(selectedType.tint, lineWidth: 2.5)
                .frame(width: 58, height: 58)
                .shadow(color: selectedType.tint.opacity(0.75), radius: 9)

            Circle()
                .fill(selectedType.tint)
                .frame(width: 8, height: 8)
                .shadow(color: selectedType.tint, radius: 8)

            Rectangle()
                .fill(selectedType.tint)
                .frame(width: 22, height: 2)
            Rectangle()
                .fill(selectedType.tint)
                .frame(width: 2, height: 22)

            VStack {
                Rectangle().fill(selectedType.tint).frame(width: 2, height: 12)
                Spacer().frame(height: 68)
                Rectangle().fill(selectedType.tint).frame(width: 2, height: 12)
            }

            HStack {
                Rectangle().fill(selectedType.tint).frame(width: 12, height: 2)
                Spacer().frame(width: 68)
                Rectangle().fill(selectedType.tint).frame(width: 12, height: 2)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var targetHUD: some View {
        if let marker = markerStore.selectedMarker,
           let horizontal = arController.horizontalDistance,
           let vertical = arController.verticalDifference {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(marker.serviceType.tint.opacity(0.20))
                        .frame(width: 48, height: 48)
                    Image(systemName: marker.serviceType.systemImage)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(marker.serviceType.tint)
                        .shadow(color: marker.serviceType.tint.opacity(0.7), radius: 8)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(marker.name.uppercased())
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .tracking(0.8)

                    Text(horizontal < 0.15 ? "ON VERTICAL LINE" : "MOVE TO LOCATOR BEAM")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(horizontal < 0.15 ? Color.green : Color.white.opacity(0.56))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.2f m", horizontal))
                        .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                    Text(String(format: "%+.2f m VERTICAL", vertical))
                        .font(.system(size: 9, weight: .bold, design: .rounded).monospacedDigit())
                        .tracking(0.4)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(marker.serviceType.tint)
                    .frame(width: 3)
                    .padding(.vertical, 10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(marker.serviceType.tint.opacity(0.20), lineWidth: 1)
            }
            .padding(.bottom, 8)
        }
    }

    private var controlDeck: some View {
        VStack(spacing: 10) {
            HStack {
                Text("SERVICE TYPE")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.46))
                Spacer()
                Text(selectedType.title.uppercased())
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(selectedType.tint)
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ServiceType.allCases) { type in
                        Button {
                            selectedType = type
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: type.systemImage)
                                    .font(.system(size: 14, weight: .bold))
                                Text(type.title)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(selectedType == type ? Color.black : type.tint)
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .background(
                                selectedType == type ? type.tint : Color.black.opacity(0.34),
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .stroke(type.tint.opacity(selectedType == type ? 0.0 : 0.32), lineWidth: 1)
                            }
                            .shadow(
                                color: selectedType == type ? type.tint.opacity(0.35) : .clear,
                                radius: 10
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    showPins = true
                } label: {
                    deckButton(title: "Pins", image: "mappin.and.ellipse")
                }
                .buttonStyle(.plain)

                Button {
                    arController.placeMarkerAtCenter(serviceType: selectedType)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .heavy))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("PIN SERVICE")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .tracking(0.7)
                            Text(selectedType.title.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .tracking(1.0)
                                .opacity(0.68)
                        }
                        Spacer()
                        Image(systemName: selectedType.systemImage)
                            .font(.system(size: 18, weight: .heavy))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(selectedType.tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: selectedType.tint.opacity(0.38), radius: 14, y: 5)
                }
                .buttonStyle(.plain)

                Button {
                    showScan = true
                } label: {
                    deckButton(title: "Scan", image: "move.3d")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }

    private func deckButton(title: String, image: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: image)
                .font(.system(size: 18, weight: .bold))
            Text(title.uppercased())
                .font(.system(size: 8, weight: .heavy, design: .rounded))
                .tracking(0.6)
        }
        .foregroundStyle(.white)
        .frame(width: 58, height: 58)
        .background(.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
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
                        "No service pins",
                        systemImage: "mappin.slash",
                        description: Text("Choose a service type, aim the reticle and tap Pin Service.")
                    )
                } else {
                    Section("Saved services") {
                        ForEach(store.markers) { marker in
                            Button {
                                controller.selectMarker(marker)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(marker.serviceType.tint.opacity(0.16))
                                            .frame(width: 38, height: 38)
                                        Image(systemName: marker.serviceType.systemImage)
                                            .foregroundStyle(marker.serviceType.tint)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(marker.name)
                                            .font(.headline)
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
            .navigationTitle("Service Pins")
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
                Section("Spatial tracking") {
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

                Section("Through-floor locator beam") {
                    LabeledContent("Current beam length", value: "\(Int(controller.verticalBeamLength)) m")

                    HStack(spacing: 10) {
                        beamButton("6 m", value: 6)
                        beamButton("12 m", value: 12)
                        beamButton("20 m", value: 20)
                    }

                    Text("The beam is centred on the exact service pin, so half projects upward and half downward. It is a spatial guide, not an X-ray of the building.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    Text("0.3 adds a premium HUD, stronger service colours and long vertical locator beams designed specifically for transferring a marked point between floors.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Scan & Spatial")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func beamButton(_ title: String, value: Float) -> some View {
        Button {
            controller.setBeamLength(value)
        } label: {
            Text(title)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    abs(controller.verticalBeamLength - value) < 0.1 ? Color.accentColor.opacity(0.22) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10)
                )
        }
        .buttonStyle(.plain)
    }
}
