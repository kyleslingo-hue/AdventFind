import Foundation

struct ChurchURLHelper {
    static func generateSearchURL(for church: Church) -> URL? {
        let searchQuery = buildSearchQuery(for: church)
        return googleSearchURL(for: searchQuery)
    }
    
    static func generateMapsSearchURL(for church: Church) -> URL? {
        let searchQuery = "\(church.name) \(church.address) \(church.city) \(church.state)"
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://www.google.com/maps/search/?api=1&query=\(encodedQuery)"
        return URL(string: urlString)
    }
    
    static func generateDirectionsURL(for church: Church) -> URL? {
        let destination = "\(church.latitude),\(church.longitude)"
        let encodedDestination = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://www.google.com/maps/dir/?api=1&destination=\(encodedDestination)"
        return URL(string: urlString)
    }
    
    static func generateWebsiteSearchURL(for church: Church) -> URL? {
        let searchQuery = "\(church.name) \(church.city) \(church.state) SDA church website"
        return googleSearchURL(for: searchQuery)
    }

    static func generateEventsSearchURL(churchName: String, city: String, state: String) -> URL? {
        let searchQuery = [churchName, city, state, "Seventh-day Adventist church events calendar"]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return googleSearchURL(for: searchQuery)
    }
    
    private static func googleSearchURL(for query: String) -> URL? {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.google.com/search?q=\(encodedQuery)")
    }
    
    private static func buildSearchQuery(for church: Church) -> String {
        let genericNames: Set<String> = [
            "seventh-day adventist church",
            "seventh day adventist church",
            "sda church",
            "adventist church"
        ]
        
        var components: [String] = []
        if genericNames.contains(church.name.lowercased()) {
            if !church.address.isEmpty { components.append(church.address) }
            if !church.city.isEmpty { components.append(church.city) }
            if !church.state.isEmpty { components.append(church.state) }
            components.append("Seventh-day Adventist Church website")
        } else {
            components.append(church.name)
            if !church.city.isEmpty { components.append(church.city) }
            if !church.state.isEmpty { components.append(church.state) }
            components.append("website")
        }
        return components.joined(separator: " ")
    }
}
