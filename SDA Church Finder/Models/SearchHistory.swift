import Foundation
import SwiftData

@Model
final class SearchHistory {
    var id: String
    var searchTerm: String
    var searchType: SearchType
    var timestamp: Date
    
    init(searchTerm: String, searchType: SearchType) {
        self.id = UUID().uuidString
        self.searchTerm = searchTerm
        self.searchType = searchType
        self.timestamp = Date()
    }
}

enum SearchType: String, Codable {
    case location
    case zipCode
    case cityState
}
