import SwiftUI

struct TextSizeModifier: ViewModifier {
    @Environment(\.sizeCategory) var sizeCategory
    
    func body(content: Content) -> some View {
        content
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

extension View {
    func applyTextSize() -> some View {
        modifier(TextSizeModifier())
    }
}
