import SwiftUI

struct DirectoryVerificationSection: View {
    let verification: [String: FieldVerification]?

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 18) {
                Text("Published sources and direct church confirmations are tracked separately for each detail.")
                    .font(.caption).foregroundStyle(AdventDesign.muted)
                ForEach(DirectoryField.allCases) { field in
                    let evidence = verification?[field.rawValue] ?? .unknown
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(field.title).font(.subheadline.weight(.medium))
                            Spacer()
                            Text(evidence.displayStatus.title).font(.caption)
                                .foregroundStyle(evidence.isSourced ? AdventDesign.orange : AdventDesign.muted)
                        }
                        if let date = evidence.checkedOn {
                            Text("Source checked \(date)").font(.caption2).foregroundStyle(AdventDesign.muted)
                        }
                        if let title = evidence.sourceTitle {
                            Text(evidence.sourcePage != nil ? "Southern New England Conference" : title)
                                .font(.caption2).foregroundStyle(AdventDesign.muted)
                        }
                        if let date = evidence.sourceDate {
                            Text("Source dated \(date)").font(.caption2).foregroundStyle(AdventDesign.muted)
                        }
                        ForEach(evidence.sourceURLs, id: \.self) { source in
                            if let url = URL(string: source), ["https", "http"].contains(url.scheme ?? "") {
                                Link(url.host ?? "View source", destination: url).font(.caption2)
                            }
                        }
                    }
                }
            }.padding(.top, 16)
        } label: {
            Label("Sources and checks", systemImage: "checklist").font(.headline)
        }.adventPanel()
    }
}
