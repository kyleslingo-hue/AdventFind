import Foundation
import SwiftUI
import Combine

class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    @AppStorage("distanceUnit") var distanceUnit: DistanceUnit = .miles
    @AppStorage("defaultMapType") var defaultMapType: MapType = .standard
    @AppStorage("defaultView") var defaultView: DefaultView = .list
    @AppStorage("searchRadius") var searchRadius: SearchRadius = .twentyFive
    @AppStorage("autoSearch") var autoSearch: Bool = true
    @AppStorage("highContrast") var highContrast: Bool = false
    
    private init() {}
    
    func resetToDefaults() {
        distanceUnit = .miles
        defaultMapType = .standard
        defaultView = .list
        searchRadius = .twentyFive
        autoSearch = true
        highContrast = false
    }
}

enum DistanceUnit: String, CaseIterable, Identifiable {
    case miles = "Miles"
    case kilometers = "Kilometers"
    
    var id: String { self.rawValue }
    
    func convert(_ miles: Double) -> Double {
        switch self {
        case .miles:
            return miles
        case .kilometers:
            return miles * 1.60934
        }
    }
    
    var abbreviation: String {
        switch self {
        case .miles: return "mi"
        case .kilometers: return "km"
        }
    }
}

enum MapType: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case satellite = "Satellite"
    case hybrid = "Hybrid"
    
    var id: String { self.rawValue }
}

enum DefaultView: String, CaseIterable, Identifiable {
    case list = "List"
    case map = "Map"
    
    var id: String { self.rawValue }
}

enum SearchRadius: Int, CaseIterable, Identifiable {
    case five = 5
    case ten = 10
    case twentyFive = 25
    case fifty = 50
    case hundred = 100
    
    var id: Int { self.rawValue }
    
    var displayName: String {
        "\(self.rawValue) miles"
    }
    
    var meters: Double {
        Double(self.rawValue) * 1609.34
    }
}

