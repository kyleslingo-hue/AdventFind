import SwiftUI

struct HighContrastModifier: ViewModifier {
    @ObservedObject private var settings = UserSettings.shared
    
    func body(content: Content) -> some View {
        content
            .brightness(settings.highContrast ? 0.05 : 0)
            .contrast(settings.highContrast ? 1.1 : 1.0)
    }
}

extension View {
    func applyHighContrast() -> some View {
        modifier(HighContrastModifier())
    }
}
