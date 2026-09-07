import Foundation
import SwiftUI
import UIKit
import simd

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
        case .pipe: return "pipe.and.drop"
        case .cable: return "cable.connector"
        case .joist: return "rectangle.split.3x1"
        case .duct: return "wind"
        case .drain: return "drop.triangle"
        case .gas: return "flame"
        case .structure: return "building.columns"
        case .fixing: return "scope"
        case .other: return "mappin"
        }
    }

    var tint: Color {
        switch self {
        case .pipe: return .cyan
        case .cable: return .orange
        case .joist: return .brown
        case .duct: return .mint
        case .drain: return .blue
        case .gas: return .yellow
        case .structure: return .purple
        case .fixing: return .pink
        case .other: return .gray
        }
    }

    var uiColor: UIColor {
        UIColor(tint)
    }
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
