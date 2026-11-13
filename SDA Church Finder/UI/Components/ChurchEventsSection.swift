import SwiftUI
import SafariServices

struct ChurchEventsSection: View {
    let cacheKey: String
    let churchName: String
    let city: String
    let state: String
    let website: String?
    var eventsURL: String? = nil
    var calendarFeedURL: String? = nil

    @State private var events: [ChurchEvent] = []
    @State private var resolvedCalendarURL: URL?
    @State private var isLoading = true
    @State private var selectedSafariURL: IdentifiableURL?
    @State private var selectedEvent: ChurchEvent?

    private var fallbackWebURL: URL? {
        resolvedCalendarURL
            ?? ChurchEventsService.shared.defaultEventsWebURL(for: website, explicitEventsURL: eventsURL)
            ?? ChurchURLHelper.generateEventsSearchURL(churchName: churchName, city: city, state: state)
    }

    private var hasDirectCalendarWebsite: Bool {
        resolvedCalendarURL != nil || ChurchEventsService.shared.defaultEventsWebURL(for: website, explicitEventsURL: eventsURL) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Eyebrow(text: "Community calendar")
                Spacer()
                if !events.isEmpty {
                    Text("\(events.count) listed")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AdventDesign.orange)
                }
            }
            Text("Upcoming events & schedule")
                .font(.headline)
                .foregroundStyle(AdventDesign.paper)

            if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Checking church website for upcoming events…")
                        .font(.caption)
                        .foregroundStyle(AdventDesign.muted)
                }
                .padding(.vertical, 8)
            } else if !events.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(events) { event in
                        eventRow(event)
                    }
                }
            } else {
                Text("No upcoming events were published in this church’s online feed right now.")
                    .font(.caption)
                    .foregroundStyle(AdventDesign.muted)
                    .lineSpacing(3)
            }

            if let calendarURL = fallbackWebURL {
                Button {
                    selectedSafariURL = IdentifiableURL(url: calendarURL)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .foregroundStyle(AdventDesign.orange)
                        Text(hasDirectCalendarWebsite ? "View full calendar on church website" : "Search church events online")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AdventDesign.paper)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(AdventDesign.orange)
                    }
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("church.eventsButton")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .adventPanel()
        .task(id: cacheKey) {
            isLoading = true
            let result = await ChurchEventsService.shared.fetchUpcomingEvents(
                cacheKey: cacheKey,
                website: website,
                eventsURL: eventsURL,
                calendarFeedURL: calendarFeedURL
            )
            events = result.events
            resolvedCalendarURL = result.webCalendarURL
            isLoading = false
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailSheet(event: event, churchName: churchName) { url in
                selectedEvent = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    selectedSafariURL = IdentifiableURL(url: url)
                }
            }
        }
        .sheet(item: $selectedSafariURL) { item in
            InAppSafariView(url: item.url)
                .ignoresSafeArea()
        }
    }

    private func eventRow(_ event: ChurchEvent) -> some View {
        Button {
            selectedEvent = event
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(event.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AdventDesign.paper)
                            .multilineTextAlignment(.leading)
                        Label(event.formattedDateRange, systemImage: "clock")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AdventDesign.orange)
                        if let location = event.location, !location.isEmpty {
                            Label(location, systemImage: "mappin.and.ellipse")
                                .font(.caption2)
                                .foregroundStyle(AdventDesign.muted)
                                .lineLimit(1)
                        }
                        if let summary = event.summary, !summary.isEmpty {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(AdventDesign.muted)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AdventDesign.muted)
                        .padding(.top, 4)
                }
                .padding(14)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct EventDetailSheet: View {
    let event: ChurchEvent
    let churchName: String
    let onOpenWebURL: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Eyebrow(text: churchName)
                    Text(event.title)
                        .font(.system(.title, design: .serif))
                        .foregroundStyle(AdventDesign.paper)
                    VStack(alignment: .leading, spacing: 12) {
                        Label(event.formattedDateRange, systemImage: "clock")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AdventDesign.orange)
                        if let location = event.location, !location.isEmpty {
                            Label(location, systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                                .foregroundStyle(AdventDesign.paper)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .adventPanel()

                    if let summary = event.summary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow(text: "Details")
                            Text(summary)
                                .font(.subheadline)
                                .foregroundStyle(AdventDesign.paper)
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .adventPanel()
                    }

                    if let addURL = event.googleCalendarAddURL {
                        Button {
                            onOpenWebURL(addURL)
                        } label: {
                            Label("Add to Google Calendar", systemImage: "calendar.badge.plus")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .foregroundStyle(AdventDesign.ink)
                                .background(AdventDesign.orange, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }

                    if let eventURL = event.url {
                        Button {
                            onOpenWebURL(eventURL)
                        } label: {
                            Label("Open event page on website", systemImage: "safari")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .foregroundStyle(AdventDesign.paper)
                                .background(AdventDesign.panel, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
            .background(AdventDesign.ink)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
        .tint(AdventDesign.orange)
    }
}

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct InAppSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .done
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
