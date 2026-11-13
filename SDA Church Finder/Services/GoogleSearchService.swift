import Foundation

final class GoogleSearchService {
    static let shared = GoogleSearchService()
    
    private init() {}
    
    func generateSearchURL(for church: Church) -> URL? {
        ChurchURLHelper.generateSearchURL(for: church)
    }
    
    func generateMapsSearchURL(for church: Church) -> URL? {
        ChurchURLHelper.generateMapsSearchURL(for: church)
    }
    
    func generateDirectionsURL(for church: Church) -> URL? {
        ChurchURLHelper.generateDirectionsURL(for: church)
    }
    
    func generateWebsiteSearchURL(for church: Church) -> URL? {
        ChurchURLHelper.generateWebsiteSearchURL(for: church)
    }
}
