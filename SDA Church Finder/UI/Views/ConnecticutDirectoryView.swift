import SwiftUI

struct ConnecticutDirectoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var query = ""
    @State private var filters = DirectoryFilters()
    @FocusState private var searchIsFocused: Bool
    @State private var selected: ChurchDirectoryRecord?
    @State private var records: [ChurchDirectoryRecord] = ChurchDirectory.shared.records

    private var filtered: [ChurchDirectoryRecord] {
        records.filter { filters.includes($0, query: query) }
    }

    private var states: [String] { Set(records.map(\.state).filter { !$0.isEmpty }).sorted() }
    private var conferences: [String] { Set(records.compactMap(\.conference).filter { !$0.isEmpty }).sorted() }
    private var languages: [String] { Set(records.flatMap(\.filterLanguages)).sorted() }

    private var filterControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Menu {
                        Picker("State", selection: $filters.state) {
                            Text("All states").tag(DirectoryFilters.all)
                            ForEach(states, id: \.self) { Text(stateTitle($0)).tag($0) }
                            Text("State not listed").tag(DirectoryFilters.unknown)
                        }
                    } label: {
                        Label(filters.state == DirectoryFilters.all ? "State" : stateTitle(filters.state), systemImage: "mappin")
                    }.accessibilityIdentifier("directory.stateFilter")
                    Menu {
                        Picker("Conference", selection: $filters.conference) {
                            Text("All conferences").tag(DirectoryFilters.all)
                            ForEach(conferences, id: \.self) { Text($0).tag($0) }
                            Text("Conference not listed").tag(DirectoryFilters.unknown)
                        }
                    } label: {
                        Label(filters.conference == DirectoryFilters.all ? "Conference" :
                              filters.conference == DirectoryFilters.unknown ? "Conference not listed" : conferenceTitle(filters.conference), systemImage: "building.2")
                    }.accessibilityIdentifier("directory.conferenceFilter")
                    Menu {
                        Picker("Language", selection: $filters.language) {
                            Text("All languages").tag(DirectoryFilters.all)
                            ForEach(languages, id: \.self) { Text($0).tag($0) }
                            Text("Language not listed").tag(DirectoryFilters.unknown)
                        }
                        Toggle("Confirmed worship languages only", isOn: $filters.confirmedLanguagesOnly)
                    } label: {
                        Label(filters.language == DirectoryFilters.all ? "Language" :
                              filters.language == DirectoryFilters.unknown ? "Language not listed" : filters.language, systemImage: "character.bubble")
                    }.accessibilityIdentifier("directory.languageFilter")
                }.buttonStyle(.bordered).font(.caption.weight(.semibold))
            }
            if filters.language != DirectoryFilters.all || filters.confirmedLanguagesOnly {
                Text(filters.confirmedLanguagesOnly ? "Filtering confirmed worship languages. Many listings still need confirmation." :
                     "Language filters include clues in congregation names; worship languages may differ.")
                    .font(.caption).foregroundStyle(AdventDesign.muted)
            }
            HStack {
                Text("\(filtered.count) of \(records.count) congregations")
                    .accessibilityIdentifier("directory.resultCount")
                Spacer()
                if filters.isActive || !query.isEmpty {
                    Button("Clear filters") { filters = DirectoryFilters(); query = ""; searchIsFocused = false }
                        .accessibilityIdentifier("directory.clearFilters")
                }
            }.font(.caption).foregroundStyle(AdventDesign.muted)
        }
    }

    private func conferenceTitle(_ name: String) -> String {
        name == "Southern New England Conference" ? "SNEC" : name
    }

    private func stateTitle(_ code: String) -> String {
        [
            "CT": "Connecticut",
            "MA": "Massachusetts",
            "RI": "Rhode Island",
            "NY": "New York",
            "ME": "Maine",
            "NH": "New Hampshire",
            "VT": "Vermont",
            DirectoryFilters.unknown: "State not listed"
        ][code] ?? code
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let isDualPane = horizontalSizeClass == .regular && geometry.size.width >= 600
                if isDualPane {
                    HStack(spacing: 0) {
                        directoryList
                            .frame(width: geometry.size.width * 0.48)
                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(width: 1)
                        Group {
                            if let record = selected ?? filtered.first {
                                ConnecticutDirectoryDetailContent(record: record)
                            } else {
                                AdventEmptyState(symbol: "books.vertical", title: "Select a congregation", message: "Choose a community on the left to inspect its verified details and sources.")
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    directoryList
                        .sheet(item: $selected) { record in
                            ConnecticutDirectoryDetail(record: record)
                        }
                }
            }
            .background(AdventDesign.ink)
            .searchable(text: $query, prompt: "Church, town, or conference")
            .searchFocused($searchIsFocused)
            .scrollDismissesKeyboard(.interactively)
            .onSubmit(of: .search) { searchIsFocused = false }
            .navigationTitle("Church directory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { searchIsFocused = false }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(AdventDesign.orange)
        .onAppear {
            records = ChurchDirectory.shared.records
        }
        .onReceive(NotificationCenter.default.publisher(for: .churchDirectoryDidUpdate)) { _ in
            records = ChurchDirectory.shared.records
        }
    }

    private var directoryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Eyebrow(text: "Find your community")
                Text("Church communities.").font(.system(.largeTitle, design: .serif))
                Text("\(records.count) Seventh-day Adventist communities. Search by name, place, or conference. Some location details still need verification.")
                    .font(.subheadline).foregroundStyle(AdventDesign.muted)
                filterControls
                if filtered.isEmpty {
                    AdventEmptyState(symbol: "magnifyingglass", title: "No matching listings", message: "Try another church name or clear the filters to see all communities.")
                }
                ForEach(filtered) { record in
                    let isSelected = selected?.id == record.id
                    Button {
                        searchIsFocused = false
                        selected = record
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(record.name).font(.headline).foregroundStyle(AdventDesign.paper)
                            Text(record.fullAddress).font(.caption).foregroundStyle(AdventDesign.muted)
                            if !record.sourcedWorshipLanguages.isEmpty {
                                Label("Worship language: \(record.sourcedWorshipLanguages.formatted(.list(type: .and)))", systemImage: "character.bubble")
                                    .font(.caption).foregroundStyle(AdventDesign.muted)
                            } else if !record.indicatedLanguages.isEmpty {
                                Label("Language indicated: \(record.indicatedLanguages.formatted(.list(type: .and)))", systemImage: "character.bubble")
                                    .font(.caption).foregroundStyle(AdventDesign.muted)
                            }
                            HStack {
                                Text(record.addressStatusLabel)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }.font(.caption).foregroundStyle(AdventDesign.orange)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .adventPanel()
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(isSelected ? AdventDesign.orange.opacity(0.6) : .clear, lineWidth: 1.5)
                        )
                    }.buttonStyle(.plain)
                }
            }.padding(24)
        }
    }
}

