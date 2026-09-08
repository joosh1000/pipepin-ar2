import Foundation

@MainActor
final class SiteStore: ObservableObject {
    @Published private(set) var sites: [SiteRecord] = []

    private let storageKey = "pipepin.sites.v1"

    init() {
        load()
    }

    func add(name: String, address: String, reference: String) -> SiteRecord {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let site = SiteRecord(
            name: cleanName.isEmpty ? "Untitled Site" : cleanName,
            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
            reference: reference.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        sites.insert(site, at: 0)
        save()
        return site
    }

    func delete(_ site: SiteRecord) {
        sites.removeAll { $0.id == site.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sites) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SiteRecord].self, from: data) else { return }
        sites = decoded
    }
}
