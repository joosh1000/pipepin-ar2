import Foundation

@MainActor
final class SiteAreaStore: ObservableObject {
    @Published private(set) var areas: [SiteArea] = []
    private let storageKey = "pipepin.site-areas.v1"

    init() { load() }

    func areas(for siteID: UUID) -> [SiteArea] {
        areas.filter { $0.siteID == siteID }
    }

    func ensureDefault(for siteID: UUID) -> SiteArea {
        if let first = areas(for: siteID).first { return first }
        let area = SiteArea(siteID: siteID, floorName: "Ground Floor", roomName: "Unassigned Room")
        areas.append(area)
        save()
        return area
    }

    func add(siteID: UUID, floorName: String, roomName: String) -> SiteArea {
        let cleanFloor = floorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRoom = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let area = SiteArea(
            siteID: siteID,
            floorName: cleanFloor.isEmpty ? "Ground Floor" : cleanFloor,
            roomName: cleanRoom.isEmpty ? "Unassigned Room" : cleanRoom
        )
        areas.append(area)
        save()
        return area
    }

    func delete(_ area: SiteArea) {
        areas.removeAll { $0.id == area.id }
        save()
    }

    func deleteAreas(for siteID: UUID) {
        areas.removeAll { $0.siteID == siteID }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(areas) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SiteArea].self, from: data) else { return }
        areas = decoded
    }
}
