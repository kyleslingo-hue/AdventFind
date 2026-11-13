import SwiftUI

struct ChurchCardView: View {
    let church: Church
    let distance: String
    let onTap: () -> Void
    let onFavorite: () -> Void
    var showDistance = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Button(action: onTap) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "building.2.crop.circle")
                            .font(.system(size: 29, weight: .ultraLight))
                            .foregroundStyle(AdventDesign.orange).frame(width: 50, height: 56)
                            .background(AdventDesign.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 7) {
                            Text(church.displayName).font(.system(.headline, design: .rounded))
                                .foregroundStyle(AdventDesign.paper).multilineTextAlignment(.leading)
                            Text([church.city, church.state].filter { !$0.isEmpty }.joined(separator: ", "))
                                .font(.caption).foregroundStyle(AdventDesign.muted)
                        }
                        Spacer(minLength: 0)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain)
                Button(action: onFavorite) {
                    Image(systemName: church.isFavorite ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(church.isFavorite ? AdventDesign.orange : AdventDesign.muted)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityLabel(church.isFavorite ? "Unsave \(church.displayName)" : "Save \(church.displayName)")
            }
            if let conference = church.conference {
                Label(conference, systemImage: "building.2")
                    .font(.caption).foregroundStyle(AdventDesign.muted)
            }
            if !church.languages.isEmpty {
                Label("Language indicated: \(church.languages.formatted(.list(type: .and)))", systemImage: "character.bubble")
                    .font(.caption).foregroundStyle(AdventDesign.muted)
            }
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
            Button(action: onTap) {
                HStack {
                    if showDistance && distance != "Unknown" {
                        Label(distance, systemImage: "location.north").font(.caption.weight(.medium))
                    } else {
                        Text("Plan a visit").font(.caption.weight(.medium))
                    }
                    Spacer()
                    Text("Church details").font(.caption.weight(.medium))
                    Image(systemName: "arrow.up.right").font(.caption)
                }.foregroundStyle(AdventDesign.orange).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }.adventPanel()
    }
}
