import Foundation
import simd

struct SavedMarker: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var x: Float
    var y: Float
    var z: Float
    var createdAt: Date

    init(id: UUID = UUID(), name: String, position: SIMD3<Float>, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.x = position.x
        self.y = position.y
        self.z = position.z
        self.createdAt = createdAt
    }

    var position: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}
