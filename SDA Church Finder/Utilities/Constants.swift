import Foundation

enum AppConstants {
    static let defaultSearchRadius: Double = 50000
    static let maxSearchRadius: Double = 100000
    static let minSearchRadius: Double = 5000
    static let feedbackEmail = "kyle.slingo@me.com"
}

enum UserDefaultsKeys {
    static let preferredDistanceUnit = "preferredDistanceUnit"
    static let lastSearchLocation = "lastSearchLocation"
    static let favoriteChurchIds = "favoriteChurchIds"
}