private struct ConnecticutDirectoryDetail: View {
    let record: ChurchDirectoryRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ConnecticutDirectoryDetailContent(record: record)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { ShareLink(item: "\(record.name)\n\(record.fullAddress)\n\(record.website)") }
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
        }.preferredColorScheme(.dark).tint(AdventDesign.orange)
    }
}

private struct ConnecticutDirectoryDetailContent: View {
    let record: ChurchDirectoryRecord
    @State private var liveDetails = ChurchLiveDetails()
    @State private var isLoadingLiveDetails = true

    private var resolvedConference: String? {
        record.conference ?? liveDetails.resolvedConference
    }

    private var resolvedGivingURL: URL? {
        liveDetails.givingURL ?? record.givingURL.flatMap(URL.init(string:))
    }

    private var resolvedGivingOrgID: String? {
        liveDetails.adventistGivingOrgID ?? record.givingURL.flatMap(ChurchLiveDetailsService.extractAdventistGivingOrgID)
    }

    private var translationText: String {
        var lines = [record.name, record.fullAddress, "Conference: " + (resolvedConference ?? "Not yet verified")]
        if !record.indicatedLanguages.isEmpty {
            lines.append("Language indicated by listing name: " + record.indicatedLanguages.joined(separator: ", "))
        } else {
            lines.append("Worship language not listed.")
        }
        if !record.reviewNotes.isEmpty { lines.append(record.reviewNotes) }
        lines.append("Contact the church to confirm worship times, languages, and visitor information.")
        return lines.joined(separator: "\n\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Eyebrow(text: "Seventh-day Adventist community")
                    Spacer()
                    ShareLink(item: "\(record.name)\n\(record.fullAddress)\n\(record.website)") {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                Text(record.name).font(.system(.largeTitle, design: .serif))
                Label(record.fullAddress, systemImage: "mappin.and.ellipse").font(.headline)
                if let serviceTimes = liveDetails.serviceTimesSummary, !serviceTimes.isEmpty {
                    Label(serviceTimes, systemImage: "clock").font(.subheadline)
                }
                if let pastor = liveDetails.pastorName, !pastor.isEmpty {
                    Label(pastor, systemImage: "person").font(.subheadline)
                }
                if !record.sourcedWorshipLanguages.isEmpty {
                    Label("Worship language: \(record.sourcedWorshipLanguages.formatted(.list(type: .and)))", systemImage: "character.bubble")
                    Text(record.evidence(for: .languages).status.title).font(.caption).foregroundStyle(AdventDesign.muted)
                } else if !record.indicatedLanguages.isEmpty {
                    Label("Language indicated: \(record.indicatedLanguages.formatted(.list(type: .and)))", systemImage: "character.bubble")
                    Text("Based on the listing name. Contact the church to confirm worship languages.")
                        .font(.caption).foregroundStyle(AdventDesign.muted)
                } else {
                    Label("Worship language not listed", systemImage: "character.bubble")
                }
                ChurchConferenceSection(
                    conference: resolvedConference,
                    evidence: record.evidence(for: .conference),
                    liveSourceNote: record.conference == nil ? liveDetails.conferenceSourceDescription : nil
                )
                ChurchGivingSection(
                    churchName: record.name,
                    city: record.city,
                    state: record.state,
                    givingURL: resolvedGivingURL,
                    adventistGivingOrgID: resolvedGivingOrgID,
                    isLoading: isLoadingLiveDetails
                )
                ChurchEventsSection(
                    cacheKey: record.id,
                    churchName: record.name,
                    city: record.city,
                    state: record.state,
                    website: record.website,
                    eventsURL: record.eventsURL,
                    calendarFeedURL: record.calendarFeedURL
                )
                ChurchTranslationButton(text: translationText)
                if let url = record.directionsURL {
                    Link(destination: url) {
                        Label("Directions in Apple Maps", systemImage: "arrow.triangle.turn.up.right")
                            .frame(maxWidth: .infinity).padding(18)
                            .foregroundStyle(AdventDesign.ink)
                            .background(AdventDesign.orange, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                if let url = URL(string: record.website), ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
                    Link(destination: url) { Label("Visit church website", systemImage: "globe") }
                }
                if let phone = record.phone ?? liveDetails.phone, let url = URL(string: "tel:\(phone.sanitizedPhoneNumber())") {
                    Link(destination: url) { Label(phone, systemImage: "phone") }
                }
                if let email = liveDetails.email, let url = URL(string: "mailto:\(email)") {
                    Link(destination: url) { Label(email, systemImage: "envelope") }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "About this listing")
                    Text(record.addressStatusLabel + ". Check the individual sources below for dates and confirmation status.")
                    if !record.reviewNotes.isEmpty { Text(record.reviewNotes) }
                    Text("Confirm worship times directly with the church. This is an AdventFind research listing, not a live official directory feed.")
                    ForEach(record.sourceURLs, id: \.self) { source in
                        if let url = URL(string: source) { Link("View source", destination: url) }
                    }
                }.font(.subheadline).foregroundStyle(AdventDesign.muted).adventPanel()
                DirectoryVerificationSection(verification: record.verification)
            }.padding(24)
        }
        .background(AdventDesign.ink)
        .foregroundStyle(AdventDesign.paper)
        .task(id: record.id) {
            isLoadingLiveDetails = true
            liveDetails = await ChurchLiveDetailsService.shared.fetchLiveDetails(
                cacheKey: record.id,
                churchName: record.name,
                city: record.city,
                state: record.state,
                website: record.website,
                explicitGivingURL: record.givingURL
            )
            isLoadingLiveDetails = false
        }
    }
}
