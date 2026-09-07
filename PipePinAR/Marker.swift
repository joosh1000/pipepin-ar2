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
            return UIColor(red: 0.00, green: 0.95, blue: 1.00, alpha: 1.00)
        case .cable:
            return UIColor(red: 1.00, green: 0.32, blue: 0.02, alpha: 1.00)
        case .joist:
            return UIColor(red: 1.00, green: 0.70, blue: 0.08, alpha: 1.00)
        case .duct:
            return UIColor(red: 0.00, green: 1.00, blue: 0.62, alpha: 1.00)
        case .drain:
            return UIColor(red: 0.08, green: 0.44, blue: 1.00, alpha: 1.00)
        case .gas:
            return UIColor(red: 1.00, green: 0.90, blue: 0.00, alpha: 1.00)
        case .structure:
            return UIColor(red: 0.70, green: 0.28, blue: 1.00, alpha: 1.00)
        case .fixing:
            return UIColor(red: 1.00, green: 0.10, blue: 0.60, alpha: 1.00)
        case .other:
            return UIColor(white: 0.98, alpha: 1.00)
        }
    }

    var tint: Color { Color(uiColor: uiColor) }
}

enum ServiceOrientation: String, Codable, CaseIterable, Identifiable {
    case vertical
    case horizontal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vertical: return "Vertical"
        case .horizontal: return "Horizontal"
        }
    }

    var systemImage: String {
        switch self {
        case .vertical: return "arrow.up.and.down"
        case .horizontal: return "arrow.left.and.right"
        }
    }
}

enum FlowDirection: String, Codable, CaseIterable, Identifiable {
    case none
    case forward
    case reverse

    var id: String { rawValue }

    func title(for orientation: ServiceOrientation) -> String {
        switch (self, orientation) {
        case (.none, _): return "No arrows"
        case (.forward, .vertical): return "Up"
        case (.reverse, .vertical): return "Down"
        case (.forward, .horizontal): return "Forward"
        case (.reverse, .horizontal): return "Reverse"
        }
    }

    func systemImage(for orientation: ServiceOrientation) -> String {
        switch (self, orientation) {
        case (.none, _): return "minus"
        case (.forward, .vertical): return "arrow.up"
        case (.reverse, .vertical): return "arrow.down"
        case (.forward, .horizontal): return "arrow.right"
        case (.reverse, .horizontal): return "arrow.left"
        }
    }
}

struct SavedMarker: Identifiable, Codable, Equatable {
    var id: UUID
    var siteID: UUID?
    var name: String
    var serviceType: ServiceType
    var orientation: ServiceOrientation
    var flowDirection: FlowDirection
    var beamYaw: Float
    var x: Float
    var y: Float
    var z: Float
    var createdAt: Date

    init(
        id: UUID = UUID(),
        siteID: UUID?,
        name: String,
        serviceType: ServiceType = .other,
        orientation: ServiceOrientation = .vertical,
        flowDirection: FlowDirection = .none,
        beamYaw: Float = 0,
        position: SIMD3<Float>,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.siteID = siteID
        self.name = name
        self.serviceType = serviceType
        self.orientation = orientation
        self.flowDirection = flowDirection
        self.beamYaw = beamYaw
        self.x = position.x
        self.y = position.y
        self.z = position.z
        self.createdAt = createdAt
    }

    var position: SIMD3<Float> { SIMD3<Float>(x, y, z) }

    enum CodingKeys: String, CodingKey {
        case id, siteID, name, serviceType, orientation, flowDirection, beamYaw, x, y, z, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        siteID = try container.decodeIfPresent(UUID.self, forKey: .siteID)
        name = try container.decode(String.self, forKey: .name)
        serviceType = try container.decodeIfPresent(ServiceType.self, forKey: .serviceType) ?? .other
        orientation = try container.decodeIfPresent(ServiceOrientation.self, forKey: .orientation) ?? .vertical
        flowDirection = try container.decodeIfPresent(FlowDirection.self, forKey: .flowDirection) ?? .none
        beamYaw = try container.decodeIfPresent(Float.self, forKey: .beamYaw) ?? 0
        x = try container.decode(Float.self, forKey: .x)
        y = try container.decode(Float.self, forKey: .y)
        z = try container.decode(Float.self, forKey: .z)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
