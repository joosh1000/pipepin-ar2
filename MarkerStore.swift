import Foundation
import SwiftUI
import simd

@MainActor
final class MarkerStore: ObservableObject {
    @Published var markers: [SavedMarker] = []
    @Published var selectedMarkerID: UUID?
    @Published var activeSiteID: UUID?

    private let storageKey = "pipepin.saved-markers.v1"

    init() { load() }

    var visibleMarkers: [SavedMarker] {
        guard let activeSiteID else { return [] }
        return markers.filter { $0.siteID == activeSiteID }
    }

    var selectedMarker: SavedMarker? {
        guard let selectedMarkerID else { return nil }
        return visibleMarkers.first(where: { $0.id == selectedMarkerID })
    }

    func activate(siteID: UUID) {
        activeSiteID = siteID

        // 0.3.x did not have sites. Treat those test pins as belonging to the first
        // site the user opens so existing prototype data is not silently lost.
        var migrated = false
        for index in markers.indices where markers[index].siteID == nil {
            markers[index].siteID = siteID
            migrated = true
        }
        if migrated { save() }

        // Entering a site starts in recording mode. A locate target is only shown
        // after the user explicitly chooses a service from Pins.
        selectedMarkerID = nil
    }

    func add(_ marker: SavedMarker) {
        markers.append(marker)
        // Do not auto-select newly recorded pins. Selection is reserved for an
        // explicit Locate action from the Pins list.
        selectedMarkerID = nil
        save()
    }

    func deleteVisible(at offsets: IndexSet) {
        let current = visibleMarkers
        let ids = offsets.compactMap { index in
            current.indices.contains(index) ? current[index].id : nil
        }
        markers.removeAll { ids.contains($0.id) }
        if let selectedMarkerID, ids.contains(selectedMarkerID) {
            self.selectedMarkerID = nil
        }
        save()
    }

    func deleteLastVisible() {
        guard let last = visibleMarkers.last else { return }
        markers.removeAll { $0.id == last.id }
        if selectedMarkerID == last.id {
            selectedMarkerID = nil
        }
        save()
    }


    func updatePosition(markerID: UUID, position: SIMD3<Float>) {
        guard let index = markers.firstIndex(where: { $0.id == markerID }) else { return }
        markers[index].x = position.x
        markers[index].y = position.y
        markers[index].z = position.z
        save()
    }

    func count(for siteID: UUID) -> Int {
        markers.filter { $0.siteID == siteID }.count
    }

    func deleteMarkers(for siteID: UUID) {
        markers.removeAll { $0.siteID == siteID }
        if activeSiteID == siteID {
            selectedMarkerID = nil
        }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(markers) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SavedMarker].self, from: data) else { return }
        markers = decoded
        selectedMarkerID = nil
    }
}
