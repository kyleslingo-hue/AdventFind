import Foundation

extension Double {
    func toMiles() -> Double {
        self / 1609.34
    }
    
    func toKilometers() -> Double {
        self / 1000
    }
    
    func formatDistance() -> String {
        let miles = self.toMiles()
        if miles < 1 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.0f mi", miles)
        }
    }
}

extension String {
    func sanitizedPhoneNumber() -> String {
        let allowedCharacters = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "+"))
        return self.components(separatedBy: allowedCharacters.inverted).joined()
    }
}
