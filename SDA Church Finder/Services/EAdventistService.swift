import Foundation
import CoreLocation
import OSLog

private let logger = Logger(subsystem: "com.sdachurchfinder.app", category: "EAdventistService")

private class CachedChurches {
    let churches: [Church]
    let timestamp: Date
    
    init(churches: [Church], timestamp: Date) {
        self.churches = churches
        self.timestamp = timestamp
    }
}

class EAdventistService {
    static let shared = EAdventistService()
    
    private let baseURL = "https://www.adventistlocator.org"
    private let useMockData = false
    private let cache = NSCache<NSString, CachedChurches>()
    private let cacheExpirationInterval: TimeInterval = 3600
    
    private init() {
        cache.countLimit = 10
        cache.totalCostLimit = 1024 * 1024 * 2
        cache.evictsObjectsWithDiscardedContent = true
    }
    
    deinit {
        cache.removeAllObjects()
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
    
    func searchChurches(near location: CLLocation, radius: Double = 50000) async throws -> [Church] {
        let cacheKey = "\(location.coordinate.latitude),\(location.coordinate.longitude),\(radius)" as NSString
        
        if let cached = cache.object(forKey: cacheKey),
           Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval {
            return cached.churches
        }
        
        let churches = try await fetchChurchesFromAPI(latitude: location.coordinate.latitude, 
                                                       longitude: location.coordinate.longitude, 
                                                       radius: radius)
        
        cache.setObject(CachedChurches(churches: churches, timestamp: Date()), forKey: cacheKey)
        return churches
    }
    
    func searchChurches(zipCode: String, radius: Double = 50000) async throws -> [Church] {
        let cacheKey = "zip_\(zipCode)_\(radius)" as NSString
        
        if let cached = cache.object(forKey: cacheKey),
           Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval {
            return cached.churches
        }
        
        let churches = try await fetchChurchesByZipCode(zipCode, radius: radius)
        cache.setObject(CachedChurches(churches: churches, timestamp: Date()), forKey: cacheKey)
        return churches
    }
    
    func searchChurches(city: String, state: String, radius: Double = 50000) async throws -> [Church] {
        let cacheKey = "city_\(city)_\(state)_\(radius)" as NSString
        
        if let cached = cache.object(forKey: cacheKey),
           Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval {
            return cached.churches
        }
        
        let churches = try await fetchChurchesByCity(city, state: state, radius: radius)
        cache.setObject(CachedChurches(churches: churches, timestamp: Date()), forKey: cacheKey)
        return churches
    }
    
    private func fetchChurchesFromAPI(latitude: Double, longitude: Double, radius: Double) async throws -> [Church] {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        logger.info("Searching Apple Maps for SDA churches near \(latitude, privacy: .public), \(longitude, privacy: .public)")
        let churches = try await AppleMapsService.shared.searchChurches(near: location, radius: radius)
        logger.info("Found \(churches.count) churches from Apple Maps")
        return churches
    }
    
    
    private func fetchChurchesByZipCode(_ zipCode: String, radius: Double) async throws -> [Church] {
        logger.info("Searching Apple Maps for SDA churches in zip code \(zipCode, privacy: .public)")
        let churches = try await AppleMapsService.shared.searchChurches(zipCode: zipCode, radius: radius)
        logger.info("Found \(churches.count) churches from Apple Maps")
        return churches
    }
    
    private func fetchChurchesByCity(_ city: String, state: String, radius: Double) async throws -> [Church] {
        logger.info("Searching Apple Maps for SDA churches in \(city, privacy: .public), \(state, privacy: .public)")
        let churches = try await AppleMapsService.shared.searchChurches(city: city, state: state, radius: radius)
        logger.info("Found \(churches.count) churches from Apple Maps")
        return churches
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case serverError
    case decodingError
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .serverError:
            return "Server error occurred"
        case .decodingError:
            return "Failed to decode response"
        case .networkError:
            return "Network connection error"
        }
    }
}
