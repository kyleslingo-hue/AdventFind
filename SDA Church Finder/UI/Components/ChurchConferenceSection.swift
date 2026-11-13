import SwiftUI

struct ChurchConferenceSection: View {
    let conference: String?
    var evidence: FieldVerification? = nil
    var liveSourceNote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Conference").font(.headline)
            if let conference {
                Label(conference, systemImage: "building.2")
                    .font(.subheadline)
                if let liveSourceNote, !liveSourceNote.isEmpty, (evidence == nil || evidence == .unknown) {
                    Text(liveSourceNote).font(.caption).foregroundStyle(AdventDesign.muted)
                } else {
                    Text((evidence ?? .unknown).displayStatus.title).font(.caption).foregroundStyle(AdventDesign.muted)
                }
            } else {
                Label("Conference not listed", systemImage: "building.2")
                    .font(.subheadline)
                    .foregroundStyle(AdventDesign.muted)
                Text("Fills automatically when identified on AdventistGiving")
                    .font(.caption)
                    .foregroundStyle(AdventDesign.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .adventPanel()
    }
}
