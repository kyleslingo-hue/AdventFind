import SwiftUI
import Translation

struct ChurchTranslationButton: View {
    let text: String
    @State private var showingTranslation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Translate church details", systemImage: "translate") {
                showingTranslation = true
            }
            .translationPresentation(isPresented: $showingTranslation, text: text)
            Text("Translate on your device. You may need to download a language first.")
                .font(.caption).foregroundStyle(AdventDesign.muted)
        }
    }
}
