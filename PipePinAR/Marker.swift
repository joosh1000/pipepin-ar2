import Foundation
import simd
import SwiftUI
import UIKit

enum ServiceType: String, Codable, CaseIterable, Identifiable {
    case pipe
    case cable
    case joist
    case duct
    case drain
    case gas
    case structure
    case fixing
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pipe: return "Pipe"
        case .cable: return "Cable"
        case .joist: return "Joist"
        case .duct: return "Duct"
        case .drain: return "Drain"
        case .gas: return "Gas"
        case .structure: return "Structure"
        case .fixing: return "Fixing"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .pipe: return "line.diagonal"
        case .cable: return "cable.connector"
        case .joist: return "rectangle.split.3x1"
        case .duct: return "wind"
        case .drain: return "drop.fill"
        case .gas: return "flame.fill"
        case .structure: return "building.columns.fill"
        case .fixing: return "scope"
        case .other: return "mappin"
        }
    }

    var uiColor: UIColor {
        switch self {
        case .pipe:
            return UIColor(red: 0.00, green: 0.92, blue: 1.00, alpha: 1.00)
        case .cable:
            return UIColor(red: 1.00, green: 0.38, blue: 0.06, alpha: 1.00)
        case .joist:
            return UIColor(red: 1.00, green: 0.67, blue: 0.16, alpha: 1.00)
        case .duct:
            return UIColor(red: 0.05, green: 0.95, blue: 0.67, alpha: 1.00)
        case .drain:
            return UIColor(red: 0.16, green: 0.48, blue: 1.00, alpha: 1.00)
        case .gas:
            return UIColor(red: 1.00, green: 0.91, blue: 0.08, alpha: 1.00)
        case .structure:
            return UIColor(red: 0.68, green: 0.34, blue: 1.00, alpha: 1.00)
        case .fixing:
            return UIColor(red: 1.00, green: 0.16, blue: 0.62, alpha: 1.00)
        case .other:
            return UIColor(white: 0.94, alpha: 1.00)
        }
    }

    var tint: Color { Color(uiColor: uiColor) }
}

struct SavedMarker: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var serviceType: ServiceType
    var x: Float
    var y: Float
    var z: Float
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        serviceType: ServiceType = .other,
        position: SIMD3<Float>,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.serviceType = serviceType
        self.x = position.x
        self.y = position.y
        self.z = position.z
        self.createdAt = createdAt
    }

    var position: SIMD3<Float> { SIMD3<Float>(x, y, z) }

    enum CodingKeys: String, CodingKey {
        case id, name, serviceType, x, y, z, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        serviceType = try container.decodeIfPresent(ServiceType.self, forKey: .serviceType) ?? .other
        x = try container.decode(Float.self, forKey: .x)
        y = try container.decode(Float.self, forKey: .y)
        z = try container.decode(Float.self, forKey: .z)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
