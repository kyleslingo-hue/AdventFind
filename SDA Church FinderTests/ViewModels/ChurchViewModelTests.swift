import XCTest
import CoreLocation
@testable import AdventFind

@MainActor
final class ChurchViewModelTests: XCTestCase {
    var viewModel: ChurchViewModel!
    var locationManager: LocationManager!
    
    override func setUp() async throws {
        try await super.setUp()
        FavoritesManager.shared.removeFavorite("1")
        locationManager = LocationManager()
        viewModel = ChurchViewModel(locationManager: locationManager)
    }
    
    override func tearDown() async throws {
        FavoritesManager.shared.removeFavorite("1")
        viewModel = nil
        locationManager = nil
        try await super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertTrue(viewModel.churches.isEmpty, "Churches should be empty initially")
        XCTAssertTrue(viewModel.filteredChurches.isEmpty, "Filtered churches should be empty initially")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        XCTAssertNil(viewModel.error, "Should have no error initially")
        XCTAssertTrue(viewModel.searchText.isEmpty, "Search text should be empty initially")
    }
    
    func testSearchTextFiltering() {
        let church1 = Church(
            id: "1",
            name: "Glendale City SDA Church",
            address: "123 Main St",
            city: "Glendale",
            state: "CA",
            zipCode: "91206",
            country: "USA",
            latitude: 34.1425,
            longitude: -118.2551
        )
        
        let church2 = Church(
            id: "2",
            name: "Pasadena SDA Church",
            address: "456 Oak Ave",
            city: "Pasadena",
            state: "CA",
            zipCode: "91104",
            country: "USA",
            latitude: 34.1478,
            longitude: -118.1242
        )
        
        viewModel.churches = [church1, church2]
        
        XCTAssertEqual(viewModel.filteredChurches.count, 2, "Should show all churches with no filter")
        
        viewModel.searchText = "Glendale"
        
        let expectation = XCTestExpectation(description: "Filter updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.viewModel.filteredChurches.count, 1, "Should filter to one church")
            XCTAssertEqual(self.viewModel.filteredChurches.first?.name, "Glendale City SDA Church")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testToggleFavorite() {
        let church = Church(
            id: "1",
            name: "Test Church",
            address: "123 Main St",
            city: "Test City",
            state: "CA",
            zipCode: "12345",
            country: "USA",
            latitude: 34.0,
            longitude: -118.0
        )
        
        viewModel.churches = [church]
        
        XCTAssertFalse(viewModel.churches[0].isFavorite, "Should not be favorite initially")
        
        viewModel.toggleFavorite(church)
        
        XCTAssertTrue(viewModel.churches[0].isFavorite, "Should be favorite after toggle")
        
        viewModel.toggleFavorite(church)
        
        XCTAssertFalse(viewModel.churches[0].isFavorite, "Should not be favorite after second toggle")
    }
    
    func testDistanceCalculation() {
        let church = Church(
            id: "1",
            name: "Test Church",
            address: "123 Main St",
            city: "Test City",
            state: "CA",
            zipCode: "12345",
            country: "USA",
            latitude: 34.0522,
            longitude: -118.2437
        )
        
        viewModel.churches = [church]
        locationManager.location = CLLocation(latitude: 34.0522, longitude: -118.2437)
        
        let distance = viewModel.distance(to: church)
        
        XCTAssertNotEqual(distance, "Unknown", "Should calculate distance when location is available")
    }

    func testDistanceFromSearchCenterWithoutGPSPermission() {
        let church = Church(
            id: "1",
            name: "Hartford SDA Church",
            address: "123 Main St",
            city: "Hartford",
            state: "CT",
            zipCode: "06105",
            country: "USA",
            latitude: 41.7658,
            longitude: -72.6734
        )
        viewModel.churches = [church]
        viewModel.searchCenterLocation = CLLocation(latitude: 41.7658, longitude: -72.6734)

        XCTAssertNil(locationManager.location)
        XCTAssertNotEqual(viewModel.distance(to: church), "Unknown")
    }
}
