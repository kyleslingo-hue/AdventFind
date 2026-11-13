import SwiftUI
import MapKit
import CoreLocation

struct ChurchDetailView: View {
    let church: Church
    let distance: String
    let userLocation: CLLocation?
    var onFavoriteChange: (() -> Void)? = nil
    var onUpdate: ((Church) -> Void)? = nil
    @State private var saved = false
    @State private var liveDetails = ChurchLiveDetails()
    @State private var isLoadingLiveDetails = true
    @State private var showingReportAlert = false
    @StateObject private var place = SabbathPlace()

    private var reportEmailURL: URL? {
        let recipient = AppConstants.feedbackEmail
        let subject = "[AdventFind] Info Update: \(resolvedName)"
        let body = """
        Church: \(resolvedName)
        Address: \(church.fullAddress)
        Conference: \(resolvedConference ?? "Not listed")
        Website: \(resolvedWebsite ?? "None")
        AdventistGiving: \(resolvedGivingURL?.absoluteString ?? "None")

        What needs to be updated?
        [ ] Church is closed or moved
        [ ] Service times are incorrect
        [ ] Website or contact info is outdated
        [ ] AdventistGiving OrgID or envelope link needs update
        [ ] Other:

        Notes:

        """
        var components = URLComponents(string: "mailto:\(recipient)")
        components?.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components?.url
    }

    private var resolvedName: String {
        if let trueName = liveDetails.trueCongregationName, !trueName.isEmpty {
            return trueName
        }
        return church.displayName
    }

    private var resolvedConference: String? {
        church.conference ?? liveDetails.resolvedConference
    }

    private var resolvedWebsite: String? {
        church.website ?? liveDetails.discoveredWebsite?.absoluteString
    }

    private var resolvedServiceTime: String? {
        if let time = church.sabbathServiceTime, !time.isEmpty { return time }
        return liveDetails.serviceTimesSummary
    }

    private var resolvedPastor: String? {
        church.pastorName ?? liveDetails.pastorName
    }

    private var resolvedPhone: String? {
        church.phone ?? liveDetails.phone
    }

    private var resolvedEmail: String? {
        church.email ?? liveDetails.email
    }

    private var resolvedGivingURL: URL? {
        liveDetails.givingURL ?? church.givingURL.flatMap(URL.init(string:))
    }

