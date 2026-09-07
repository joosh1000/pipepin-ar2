import Foundation

@MainActor
final class MarkerStore: ObservableObject {
    @Published var markers: [SavedMarker] = []
    @Published var selectedMarkerID: UUID?

    private let storageKey = "pipepin.saved-markers.v1"

    init() { load() }

    var selectedMarker: SavedMarker? {
        guard let selectedMarkerID else { return nil }
        return markers.first(where: { $0.id == selectedMarkerID })
    }

    func add(_ marker: SavedMarker) {
        markers.append(marker)
        selectedMarkerID = marker.id
        save()
    }

    func delete(at offsets: IndexSet) {
        let deleted = offsets.map { markers[$0].id }
        markers.remove(atOffsets: offsets)
        if let selectedMarkerID, deleted.contains(selectedMarkerID) {
            self.selectedMarkerID = markers.first?.id
        }
        save()
    }

    func clear() {
        markers.removeAll()
        selectedMarkerID = nil
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
        selectedMarkerID = decoded.first?.id
    }
}
