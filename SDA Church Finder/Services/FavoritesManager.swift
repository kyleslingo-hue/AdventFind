import Foundation

class FavoritesManager {
    static let shared = FavoritesManager()
    
    private let favoritesKey = "favoriteChurchIds"
    private let recordsKey = "savedChurchRecords"
    private let defaults = UserDefaults.standard
    private var cachedFavoriteIds: Set<String>?
    private var cachedRecords: [Church]?
    
    private init() {}
    
    func getFavoriteIds() -> Set<String> {
        if let cachedFavoriteIds {
            return cachedFavoriteIds
        }
        if let array = defaults.array(forKey: favoritesKey) as? [String] {
            let set = Set(array)
            cachedFavoriteIds = set
            return set
        }
        return []
    }
    
    func isFavorite(_ churchId: String) -> Bool {
        getFavoriteIds().contains(churchId)
    }
    
    func toggleFavorite(_ churchId: String) {
        var favorites = getFavoriteIds()
        if favorites.contains(churchId) {
            favorites.remove(churchId)
        } else {
            favorites.insert(churchId)
        }
        saveFavorites(favorites)
    }
    
    func addFavorite(_ churchId: String) {
        var favorites = getFavoriteIds()
        favorites.insert(churchId)
        saveFavorites(favorites)
    }
    
    func removeFavorite(_ churchId: String) {
        var favorites = getFavoriteIds()
        favorites.remove(churchId)
        saveFavorites(favorites)
    }
    
    func savedChurches() -> [Church] {
        let favoriteIds = getFavoriteIds()
        if let cachedRecords {
            return cachedRecords.filter { favoriteIds.contains($0.id) }
        }
        guard let data = defaults.data(forKey: recordsKey),
              let records = try? JSONDecoder().decode([Church].self, from: data) else {
            cachedRecords = []
            return []
        }
        // Older saved records assumed English and inferred languages from nationality.
        let updated = records.filter { favoriteIds.contains($0.id) }.map { church in
            var church = church
            church.languages = ChurchLanguage.indicated(in: church.name)
            return church
        }
        let enriched = ChurchDirectory.shared.enriching(updated)
        cachedRecords = enriched
        return enriched
    }

    func toggleFavorite(_ church: Church) {
        var records = savedChurches()
        if isFavorite(church.id) {
            removeFavorite(church.id)
            records.removeAll { $0.id == church.id }
        } else {
            addFavorite(church.id)
            records.removeAll { $0.id == church.id }
            let enriched = ChurchDirectory.shared.enriching([church]).first ?? church
            records.append(enriched)
        }
        cachedRecords = records
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: recordsKey)
        }
    }

    func updateFavorite(_ church: Church) {
        var records = savedChurches()
        if let idx = records.firstIndex(where: { $0.id == church.id }) {
            records[idx] = church
            cachedRecords = records
            if let data = try? JSONEncoder().encode(records) {
                defaults.set(data, forKey: recordsKey)
            }
        }
    }

    private func saveFavorites(_ favorites: Set<String>) {
        cachedFavoriteIds = favorites
        defaults.set(Array(favorites), forKey: favoritesKey)
        if let cached = cachedRecords {
            cachedRecords = cached.filter { favorites.contains($0.id) }
        }
    }
}