    private var resolvedGivingOrgID: String? {
        liveDetails.adventistGivingOrgID ?? church.givingURL.flatMap(ChurchLiveDetailsService.extractAdventistGivingOrgID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ZStack(alignment: .bottomLeading) {
                    SabbathLandscape()
                    LinearGradient(colors: [.clear, AdventDesign.ink], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "A place to connect")
                        Text(resolvedName).font(.system(.largeTitle, design: .serif)).foregroundStyle(AdventDesign.paper)
                        if (church.isGenericName || church.displayName != church.name), liveDetails.trueCongregationName != nil {
                            Text("Verified congregation name")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(AdventDesign.orange)
                        }
                        Text([church.city, church.state].filter { !$0.isEmpty }.joined(separator: ", "))
                            .font(.subheadline).foregroundStyle(AdventDesign.muted)
                    }.padding(24)
                }.frame(minHeight: 300).clipShape(RoundedRectangle(cornerRadius: 28))
                HStack(spacing: 12) {
                    Button(action: directions) {
                        Label("Get directions", systemImage: "arrow.triangle.turn.up.right")
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(17)
                            .foregroundStyle(AdventDesign.ink)
                            .background(AdventDesign.orange, in: RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain)
                    Button {
                        FavoritesManager.shared.toggleFavorite(church)
                        saved = FavoritesManager.shared.isFavorite(church.id)
                        onFavoriteChange?()
                    } label: {
                        Image(systemName: saved ? "bookmark.fill" : "bookmark").frame(width: 54, height: 54)
                            .background(AdventDesign.panel, in: RoundedRectangle(cornerRadius: 16))
                    }.accessibilityLabel(saved ? "Unsave church" : "Save church")
                }
                VStack(alignment: .leading, spacing: 15) {
                    Eyebrow(text: "Come as you are")
                    Label(church.fullAddress, systemImage: "mappin.and.ellipse").font(.subheadline)
                    if distance != "Unknown" { Label(distance + " away", systemImage: "location.north").font(.caption).foregroundStyle(AdventDesign.muted) }
                    if let time = resolvedServiceTime, !time.isEmpty {
                        Label(time, systemImage: "clock").font(.subheadline)
                    } else {
                        Label("Contact the church for worship times", systemImage: "clock").font(.subheadline).foregroundStyle(AdventDesign.muted)
                    }
                    if !church.languages.isEmpty {
                        Label("Language indicated: \(church.languages.formatted(.list(type: .and)))", systemImage: "character.bubble")
                            .font(.subheadline)
                        Text("Based on the listing name. Contact the church to confirm worship languages.")
                            .font(.caption).foregroundStyle(AdventDesign.muted)
                    } else {
                        Label("Worship language not listed", systemImage: "character.bubble")
                            .font(.subheadline).foregroundStyle(AdventDesign.muted)
                    }
                    if let pastor = resolvedPastor { Label(pastor, systemImage: "person").font(.subheadline) }
                    if church.isAccessible { Label("Accessible entrance listed", systemImage: "figure.roll").font(.subheadline) }
                }.frame(maxWidth: .infinity, alignment: .leading).adventPanel()
                ChurchConferenceSection(
                    conference: resolvedConference,
                    evidence: church.directoryAttribution?.verification?[DirectoryField.conference.rawValue],
                    liveSourceNote: church.conference == nil ? liveDetails.conferenceSourceDescription : nil
                )
                ChurchGivingSection(
                    churchName: resolvedName,
                    city: church.city,
                    state: church.state,
                    givingURL: resolvedGivingURL,
                    adventistGivingOrgID: resolvedGivingOrgID,
                    isLoading: isLoadingLiveDetails,
                    onLinkAdventistGiving: { orgID, directURL in
                        liveDetails.adventistGivingOrgID = orgID
                        liveDetails.givingURL = directURL
                        if let conf = ChurchLiveDetailsService.conferenceName(forOrgID: orgID) {
                            liveDetails.conferenceFromOrgID = conf
                        }
                        var updated = church
                        updated.givingURL = directURL.absoluteString
                        if let conf = liveDetails.conferenceFromOrgID {
                            updated.conference = conf
                        }
                        onUpdate?(updated)
                    }
                )
                ChurchEventsSection(
                    cacheKey: church.id,
                    churchName: resolvedName,
                    city: church.city,
                    state: church.state,
                    website: resolvedWebsite,
                    eventsURL: church.eventsURL,
                    calendarFeedURL: church.calendarFeedURL
                )
                ChurchTranslationButton(text: translationText)
                Map(initialPosition: .region(MKCoordinateRegion(center: church.coordinate, latitudinalMeters: 3000, longitudinalMeters: 3000))) {
                    Marker(resolvedName, coordinate: church.coordinate).tint(AdventDesign.orange)
                }.frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 24))
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: "Make the connection")
                    if let phone = resolvedPhone, let url = URL(string: "tel:\(phone.sanitizedPhoneNumber())") {
                        Link(destination: url) { contactRow("Call the church", subtitle: phone, icon: "phone") }
                    }
                    if let website = resolvedWebsite, let url = URL(string: website), ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
                        Link(destination: url) { contactRow("Visit website", subtitle: url.host ?? website, icon: "globe") }
                    } else if let url = ChurchURLHelper.generateWebsiteSearchURL(for: church) {
                        Link(destination: url) { contactRow("Find church website", subtitle: "Search the web", icon: "magnifyingglass") }
                    }
                    if let email = resolvedEmail, let url = URL(string: "mailto:\(email)") {
                        Link(destination: url) { contactRow("Send an email", subtitle: email, icon: "envelope") }
                    }
                    if let url = reportEmailURL {
                        Link(destination: url) {
                            contactRow("Report outdated info", subtitle: "Email updates to \(AppConstants.feedbackEmail)", icon: "envelope.badge")
                        }
                    } else {
                        Button {
                            UIPasteboard.general.string = "To: \(AppConstants.feedbackEmail)\n\n\(translationText)"
                            showingReportAlert = true
                        } label: {
                            contactRow("Report outdated info", subtitle: "Copy details to email \(AppConstants.feedbackEmail)", icon: "envelope.badge")
                        }.buttonStyle(.plain)
                    }
                }.adventPanel()
                if let zone = place.timeZone {
                    TimelineView(.periodic(from: .now, by: 30)) { timeline in
                        if let sabbath = SabbathTimeService.shared.getNextSabbath(for: CLLocation(latitude: church.latitude, longitude: church.longitude), now: timeline.date, timeZone: zone) {
                            VStack(alignment: .leading, spacing: 16) {
                                Eyebrow(text: "Sunset at this church")
                                SabbathBanner(sabbath: sabbath, now: timeline.date)
                            }.adventPanel()
                        }
                    }
                }
                if let attribution = church.directoryAttribution {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "Name from church website")
                        Text("Source checked \(attribution.checkedOn). Map position provided by Apple Maps.")
                            .font(.caption).foregroundStyle(AdventDesign.muted)
                        if !attribution.reviewNotes.isEmpty {
                            Text(attribution.reviewNotes).font(.caption).foregroundStyle(AdventDesign.muted)
                        }
                        ForEach(attribution.sourceURLs, id: \.self) { source in
                            if let url = URL(string: source) { Link("View church source", destination: url).font(.caption) }
                        }
                    }.adventPanel()
                    DirectoryVerificationSection(verification: attribution.verification)
                }
                Text(church.directoryAttribution == nil
                     ? "Listed via Apple Maps. Contact the church to confirm worship times and visitor information. Landscape is an illustration."
                     : "Church name and website from AdventFind’s researched directory. Contact the church to confirm visitor information. Landscape is an illustration.")
                    .font(.caption).foregroundStyle(AdventDesign.muted).lineSpacing(4)
            }.padding(20).frame(maxWidth: 780).frame(maxWidth: .infinity)
        }.background(AdventDesign.ink).foregroundStyle(AdventDesign.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: "\(resolvedName)\n\(church.fullAddress)") {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .task(id: church.id) {
                saved = FavoritesManager.shared.isFavorite(church.id)
                isLoadingLiveDetails = true
                async let resolveTimezone: Void = place.resolve(CLLocation(latitude: church.latitude, longitude: church.longitude))
                async let fetchedDetails = ChurchLiveDetailsService.shared.fetchLiveDetails(
                    cacheKey: church.id,
                    churchName: church.isGenericName ? church.displayName : church.name,
                    city: church.city,
                    state: church.state,
                    website: church.website,
                    explicitGivingURL: church.givingURL
                )
                _ = await resolveTimezone
                liveDetails = await fetchedDetails
                isLoadingLiveDetails = false

                var updated = church
                var changed = false
                if let trueName = liveDetails.trueCongregationName, !trueName.isEmpty, trueName != updated.name {
                    updated.name = trueName
                    changed = true
                }
                if let conf = liveDetails.resolvedConference, updated.conference == nil {
                    updated.conference = conf
                    changed = true
                }
                if let site = liveDetails.discoveredWebsite?.absoluteString, updated.website == nil {
                    updated.website = site
                    changed = true
                }
                if let giving = liveDetails.givingURL?.absoluteString, updated.givingURL == nil {
                    updated.givingURL = giving
                    changed = true
                }
                if let pastor = liveDetails.pastorName, updated.pastorName == nil {
                    updated.pastorName = pastor
                    changed = true
                }
                if let time = liveDetails.serviceTimesSummary, updated.sabbathServiceTime == nil {
                    updated.sabbathServiceTime = time
                    changed = true
                }
                if let phone = liveDetails.phone, updated.phone == nil {
                    updated.phone = phone
                    changed = true
                }
                if let email = liveDetails.email, updated.email == nil {
                    updated.email = email
                    changed = true
                }
                if liveDetails.isLikelyClosed {
                    updated.isLikelyInactive = true
                    updated.operationalNotes = liveDetails.closedReason
                    changed = true
                }
                if changed {
                    onUpdate?(updated)
                }
            }
            .alert("Report Outdated Info", isPresented: $showingReportAlert) {
                Button("Copy Email & Details") {
                    UIPasteboard.general.string = "To: \(AppConstants.feedbackEmail)\n\n\(resolvedName)\n\(church.fullAddress)\nConference: \(resolvedConference ?? "Not listed")\nWebsite: \(resolvedWebsite ?? "None")"
                }
                Button("Done", role: .cancel) {}
            } message: {
                Text("Send updates or corrections directly to \(AppConstants.feedbackEmail). Church details have been copied to your clipboard.")
            }
    }

    private var translationText: String {
        var lines = [resolvedName, church.fullAddress, "Conference: " + (resolvedConference ?? "Not yet verified")]
        if !church.languages.isEmpty {
            lines.append("Language indicated by listing name: " + church.languages.joined(separator: ", "))
        } else {
            lines.append("Worship language not listed.")
        }
        lines.append(resolvedServiceTime.map { "Worship time: " + $0 }
                     ?? "Contact the church for worship times.")
        if let pastor = resolvedPastor { lines.append("Pastor: " + pastor) }
        if church.isAccessible { lines.append("Accessible entrance listed.") }
        if let notes = church.directoryAttribution?.reviewNotes, !notes.isEmpty { lines.append(notes) }
        lines.append("Contact the church to confirm worship languages and visitor information.")
        return lines.joined(separator: "\n\n")
    }

    private func contactRow(_ title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon).foregroundStyle(AdventDesign.orange).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AdventDesign.paper)
                Text(subtitle).font(.caption).foregroundStyle(AdventDesign.muted)
            }
            Spacer()
            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(AdventDesign.orange)
        }.padding(.vertical, 5)
    }

    private func directions() {
        let location = CLLocation(latitude: church.latitude, longitude: church.longitude)
        let address = MKAddress(fullAddress: church.fullAddress, shortAddress: church.city)
        let item = MKMapItem(location: location, address: address)
        item.name = resolvedName
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}
