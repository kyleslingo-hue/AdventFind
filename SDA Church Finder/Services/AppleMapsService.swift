import Foundation
import MapKit
import CoreLocation

class AppleMapsService {
    static let shared = AppleMapsService()
    
    private init() {}
    
    func searchChurches(near location: CLLocation, radius: Double = 50000, specificQueries: [String] = []) async throws -> [Church] {
        var queries = [
            "Seventh-day Adventist Church",
            "SDA Church",
            "Seventh Day Adventist",
            "Iglesia Adventista"
        ]
        if !specificQueries.isEmpty {
            queries = specificQueries + queries
        }
        
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )
        
        var allMapItems: [MKMapItem] = []
        await withTaskGroup(of: [MKMapItem].self) { group in
            for query in queries {
                group.addTask {
                    let searchRequest = MKLocalSearch.Request()
                    searchRequest.naturalLanguageQuery = query
                    searchRequest.region = region
                    let search = MKLocalSearch(request: searchRequest)
                    do {
                        let response = try await search.start()
                        return response.mapItems
                    } catch {
                        return []
                    }
                }
            }
            for await items in group {
                allMapItems.append(contentsOf: items)
            }
        }
        
        var churches: [Church] = []
        var seenIDs = Set<String>()
        
        for mapItem in allMapItems {
            guard let name = mapItem.name else {
                continue
            }
            
            let lowercasedName = name.lowercased()
            let nonChurchKeywords = [
                "school", "academy", "elementary", "university", "college", "institute", "high school", "daycare", "child care", "early childhood", "preschool",
                "conference office", "association office", "union office", "division office", "administrative office",
                "book center", "adventist book center", "abc store", "bookstore", "thrift store", "thrift shop",
                "campground", "youth camp", "cemetery", "graveyard",
                "permanently closed", "temporarily closed", "defunct", "former site"
            ]
            if nonChurchKeywords.contains(where: { lowercasedName.contains($0) }) {
                continue
            }

            let itemLocation = mapItem.location
            let coordinate = itemLocation.coordinate
            let distance = location.distance(from: itemLocation)
            
            if distance > radius {
                continue
            }
            
            let itemID = mapItem.identifier?.rawValue ?? "\(coordinate.latitude),\(coordinate.longitude)"
            if seenIDs.contains(itemID) {
                continue
            }
            
            if let existingIndex = churches.firstIndex(where: {
                CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: itemLocation) < 150
            }) {
                let existing = churches[existingIndex]
                if existing.isGenericName && !Church.isGenericCongregationName(name) {
                    churches[existingIndex].name = name
                }
                if churches[existingIndex].website == nil, let url = mapItem.url?.absoluteString {
                    churches[existingIndex].website = url
                }
                if churches[existingIndex].phone == nil, let phone = mapItem.phoneNumber {
                    churches[existingIndex].phone = phone
                }
                seenIDs.insert(itemID)
                continue
            }
            
            let addressComponents = parseAddress(from: mapItem)
            
            let church = Church(
                id: mapItem.identifier?.rawValue ?? UUID().uuidString,
                name: name,
                address: addressComponents.street,
                city: addressComponents.city,
                state: addressComponents.state,
                zipCode: addressComponents.zipCode,
                country: addressComponents.country,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                phone: mapItem.phoneNumber,
                website: mapItem.url?.absoluteString,
                email: nil,
                pastorName: nil,
                languages: detectLanguages(from: name),
                sabbathServiceTime: nil,
                weeklyServices: [],
                isAccessible: false,
                photoURLs: []
            )
            
            let isDirMatch = ChurchDirectory.shared.match(for: church) != nil
            guard Self.isAdventistAffiliation(name: name, website: mapItem.url?.absoluteString, isDirectoryMatched: isDirMatch) else {
                continue
            }
            
