import SwiftUI

struct ContentView: View {
    @StateObject private var siteStore = SiteStore()
    @StateObject private var markerStore = MarkerStore()
    @StateObject private var areaStore = SiteAreaStore()
    @StateObject private var arController = ARSessionController()
    @State private var selectedSite: SiteRecord?

    var body: some View {
        Group {
            if let selectedSite {
                ARWorkspaceView(
                    site: selectedSite,
                    markerStore: markerStore,
                    areaStore: areaStore,
                    arController: arController,
                    onChangeSite: {
                        self.selectedSite = nil
                    }
                )
                .onAppear {
                    markerStore.activate(siteID: selectedSite.id)
                }
            } else {
                SitesHomeView(
                    siteStore: siteStore,
                    markerStore: markerStore,
                    areaStore: areaStore,
                    onSelect: { site in
                        markerStore.activate(siteID: site.id)
                        selectedSite = site
                    },
                    onDelete: { site in
                        markerStore.deleteMarkers(for: site.id)
                        areaStore.deleteAreas(for: site.id)
                        siteStore.delete(site)
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct SitesHomeView: View {
    @ObservedObject var siteStore: SiteStore
    @ObservedObject var markerStore: MarkerStore
    @ObservedObject var areaStore: SiteAreaStore
    let onSelect: (SiteRecord) -> Void
    let onDelete: (SiteRecord) -> Void

    @State private var showCreateSite = false
    @State private var deleteCandidate: SiteRecord?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.035, blue: 0.055),
                    Color(red: 0.015, green: 0.018, blue: 0.030),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.cyan.opacity(0.11))
                .frame(width: 330, height: 330)
                .blur(radius: 55)
                .offset(x: 170, y: -330)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                sitesHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 18)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        introCard

                        HStack {
                            Text("YOUR SITES")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .tracking(1.6)
                                .foregroundStyle(.white.opacity(0.46))
                            Spacer()
                            Text("\(siteStore.sites.count)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.58))
                        }

                        if siteStore.sites.isEmpty {
                            emptySites
                        } else {
                            VStack(spacing: 10) {
                                ForEach(siteStore.sites) { site in
                                    siteCard(site)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 120)
                }
            }

            VStack {
                Spacer()
                Button {
                    showCreateSite = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .heavy))
                        Text("CREATE SITE")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .tracking(1.0)
                        Spacer()
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .frame(height: 60)
                    .background(Color.cyan, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.cyan.opacity(0.28), radius: 22, y: 8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
        .sheet(isPresented: $showCreateSite) {
            CreateSiteView(siteStore: siteStore) { site in
                markerStore.activate(siteID: site.id)
                onSelect(site)
            }
        }
        .confirmationDialog(
            "Delete this site?",
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete site and its local test pins", role: .destructive) {
                if let deleteCandidate {
                    onDelete(deleteCandidate)
                }
                deleteCandidate = nil
            }
            Button("Cancel", role: .cancel) {
                deleteCandidate = nil
            }
        } message: {
            Text("This prototype stores sites and pins on this iPhone only.")
        }
    }

    private var sitesHeader: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .fill(.white.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: "scope")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Color.cyan)
                    .shadow(color: Color.cyan.opacity(0.60), radius: 8)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text("PIPEPIN")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .tracking(2.0)
                    Text("0.5")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.09), in: Capsule())
                }
                Text("SPATIAL SERVICE MAPPING")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("START WITH THE BUILDING")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(Color.cyan)
                Spacer()
                Image(systemName: "cube.transparent")
                    .foregroundStyle(Color.cyan)
            }

            Text("Select the site before scanning or pinning services.")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)

            Text("Pins, routes and future 3D scans will stay grouped around the building they belong to.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var emptySites: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "building.2")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(Color.cyan)
            }
            Text("No sites yet")
                .font(.headline)
            Text("Create the building or job you are standing in, then open its AR workspace.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
        .padding(.horizontal, 24)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func siteCard(_ site: SiteRecord) -> some View {
        Button {
            onSelect(site)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.cyan.opacity(0.11))
                        .frame(width: 54, height: 54)
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.cyan)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(site.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if !site.address.isEmpty {
                        Text(site.address)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.50))
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        Label("\(markerStore.count(for: site.id)) pins", systemImage: "mappin.and.ellipse")
                        if !site.reference.isEmpty {
                            Text("•")
                            Text(site.reference)
                        }
                    }
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color.cyan)
            }
            .padding(14)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                deleteCandidate = site
            } label: {
                Label("Delete site", systemImage: "trash")
            }
        }
    }
}

