import SwiftUI

struct ContentView: View {
    @StateObject private var markerStore = MarkerStore()
    @StateObject private var arController = ARSessionController()
    @State private var showMarkers = false

    var body: some View {
        ZStack {
            ARViewContainer(controller: arController, markerStore: markerStore)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                header
                Spacer()
                alignmentCard
                controls
            }
            .padding()
        }
        .sheet(isPresented: $showMarkers) {
            MarkerListView(store: markerStore, controller: arController)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("PIPEPIN AR")
                    .font(.headline.weight(.heavy))
                Spacer()
                Text(arController.trackingText)
                    .font(.caption)
            }
            Text(arController.statusText)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var alignmentCard: some View {
        if let marker = markerStore.selectedMarker,
           let horizontal = arController.horizontalDistance,
           let vertical = arController.verticalDifference {
            VStack(spacing: 6) {
                Text(marker.name)
                    .font(.headline)
                Text(horizontal < 0.15 ? "YOU'RE ABOVE / BELOW THE MARKER" : "Move toward the marker")
                    .font(.caption.weight(.bold))
                Text(String(format: "Horizontal offset %.2f m", horizontal))
                    .font(.title3.monospacedDigit())
                Text(String(format: "Vertical difference %+.2f m", vertical))
                    .font(.subheadline.monospacedDigit())
                ProgressView(value: max(0, min(1, 1 - Double(horizontal / 2))))
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                arController.startSession(reset: true)
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                showMarkers = true
            } label: {
                Label("Markers", systemImage: "mappin.and.ellipse")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
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
                    ContentUnavailableView("No markers yet", systemImage: "mappin.slash", description: Text("Close this screen and tap a visible surface in AR to place one."))
                } else {
                    ForEach(store.markers) { marker in
                        Button {
                            controller.selectMarker(marker)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(marker.name)
                                    Text(marker.createdAt, format: .dateTime.hour().minute().day().month())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if marker.id == store.selectedMarkerID {
                                    Image(systemName: "checkmark.circle.fill")
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
            .navigationTitle("Saved Markers")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
