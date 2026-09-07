import Foundation

struct SiteRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var address: String
    var reference: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        address: String = "",
        reference: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.reference = reference
        self.createdAt = createdAt
    }
}
