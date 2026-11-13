import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var syncService = DirectorySyncService.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        GeometryReader { geometry in
            let isDualPane = horizontalSizeClass == .regular || geometry.size.width >= 600
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Eyebrow(text: "Make yourself at home")
                    Text("Your way to explore.").font(.system(.largeTitle, design: .serif))
                    if isDualPane {
                        HStack(alignment: .top, spacing: 24) {
                            VStack(alignment: .leading, spacing: 24) {
                                discoveryPanel
                                accessibilityPanel
                                directoryPanel
                            }.frame(maxWidth: .infinity)
                            VStack(alignment: .leading, spacing: 24) {
                                sunsetPanel
                                aboutPanel
                            }.frame(maxWidth: .infinity)
                        }
                    } else {
                        discoveryPanel
                        accessibilityPanel
                        directoryPanel
                        sunsetPanel
                        aboutPanel
                    }
                }
                .padding(24)
                .frame(maxWidth: 1120)
                .frame(maxWidth: .infinity)
            }
        }
        .background(AdventDesign.ink)
        .foregroundStyle(AdventDesign.paper)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var discoveryPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            Eyebrow(text: "Discovery")
            Picker("Distance units", selection: $settings.distanceUnit) {
                ForEach(DistanceUnit.allCases) { Text($0.rawValue).tag($0) }
            }
            Divider()
            Picker("Search radius", selection: $settings.searchRadius) {
                ForEach(SearchRadius.allCases) { Text($0.displayName).tag($0) }
            }
            Divider()
            Toggle("Find churches after locating me", isOn: $settings.autoSearch)
        }.adventPanel()
    }

    private var accessibilityPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow(text: "Display & readability")
            Toggle("Boost contrast", isOn: $settings.highContrast)
            Text("Increases contrast across dark panels and warm ivory text.")
                .font(.caption).foregroundStyle(AdventDesign.muted)
        }.adventPanel()
    }

    private var directoryPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Church Directory")
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Verified Database").font(.headline)
                    Text("\(ChurchDirectory.shared.records.count) verified churches loaded")
                        .font(.subheadline)
                        .foregroundStyle(AdventDesign.muted)
                }
                Spacer()
                Button {
                    Task {
                        _ = await syncService.sync(force: true)
                    }
                } label: {
                    syncButtonLabel
                }
                .buttonStyle(.borderedProminent)
                .tint(AdventDesign.orange)
                .disabled(syncService.status == .syncing)
            }
            Divider()
            syncStatusText
        }.adventPanel()
    }

    @ViewBuilder
    private var syncButtonLabel: some View {
        HStack(spacing: 6) {
            if syncService.status == .syncing {
                ProgressView().tint(AdventDesign.paper)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Check").fontWeight(.semibold)
            }
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private var syncStatusText: some View {
        switch syncService.status {
        case .syncing:
            Text("Checking GitHub for verified church updates...")
                .font(.caption).foregroundStyle(AdventDesign.muted)
        case .updated(let count):
            Text("Successfully updated \(count) directory dataset(s).")
                .font(.caption).foregroundStyle(AdventDesign.orange)
        case .upToDate:
            Text("Database is up to date.")
                .font(.caption).foregroundStyle(AdventDesign.muted)
        case .failed(let reason):
            Text("Using local/offline database (\(reason)).")
                .font(.caption).foregroundStyle(AdventDesign.muted)
        case .idle:
            Text("Automatically updates in background when online.")
                .font(.caption).foregroundStyle(AdventDesign.muted)
        }
    }

    private var sunsetPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "About sunset times")
            Label("Local to the place you choose", systemImage: "sun.horizon")
                .font(.headline).foregroundStyle(AdventDesign.orange)
            Text("Friday and Saturday sunset are calculated from coordinates and the location’s time zone, including daylight saving time. Times are estimates for a level horizon; local terrain and weather can affect what you see.")
                .font(.subheadline).foregroundStyle(AdventDesign.muted).lineSpacing(4)
            Text("If no sunset occurs, we won’t invent an observance time. Ask the local church for guidance.")
                .font(.caption).foregroundStyle(AdventDesign.muted)
        }.adventPanel()
    }

    private var aboutPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Made for the journey")
            Text("AdventFind").font(.system(.title, design: .rounded, weight: .bold))
            Text("Discover Seventh-day Adventist communities. Save a place. Make room for Sabbath.")
                .font(.subheadline).foregroundStyle(AdventDesign.muted)
            Divider()
            Text("Discovery uses Apple Maps with researched Connecticut names from church websites where an address match is clear. You can browse the Connecticut directory in Explore. Official directory integration is still in development. Saved churches stay on this device.")
                .font(.caption).foregroundStyle(AdventDesign.muted)
        }.adventPanel()
    }
}
