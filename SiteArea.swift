import Foundation

struct SiteArea: Identifiable, Codable, Equatable {
    var id: UUID
    var siteID: UUID
    var floorName: String
    var roomName: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        siteID: UUID,
        floorName: String,
        roomName: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.siteID = siteID
        self.floorName = floorName
        self.roomName = roomName
        self.createdAt = createdAt
    }

    var displayName: String {
        roomName.isEmpty ? floorName : "\(floorName) · \(roomName)"
    }
}