struct CreateSiteView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var siteStore: SiteStore
    let onCreated: (SiteRecord) -> Void

    @State private var name = ""
    @State private var address = ""
    @State private var reference = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Site") {
                    TextField("Site / building name", text: $name)
                    TextField("Address (optional)", text: $address, axis: .vertical)
                    TextField("Job ID / reference (optional)", text: $reference)
                }

                Section {
                    Text("This is the container for service pins now and for room scans, routes and the future building model later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Site")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        let site = siteStore.add(name: name, address: address, reference: reference)
                        dismiss()
                        onCreated(site)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct ARWorkspaceView: View {
    let site: SiteRecord
    @ObservedObject var markerStore: MarkerStore
    @ObservedObject var areaStore: SiteAreaStore
    @ObservedObject var arController: ARSessionController
    let onChangeSite: () -> Void

    @State private var selectedType: ServiceType = .pipe
    @State private var selectedOrientation: ServiceOrientation = .vertical
    @State private var selectedFlow: FlowDirection = .none
    @State private var showPins = false
    @State private var showScan = false
    @State private var showAreas = false
    @State private var selectedAreaID: UUID?

    var body: some View {
        ZStack {
            ARViewContainer(controller: arController, markerStore: markerStore)
                .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.48), .clear, .clear, .black.opacity(0.64)],
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
            PinsView(site: site, store: markerStore, controller: arController)
        }
        .sheet(isPresented: $showScan) {
            ScanView(site: site, store: markerStore, controller: arController)
        }
        .sheet(isPresented: $showAreas) {
            AreasView(site: site, areaStore: areaStore, selectedAreaID: $selectedAreaID)
        }
        .onAppear {
            if selectedAreaID == nil {
                selectedAreaID = areaStore.ensureDefault(for: site.id).id
            }
            arController.refreshSavedMapState()
        }
    }

    private var selectedArea: SiteArea? {
        let areas = areaStore.areas(for: site.id)
        if let selectedAreaID, let match = areas.first(where: { $0.id == selectedAreaID }) { return match }
        return areas.first
    }

    private var premiumHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    onChangeSite()
                } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 11)
                                .fill(.white.opacity(0.10))
                                .frame(width: 38, height: 38)
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.cyan)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(site.name.uppercased())
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .tracking(0.8)
                                .lineLimit(1)
                            HStack(spacing: 5) {
                                Text("PIPEPIN")
                                Text("0.5")
                            }
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .tracking(1.0)
                            .foregroundStyle(.white.opacity(0.52))
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                statusPill(
                    title: arController.precisionText,
                    icon: "scope",
                    good: arController.precisionReady
                )

                statusPill(
                    title: arController.lidarAvailable ? "LiDAR" : "AR",
                    icon: "move.3d",
                    good: arController.lidarAvailable
                )

                Button {
                    switch arController.torchSetting {
                    case .auto: arController.setTorch(.on)
                    case .on: arController.setTorch(.off)
                    case .off: arController.setTorch(.auto)
                    }
                } label: {
                    Image(systemName: arController.torchIsOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(arController.torchIsOn ? Color.yellow : Color.white.opacity(0.72))
                        .frame(width: 30, height: 28)
                        .background(.black.opacity(0.30), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 7) {
                Circle()
                    .fill(selectedType.tint)
                    .frame(width: 7, height: 7)
                    .shadow(color: selectedType.tint, radius: 7)

                Text(arController.statusText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)

                Spacer()

                Button {
                    showAreas = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.3.layers.3d")
                        Text(selectedArea?.displayName ?? "Set area")
                            .lineLimit(1)
                    }
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.cyan)
                }
                .buttonStyle(.plain)

                HStack(spacing: 5) {
                    Image(systemName: selectedOrientation.systemImage)
                    Text("\(Int(arController.beamLength))m")
                    if selectedFlow != .none {
                        Image(systemName: selectedFlow.systemImage(for: selectedOrientation))
                    }
                }
                .font(.system(size: 9, weight: .heavy, design: .rounded))
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
                .stroke(selectedType.tint.opacity(0.24), lineWidth: 1)
                .frame(width: 96, height: 96)

            Circle()
                .stroke(selectedType.tint, lineWidth: 2.8)
                .frame(width: 58, height: 58)
                .shadow(color: selectedType.tint.opacity(0.90), radius: 11)

            Circle()
                .fill(.white)
                .frame(width: 5, height: 5)
                .shadow(color: selectedType.tint, radius: 10)

            Rectangle()
                .fill(selectedType.tint)
                .frame(width: 24, height: 2)
            Rectangle()
                .fill(selectedType.tint)
                .frame(width: 2, height: 24)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var targetHUD: some View {
        if !arController.markersReliable && !markerStore.visibleMarkers.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("POSITION UNCERTAIN")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(0.7)
                    Text("Service beams are hidden until ARKit relocks. Scan the surroundings or use Re-lock in Precision & Mapping.")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.orange.opacity(0.34), lineWidth: 1)
            }
            .padding(.bottom, 8)
        } else if let marker = markerStore.selectedMarker,
           let horizontal = arController.horizontalDistance,
           let vertical = arController.verticalDifference {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(marker.serviceType.tint.opacity(0.22))
                        .frame(width: 50, height: 50)
                    Image(systemName: marker.serviceType.systemImage)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(marker.serviceType.tint)
                        .shadow(color: marker.serviceType.tint.opacity(0.85), radius: 9)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(marker.name.uppercased())
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .tracking(0.7)

                    HStack(spacing: 6) {
                        Label(marker.orientation.title, systemImage: marker.orientation.systemImage)
                        if marker.flowDirection != .none {
                            Label(
                                marker.flowDirection.title(for: marker.orientation),
                                systemImage: marker.flowDirection.systemImage(for: marker.orientation)
                            )
                        }
                    }
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .foregroundStyle(marker.serviceType.tint)

                    Text(horizontal < 0.15 ? "ON ABOVE / BELOW TARGET" : "MOVE TO TARGET LINE")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(0.55)
                        .foregroundStyle(horizontal < 0.15 ? Color.green : Color.white.opacity(0.52))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    Text(String(format: "%.2f m", horizontal))
                        .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                    Text(String(format: "%+.2f m VERTICAL", vertical))
                        .font(.system(size: 9, weight: .bold, design: .rounded).monospacedDigit())
                        .tracking(0.3)
                        .foregroundStyle(.white.opacity(0.50))

                    Button {
                        arController.stopLocating()
                    } label: {
                        Label("STOP LOCATE", systemImage: "xmark.circle.fill")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(marker.serviceType.tint)
                    .frame(width: 4)
                    .padding(.vertical, 10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(marker.serviceType.tint.opacity(0.24), lineWidth: 1)
            }
            .padding(.bottom, 8)
        }
    }

    private var controlDeck: some View {
        VStack(spacing: 10) {
            HStack {
                Text("SERVICE")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.44))
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
                                    .stroke(type.tint.opacity(selectedType == type ? 0.0 : 0.34), lineWidth: 1)
                            }
                            .shadow(
                                color: selectedType == type ? type.tint.opacity(0.38) : .clear,
                                radius: 11
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 8) {
                configLabel("RUN")
                configButton(
                    title: "Vertical",
                    image: "arrow.up.and.down",
                    active: selectedOrientation == .vertical
                ) {
                    selectedOrientation = .vertical
                }
                configButton(
                    title: "Horizontal",
                    image: "arrow.left.and.right",
                    active: selectedOrientation == .horizontal
                ) {
                    selectedOrientation = .horizontal
                }
            }

            HStack(spacing: 8) {
                configLabel("FLOW")
                ForEach(FlowDirection.allCases) { direction in
                    configButton(
                        title: direction.title(for: selectedOrientation),
                        image: direction.systemImage(for: selectedOrientation),
                        active: selectedFlow == direction
                    ) {
                        selectedFlow = direction
                    }
                }
            }

            if selectedOrientation == .horizontal {
                HStack(spacing: 6) {
                    Image(systemName: "iphone.gen3")
                    Text("Horizontal beam follows the direction the rear camera is facing when you pin. Aim the phone along the service run, then press Pin Service.")
                }
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.44))
                .padding(.horizontal, 4)
            }

            HStack(spacing: 10) {
                Button {
                    showPins = true
                } label: {
                    deckButton(title: "Pins", image: "mappin.and.ellipse")
                }
                .buttonStyle(.plain)

                Button {
                    arController.placeMarkerAtCenter(
                        serviceType: selectedType,
                        orientation: selectedOrientation,
                        flowDirection: selectedFlow,
                        area: selectedArea
                    )
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .heavy))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(arController.isPrecisionCapturing ? "HOLD STILL…" : "PRECISION PIN")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .tracking(0.7)
                            Text(arController.isPrecisionCapturing ? "CAPTURING \(Int(arController.captureProgress * 100))%" : pinSubtitle)
                                .font(.system(size: 8, weight: .heavy, design: .rounded))
                                .tracking(0.6)
                                .lineLimit(1)
                                .opacity(0.68)
                        }
                        Spacer()
                        Image(systemName: selectedOrientation.systemImage)
                            .font(.system(size: 18, weight: .heavy))
                    }
                    .foregroundStyle(arController.precisionReady || arController.isPrecisionCapturing ? Color.black : Color.white.opacity(0.66))
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(arController.precisionReady || arController.isPrecisionCapturing ? selectedType.tint : Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: arController.precisionReady ? selectedType.tint.opacity(0.42) : .clear, radius: 16, y: 6)
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

    private var pinSubtitle: String {
        var parts = [selectedType.title.uppercased(), selectedOrientation.title.uppercased()]
        if selectedFlow != .none {
            parts.append(selectedFlow.title(for: selectedOrientation).uppercased())
        }
        return parts.joined(separator: " · ")
    }

    private func configLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .heavy, design: .rounded))
            .tracking(0.7)
            .foregroundStyle(.white.opacity(0.38))
            .frame(width: 38, alignment: .leading)
    }

    private func configButton(
        title: String,
        image: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: image)
                    .font(.system(size: 10, weight: .heavy))
                Text(title)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(active ? Color.black : Color.white.opacity(0.68))
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(active ? selectedType.tint : Color.black.opacity(0.28), in: Capsule())
            .overlay {
                Capsule().stroke(active ? Color.clear : .white.opacity(0.09), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
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
    let site: SiteRecord
    @ObservedObject var store: MarkerStore
    @ObservedObject var controller: ARSessionController

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Site", value: site.name)
                    LabeledContent("Services", value: "\(store.visibleMarkers.count)")
                }

                if store.visibleMarkers.isEmpty {
                    ContentUnavailableView(
                        "No service pins",
                        systemImage: "mappin.slash",
                        description: Text("Choose a service, orientation and optional direction, then aim the reticle and pin it.")
                    )
                } else {
                    Section("Saved services") {
                        ForEach(store.visibleMarkers) { marker in
                            Button {
                                controller.selectMarker(marker)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(marker.serviceType.tint.opacity(0.18))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: marker.serviceType.systemImage)
                                            .foregroundStyle(marker.serviceType.tint)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(marker.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        HStack(spacing: 7) {
                                            Label(marker.orientation.title, systemImage: marker.orientation.systemImage)
                                            if marker.flowDirection != .none {
                                                Text("•")
                                                Label(
                                                    marker.flowDirection.title(for: marker.orientation),
                                                    systemImage: marker.flowDirection.systemImage(for: marker.orientation)
                                                )
                                            }
                                        }
                                        .font(.caption2.bold())
                                        .foregroundStyle(marker.serviceType.tint)
                                        if !marker.floorName.isEmpty || !marker.roomName.isEmpty {
                                            Text([marker.floorName, marker.roomName].filter { !$0.isEmpty }.joined(separator: " · "))
                                                .font(.caption2.bold())
                                                .foregroundStyle(.secondary)
                                        }
                                        HStack(spacing: 6) {
                                            Text(marker.pinSource.title)
                                            if marker.captureConfidence > 0 {
                                                Text("•")
                                                Text("confidence \(marker.captureConfidence)/2")
                                            }
                                        }
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        Text(marker.createdAt, format: .dateTime.hour().minute().day().month())
                                            .font(.caption2)
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
                            store.deleteVisible(at: offsets)
                            controller.rebuildMarkerEntities()
                        }
                    }
                }
            }
            .navigationTitle("Service Pins")
            .navigationBarTitleDisplayMode(.inline)
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
    let site: SiteRecord
    @ObservedObject var store: MarkerStore
    @ObservedObject var controller: ARSessionController

    var body: some View {
        NavigationStack {
            Form {
                Section("Precision status") {
                    LabeledContent("Precision", value: controller.precisionText)
                    LabeledContent("Tracking", value: controller.trackingText)
                    LabeledContent("World map", value: controller.mappingText)
                    LabeledContent("Beams trustworthy", value: controller.markersReliable ? "Yes" : "Hidden / uncertain")

                    if controller.isPrecisionCapturing {
                        ProgressView(value: controller.captureProgress)
                        Button("Cancel precision capture", role: .cancel) {
                            controller.cancelPrecisionCapture()
                        }
                    }
                }

                Section("LiDAR target") {
                    LabeledContent("LiDAR", value: controller.lidarAvailable ? "Available / active" : "Not available")
                    LabeledContent("Centre depth", value: controller.depthDistance.map { String(format: "%.2f m", $0) } ?? "No reading")
                    LabeledContent("Depth confidence", value: "\(controller.depthConfidence) / 2")
                    LabeledContent("Mapped surfaces", value: "\(controller.mappedSurfaceCount)")
                    LabeledContent("Last pin source", value: controller.lastPinSourceText)

                    Button {
                        controller.toggleLiDARMesh()
                    } label: {
                        Label(controller.lidarMeshVisible ? "Hide LiDAR mesh" : "Show LiDAR mesh", systemImage: "move.3d")
                    }
                    .disabled(!controller.lidarAvailable)
                }

                Section("Light & movement") {
                    LabeledContent("Ambient light", value: String(format: "%.0f", controller.ambientLight))
                    LabeledContent("Low light", value: controller.lowLight ? "Yes" : "No")
                    LabeledContent("Phone speed", value: String(format: "%.2f m/s", controller.motionSpeed))

                    Picker("Torch", selection: Binding(
                        get: { controller.torchSetting },
                        set: { controller.setTorch($0) }
                    )) {
                        ForEach(TorchSetting.allCases) { setting in
                            Text(setting.rawValue).tag(setting)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Auto uses the continuous rear torch when PipePin detects low light. LiDAR can still measure in darkness, but extra camera detail can help visual tracking and relocalisation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Saved Site Map") {
                    LabeledContent("Saved map", value: controller.hasSavedWorldMap ? "Available" : "Not saved")
                    if let mapSavedAt = controller.mapSavedAt {
                        LabeledContent("Saved", value: mapSavedAt.formatted(date: .abbreviated, time: .shortened))
                    }

                    Button {
                        controller.saveSiteWorldMap()
                    } label: {
                        Label("Save / update Site Map", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        controller.relockToSavedMap()
                    } label: {
                        Label("Re-lock to saved Site Map", systemImage: "scope")
                    }
                    .disabled(!controller.hasSavedWorldMap)

                    Text("If PipePin loses position between rooms, it now hides the beams instead of confidently showing a potentially wrong location. Re-lock loads the saved AR world map and waits for the environment to be recognised again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Accuracy test") {
                    if let last = store.visibleMarkers.last {
                        Text("Return to the physical point used for \(last.name), aim the centre reticle at exactly the same point, then run the check.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            controller.beginAccuracyCheck(marker: last)
                            dismiss()
                        } label: {
                            Label("Check \(last.name) return accuracy", systemImage: "ruler")
                        }
                    } else {
                        Text("Create at least one precision pin first.")
                            .foregroundStyle(.secondary)
                    }

                    if let mm = controller.accuracyResultMM {
                        LabeledContent("Last measured error", value: "\(mm) mm")
                    }
                }

                Section("Locator beam length") {
                    LabeledContent("Current beam length", value: "\(Int(controller.beamLength)) m")
                    HStack(spacing: 10) {
                        beamButton("6 m", value: 6)
                        beamButton("12 m", value: 12)
                        beamButton("20 m", value: 20)
                    }
                }

                Section("Diagnostics") {
                    Text(controller.diagnosticSummary)
                        .font(.system(.caption, design: .monospaced))
                    LabeledContent("Tracking interruptions", value: "\(controller.interruptionCount)")
                    LabeledContent("Re-lock attempts", value: "\(controller.relocalizationCount)")
                    Text("This diagnostic block is intentionally exposed in the test build so we can correlate a beam jump with what ARKit thought was happening at that moment.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Session") {
                    Button {
                        controller.undoLastMarker()
                    } label: {
                        Label("Undo last pin on this site", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(store.visibleMarkers.isEmpty)

                    Button {
                        controller.startSession(reset: false, preferSavedMap: false)
                    } label: {
                        Label("Refresh current AR session", systemImage: "arrow.clockwise")
                    }
                }

                Section {
                    Text("PipePin 0.5 Precision Mapping. The priority of this build is measurement confidence rather than adding more visual features.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Precision & Mapping")
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
                    abs(controller.beamLength - value) < 0.1 ? Color.accentColor.opacity(0.22) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10)
                )
        }
        .buttonStyle(.plain)
    }
}

struct AreasView: View {
    @Environment(\.dismiss) private var dismiss
    let site: SiteRecord
    @ObservedObject var areaStore: SiteAreaStore
    @Binding var selectedAreaID: UUID?

    @State private var floorName = "Ground Floor"
    @State private var roomName = ""

    var siteAreas: [SiteArea] { areaStore.areas(for: site.id) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Current mapping area") {
                    ForEach(siteAreas) { area in
                        Button {
                            selectedAreaID = area.id
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(area.floorName)
                                        .font(.headline)
                                    Text(area.roomName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if area.id == selectedAreaID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.cyan)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        let current = siteAreas
                        for index in offsets where current.indices.contains(index) {
                            let area = current[index]
                            areaStore.delete(area)
                            if selectedAreaID == area.id {
                                selectedAreaID = areaStore.ensureDefault(for: site.id).id
                            }
                        }
                    }
                }

                Section("Add floor / room") {
                    TextField("Floor, e.g. First Floor", text: $floorName)
                    TextField("Room, e.g. Plant Room", text: $roomName)
                    Button {
                        let area = areaStore.add(siteID: site.id, floorName: floorName, roomName: roomName)
                        selectedAreaID = area.id
                        roomName = ""
                    } label: {
                        Label("Add mapping area", systemImage: "plus")
                    }
                }

                Section {
                    Text("Every new service pin is tagged to the selected Site, Floor and Room. This is also the hierarchy PipePin will use for future multi-room and 3D building maps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Floor & Room")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
