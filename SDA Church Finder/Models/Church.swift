import Foundation
import SwiftData
import CoreLocation

struct Church: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var address: String
    var city: String
    var state: String
    var zipCode: String
    var country: String
    var latitude: Double
    var longitude: Double
    var phone: String?
    var website: String?
    var email: String?
    var pastorName: String?
    var languages: [String]
    var sabbathServiceTime: String?
    var weeklyServices: [ServiceTime]
    var isAccessible: Bool
    var photoURLs: [String]
    var directoryAttribution: DirectoryAttribution? = nil
    var conference: String? = nil
    var eventsURL: String? = nil
    var calendarFeedURL: String? = nil
    var givingURL: String? = nil
    var isLikelyInactive: Bool? = false
    var operationalNotes: String? = nil
    var lastUpdated: Date
    
    var isInactive: Bool {
        isLikelyInactive ?? false
    }
    
    var isFavorite: Bool {
        FavoritesManager.shared.isFavorite(id)
    }
    
    init(
        id: String,
        name: String,
        address: String,
        city: String,
        state: String,
        zipCode: String,
        country: String,
        latitude: Double,
        longitude: Double,
        phone: String? = nil,
        website: String? = nil,
        email: String? = nil,
        pastorName: String? = nil,
        languages: [String] = [],
        sabbathServiceTime: String? = nil,
        weeklyServices: [ServiceTime] = [],
        isAccessible: Bool = false,
        photoURLs: [String] = [],
        isLikelyInactive: Bool? = false,
        operationalNotes: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.city = city
        self.state = state
        self.zipCode = zipCode
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.phone = phone
        self.website = website
        self.email = email
        self.pastorName = pastorName
        self.languages = languages
        self.sabbathServiceTime = sabbathServiceTime
        self.weeklyServices = weeklyServices
        self.isAccessible = isAccessible
        self.photoURLs = photoURLs
        self.isLikelyInactive = isLikelyInactive
        self.operationalNotes = operationalNotes
        self.lastUpdated = lastUpdated
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var fullAddress: String {
        "\(address), \(city), \(state) \(zipCode)"
    }

    var displayName: String {
        if isGenericName {
            if !city.isEmpty {
                return "\(city) SDA Church"
            }
        }
        return name
    }

    var isGenericName: Bool {
        Self.isGenericCongregationName(name)
    }

    static func isGenericCongregationName(_ testName: String) -> Bool {
        let clean = testName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let genericSet: Set<String> = [
            "seventh-day adventist church",
            "seventh day adventist church",
            "seventh-day adventist",
            "seventh day adventist",
            "seventh-day adventists",
            "seventh day adventists",
            "seventh-day adventist congregation",
            "seventh day adventist congregation",
            "seventh-day adventist church group",
            "seventh day adventist church group",
            "seventh-day adventist company",
            "seventh day adventist company",
            "sda church",
            "sda",
            "adventist church",
            "adventist",
            "adventist congregation",
            "iglesia adventista del septimo dia",
            "iglesia adventista del séptimo día",
            "iglesia adventista",
            "igreja adventista do setimo dia",
            "igreja adventista do sétimo dia",
            "igreja adventista",
            "eglise adventiste du septieme jour",
            "église adventiste du septième jour",
            "eglise adventiste"
        ]
        return genericSet.contains(clean)
    }
    
    func distance(from location: CLLocation) -> Double {
        let churchLocation = CLLocation(latitude: latitude, longitude: longitude)
        return location.distance(from: churchLocation)
    }
}

struct ServiceTime: Codable, Hashable {
    var day: String
    var time: String
    var type: String
}
