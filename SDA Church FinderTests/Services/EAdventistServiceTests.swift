import XCTest
import CoreLocation
@testable import AdventFind

final class EAdventistServiceTests: XCTestCase {
    var service: EAdventistService!
    
    override func setUp() {
        super.setUp()
        service = EAdventistService.shared
    }
    
    override func tearDown() {
        service.clearCache()
        service = nil
        super.tearDown()
    }
    
    func testSearchChurchesNearLocation() async throws {
        let location = CLLocation(latitude: 34.0522, longitude: -118.2437)
        
        let churches = try await service.searchChurches(near: location, radius: 50000)
        
        XCTAssertFalse(churches.isEmpty, "Should return at least one church")
        
        for church in churches {
            XCTAssertFalse(church.name.isEmpty, "Church name should not be empty")
            XCTAssertNotEqual(church.latitude, 0.0, "Latitude should be set")
            XCTAssertNotEqual(church.longitude, 0.0, "Longitude should be set")
        }
    }
    
    func testSearchChurchesByZipCode() async throws {
        let zipCode = "90210"
        
        let churches = try await service.searchChurches(zipCode: zipCode)
        
        XCTAssertFalse(churches.isEmpty, "Should return at least one church")
    }
    
    func testSearchChurchesByCity() async throws {
        let city = "Los Angeles"
        let state = "CA"
        
        let churches = try await service.searchChurches(city: city, state: state)
        
        XCTAssertFalse(churches.isEmpty, "Should return at least one church")
    }
    
    func testCacheExpiration() async throws {
        let location = CLLocation(latitude: 34.0522, longitude: -118.2437)
        
        let churches1 = try await service.searchChurches(near: location, radius: 50000)
        XCTAssertFalse(churches1.isEmpty)
        
        let churches2 = try await service.searchChurches(near: location, radius: 50000)
        XCTAssertEqual(churches1.count, churches2.count, "Cached results should match")
    }
    
    func testClearCache() async throws {
        let location = CLLocation(latitude: 34.0522, longitude: -118.2437)
        
        _ = try await service.searchChurches(near: location, radius: 50000)
        
        service.clearCache()
        
        let churches = try await service.searchChurches(near: location, radius: 50000)
        XCTAssertFalse(churches.isEmpty, "Should still return results after cache clear")
    }
}