            seenIDs.insert(itemID)
            churches.append(church)
        }
        
        var enriched = ChurchDirectory.shared.enriching(churches)
        
        let directoryChurches = ChurchDirectory.shared.churches(near: location, withinMeters: radius)
        for dirChurch in directoryChurches {
            let dirLoc = CLLocation(latitude: dirChurch.latitude, longitude: dirChurch.longitude)
            let isDuplicate = enriched.contains { existing in
                existing.id == dirChurch.id ||
                CLLocation(latitude: existing.latitude, longitude: existing.longitude).distance(from: dirLoc) < 150 ||
                (ChurchDirectory.normalizedStreet(existing.address) == ChurchDirectory.normalizedStreet(dirChurch.address) &&
                 existing.city.localizedCaseInsensitiveCompare(dirChurch.city) == .orderedSame)
            }
            if !isDuplicate {
                enriched.append(dirChurch)
            }
        }
        
        let resolved = disambiguateGenericChurches(enriched)
        return resolved.sorted { church1, church2 in
            church1.distance(from: location) < church2.distance(from: location)
        }
    }
    
    func searchChurches(zipCode: String, radius: Double = 50000) async throws -> [Church] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(zipCode), USA"
        request.resultTypes = .address
        
        let search = MKLocalSearch(request: request)
        let response: MKLocalSearch.Response
        do {
            response = try await search.start()
        } catch {
            throw MapError.searchFailed
        }
        
        guard let location = response.mapItems.first?.location else {
            throw MapError.locationNotFound
        }
        
        return try await searchChurches(near: location, radius: radius)
    }
    
    func searchChurches(city: String, state: String, radius: Double = 50000) async throws -> [Church] {
        let addressString = "\(city), \(state)"
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = addressString
        
        let search = MKLocalSearch(request: request)
        let response: MKLocalSearch.Response
        do {
            response = try await search.start()
        } catch {
            throw MapError.searchFailed
        }
        
        guard let location = response.mapItems.first?.location else {
            throw MapError.locationNotFound
        }
        
        let specificQueries = [
            "\(city) Seventh-day Adventist Church",
            "Seventh-day Adventist Church \(city)",
            "\(city) SDA Church",
            "SDA Church \(city)"
        ]
        return try await searchChurches(near: location, radius: radius, specificQueries: specificQueries)
    }
    
    private func parseAddress(from mapItem: MKMapItem) -> (street: String, city: String, state: String, zipCode: String, country: String) {
        let representations = mapItem.addressRepresentations
        let fullAddress = mapItem.address?.fullAddress
            ?? representations?.fullAddress(includingRegion: true, singleLine: true)
            ?? ""

        // MapKit provides formatted addresses; detect postal fields on a best-effort basis.
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue)
        let components = detector?.firstMatch(
            in: fullAddress,
            range: NSRange(fullAddress.startIndex..., in: fullAddress)
        )?.addressComponents

        let street = components?[.street] ?? fullAddress
        let city = representations?.cityName ?? components?[.city] ?? ""
        let state = components?[.state] ?? ""
        let zipCode = components?[.zip] ?? ""
        let country = representations?.regionName ?? components?[.country] ?? ""

        return (street, city, state, zipCode, country.isEmpty ? "United States" : country)
    }
    
    private func detectLanguages(from churchName: String) -> [String] {
        ChurchLanguage.indicated(in: churchName)
    }
    
    private func generateAdventistDirectoryURL(churchName: String, street: String, city: String, state: String, zipCode: String) -> String {
        // Using adventistlocator.org (official locator) to avoid Cloudflare issues
        // Include full address for more precise results
        let searchQuery = "\(churchName) \(street) \(city) \(state) \(zipCode)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "https://www.adventistlocator.org/?search=\(searchQuery)"
    }

    private func disambiguateGenericChurches(_ churches: [Church]) -> [Church] {
        var genericCountByCity: [String: Int] = [:]
        for church in churches where church.isGenericName {
            let key = church.city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !key.isEmpty {
                genericCountByCity[key, default: 0] += 1
            }
        }

        return churches.map { church in
            guard church.isGenericName else { return church }

            var resolved = church

            // Step 1: Attempt congregation name deduction from website domain
            if let website = church.website, let deduced = Self.deduceCongregationName(fromWebsite: website, city: church.city) {
                resolved.name = deduced
                return resolved
            }

            // Step 2: Disambiguate using city and street
            let cityKey = church.city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !church.city.isEmpty else { return resolved }

            let hasMultipleInCity = (genericCountByCity[cityKey] ?? 0) > 1
            let streetLabel = Self.extractStreetLabel(from: church.address)

            if hasMultipleInCity && !streetLabel.isEmpty {
                resolved.name = "\(church.city) SDA Church (\(streetLabel))"
            } else {
                resolved.name = "\(church.city) SDA Church"
            }

            return resolved
        }
    }

    static func deduceCongregationName(fromWebsite websiteString: String?, city: String = "") -> String? {
        guard let websiteString, let url = URL(string: websiteString), let rawHost = url.host?.lowercased() else {
            return nil
        }
        var host = rawHost
        if host.hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }

        // Subdomain on adventistchurch.org (e.g. amesburyma.adventistchurch.org -> Amesbury)
        if host.hasSuffix(".adventistchurch.org") {
            var slug = String(host.dropLast(".adventistchurch.org".count))
            let usStates = ["al","ak","az","ar","ca","co","ct","de","fl","ga","hi","id","il","in","ia","ks","ky","la","me","md","ma","mi","mn","ms","mo","mt","ne","nv","nh","nj","nm","ny","nc","nd","oh","ok","or","pa","ri","sc","sd","tn","tx","ut","vt","va","wa","wv","wi","wy"]
            for state in usStates {
                if slug.hasSuffix(state) && slug.count > state.count + 2 {
                    slug = String(slug.dropLast(state.count))
                    break
                }
            }
            let formatted = slug.replacingOccurrences(of: "-", with: " ").capitalized
            if !formatted.isEmpty && !Church.isGenericCongregationName(formatted) {
                return formatted.localizedCaseInsensitiveContains("church") ? formatted : "\(formatted) SDA Church"
            }
        }

        // Check standalone domains ending in sda.church, sda.org, church.org, etc.
        let churchSuffixes = [".adventist.place", ".sda.church", ".sda.org", "sda.org", "church.org", ".church"]
        for suffix in churchSuffixes {
            if host.hasSuffix(suffix) {
                var slug = String(host.dropLast(suffix.count))
                if slug.hasSuffix(".") { slug = String(slug.dropLast()) }
                if slug.hasSuffix("sda") && slug.count > 3 { slug = String(slug.dropLast(3)) }
                if slug.hasSuffix("church") && slug.count > 6 { slug = String(slug.dropLast(6)) }
                let formatted = slug.replacingOccurrences(of: "-", with: " ").capitalized
                if !formatted.isEmpty && !Church.isGenericCongregationName(formatted) && formatted.count >= 3 {
                    return formatted.localizedCaseInsensitiveContains("church") ? formatted : "\(formatted) SDA Church"
                }
            }
        }

        return nil
    }

    static func extractStreetLabel(from address: String) -> String {
        let firstLine = address.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? address
        let parts = firstLine.components(separatedBy: " ")
        if let first = parts.first, first.allSatisfy({ $0.isNumber || $0 == "-" || $0 == "/" }), parts.count > 1 {
            return parts.dropFirst().joined(separator: " ")
        }
        return firstLine
    }

    static func isAdventistAffiliation(
        name: String,
        website: String? = nil,
        isDirectoryMatched: Bool = false
    ) -> Bool {
        if isDirectoryMatched { return true }
        
        let lowerName = name.lowercased()
        
        // 1. Explicitly filter out non-Adventist denominations / Sunday churches
        let nonAdventistTerms = [
            "baptist", "methodist", "presbyterian", "episcopal", "catholic",
            "lutheran", "pentecostal", "anglican", "mormon", "latter-day",
            "jehovah", "kingdom hall", "orthodox", "nazarene",
            "assembly of god", "assemblies of god", "church of christ",
            "coptic", "church of god in christ", "ame zion", "a.m.e.",
            "mennonite", "congregational", "evangelical covenant",
            "salvation army", "foursquare"
        ]
        if nonAdventistTerms.contains(where: { lowerName.contains($0) }) {
            return false
        }
        
        // 2. Positive Adventist indicators in the congregation name
        let sdaPatterns = [
            "adventist", "adventiste", "adventista",
            "seventh-day", "seventh day", "7th day",
            "séptimo día", "septimo dia", "septième jour", "septieme jour"
        ]
        if sdaPatterns.contains(where: { lowerName.contains($0) }) {
            return true
        }
        
        // Match word-boundary "sda" (e.g. "Meriden SDA Church", "Grace SDA Church")
        if let regex = try? NSRegularExpression(pattern: #"\b(sda|7th)\b"#, options: [.caseInsensitive]),
           regex.firstMatch(in: lowerName, range: NSRange(location: 0, length: (lowerName as NSString).length)) != nil {
            return true
        }
        
        // 3. Positive Adventist indicators in website domain
        if let website = website?.lowercased() {
            if website.contains("adventist") ||
               website.contains("sda.org") ||
               website.contains("sda.church") ||
               website.contains(".adventistchurch.org") ||
               website.contains(".adventist.place") {
                return true
            }
        }
        
        return false
    }
}

enum MapError: Error, LocalizedError {
    case locationNotFound
    case searchFailed
    
    var errorDescription: String? {
        switch self {
        case .locationNotFound:
            return "Location not found"
        case .searchFailed:
            return "Search failed"
        }
    }
}
