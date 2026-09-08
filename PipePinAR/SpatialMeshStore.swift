import ARKit
import Foundation

struct SpatialMeshMetadata: Codable, Equatable {
    let savedAt: Date
    let anchorCount: Int
    let vertexCount: Int
    let faceCount: Int
}

enum SpatialMeshStore {
    static func save(meshAnchors: [ARMeshAnchor], siteID: UUID) throws -> SpatialMeshMetadata {
        let folder = folderURL()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)

        // ARMeshAnchor and ARMeshGeometry both support secure coding. Keeping this raw
        // snapshot gives PipePin a real 3D site model to process/export in later builds,
        // while ARWorldMap remains the relocalisation data for the live AR session.
        let data = try NSKeyedArchiver.archivedData(withRootObject: meshAnchors, requiringSecureCoding: true)
        try data.write(to: meshURL(siteID: siteID), options: .atomic)

        let metadata = SpatialMeshMetadata(
            savedAt: Date(),
            anchorCount: meshAnchors.count,
            vertexCount: meshAnchors.reduce(0) { $0 + $1.geometry.vertices.count },
            faceCount: meshAnchors.reduce(0) { $0 + $1.geometry.faces.count }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(metadata).write(to: metadataURL(siteID: siteID), options: .atomic)
        return metadata
    }

    static func metadata(siteID: UUID) -> SpatialMeshMetadata? {
        guard let data = try? Data(contentsOf: metadataURL(siteID: siteID)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SpatialMeshMetadata.self, from: data)
    }

    static func exists(siteID: UUID) -> Bool {
        FileManager.default.fileExists(atPath: meshURL(siteID: siteID).path)
    }

    static func remove(siteID: UUID) {
        try? FileManager.default.removeItem(at: meshURL(siteID: siteID))
        try? FileManager.default.removeItem(at: metadataURL(siteID: siteID))
    }

    private static func folderURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PipePinSpatialMeshes", isDirectory: true)
    }

    private static func meshURL(siteID: UUID) -> URL {
        folderURL().appendingPathComponent("\(siteID.uuidString).mesharchive")
    }

    private static func metadataURL(siteID: UUID) -> URL {
        folderURL().appendingPathComponent("\(siteID.uuidString).json")
    }
}
