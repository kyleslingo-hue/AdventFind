import SwiftUI
import MapKit
import CoreLocation

struct HomeView: View {
    @StateObject private var locationManager: LocationManager
    @StateObject private var viewModel: ChurchViewModel
    @StateObject private var place = SabbathPlace()
    @ObservedObject private var settings = UserSettings.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var filterIsFocused: Bool
    @FocusState private var destinationIsFocused: Bool
    @SceneStorage("adventfind.selectedTab") private var tab = 0
    @SceneStorage("adventfind.destination") private var destination = ""
    @SceneStorage("adventfind.mapMode") private var mapMode = false
    @State private var showingSearch = false
    @State private var showingConnecticutDirectory = false
    @State private var searchError: String?
    @State private var locatingPlace = false
    @State private var selected: Church?
    @State private var camera: MapCameraPosition = .automatic
    @State private var locationTask: Task<Void, Never>?

    init() {
        let manager = LocationManager()
        _locationManager = StateObject(wrappedValue: manager)
        _viewModel = StateObject(wrappedValue: ChurchViewModel(locationManager: manager))
    }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { dashboard }
                .tabItem { Label("Today", systemImage: "sun.horizon") }.tag(0)
            NavigationStack { explore }
                .tabItem { Label("Explore", systemImage: "map") }.tag(1)
            NavigationStack { saved }
                .tabItem { Label("Saved", systemImage: "bookmark") }.tag(2)
            NavigationStack { SettingsView() }
                .tabItem { Label("You", systemImage: "person.crop.circle") }.tag(3)
        }
        .tint(AdventDesign.orange)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingSearch) { locationSearchView }
        .sheet(isPresented: $showingConnecticutDirectory) { ConnecticutDirectoryView() }
        .sheet(item: $selected, onDismiss: { viewModel.refreshSavedChurches() }) { church in
            NavigationStack {
                ChurchDetailView(
                    church: church,
                    distance: viewModel.distance(to: church),
                    userLocation: locationManager.location,
                    onFavoriteChange: { viewModel.refreshSavedChurches() },
                    onUpdate: { updated in
                        selected = updated
                        viewModel.updateChurch(updated)
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { selected = nil } }
                }
            }.tint(AdventDesign.orange).preferredColorScheme(.dark)
        }
        .onChange(of: locationManager.location, initial: true) { _, location in
            guard let location else { return }
            if let current = place.location,
               !viewModel.churches.isEmpty,
               location.distance(from: current) < 500 {
                return
            }
            locationTask?.cancel()
            locationTask = Task {
                async let resolveTask: Void = place.resolve(location)
                if settings.autoSearch {
                    await viewModel.searchNearby()
                }
                await resolveTask
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, let location = place.location, place.timeZone == nil {
                Task { await place.resolve(location) }
            }
        }
        .task {
            if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                locationManager.requestLocation()
            }
        }
    }

    private func isUnfoldedCanvas(_ width: CGFloat) -> Bool {
        horizontalSizeClass == .regular || width >= 600
    }

    private var dashboard: some View {
        GeometryReader { geometry in
            let dualPane = isUnfoldedCanvas(geometry.size.width)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    masthead
                    if dualPane {
                        HStack(alignment: .top, spacing: 28) {
                            sabbathHero
                                .frame(maxWidth: .infinity)
                            VStack(alignment: .leading, spacing: 24) {
                                discoveryInvitation
                                Divider().overlay(.white.opacity(0.08))
                                nextVisitSection
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        sabbathHero
                        discoveryInvitation
                        nextVisitSection
                    }
                    Text("A community of faith. A world of possibility.")
                        .font(.system(.footnote, design: .serif)).italic()
                        .foregroundStyle(AdventDesign.muted).frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .padding(24)
                .frame(maxWidth: 1200)
                .frame(maxWidth: .infinity)
            }
        }
        .background(AdventDesign.ink)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var nextVisitSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow(text: "Your next visit")
                Spacer()
                Button("Explore all") { tab = 1 }.font(.caption.weight(.semibold))
            }
            if viewModel.isLoading {
                ProgressView("Finding your community…").frame(maxWidth: .infinity).padding(24)
            } else if let church = viewModel.filteredChurches.first {
                churchCard(church)
            } else {
                Button { showingSearch = true } label: {
                    HStack(spacing: 18) {
                        Image(systemName: "location.north.circle").font(.largeTitle.weight(.ultraLight)).foregroundStyle(AdventDesign.orange)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Somewhere you’re welcome.").font(.headline).foregroundStyle(AdventDesign.paper)
                            Text("Choose a place to find your next church.").font(.caption).foregroundStyle(AdventDesign.muted)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right").foregroundStyle(AdventDesign.orange)
                    }.adventPanel()
                }.buttonStyle(.plain)
            }
        }
    }

    private var masthead: some View {
        HStack(alignment: .center) {
            HStack(spacing: 9) {
                Image(systemName: "sun.horizon.fill").foregroundStyle(AdventDesign.orange)
                Text("adventfind").font(.system(.title3, design: .rounded, weight: .bold)).tracking(-0.6)
            }
            Spacer()
            Button { showingSearch = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "location.fill").font(.caption2)
                    Text(place.name).font(.caption.weight(.medium)).lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                }.foregroundStyle(AdventDesign.paper).padding(11)
                    .background(.white.opacity(0.07), in: Capsule())
            }.accessibilityLabel("Choose place. \(place.name)")
        }.foregroundStyle(AdventDesign.paper)
    }

    private var sabbathHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                SabbathLandscape()
                VStack(alignment: .leading, spacing: 12) {
                    Text("MAKE ROOM FOR REST").font(.system(size: 9, weight: .bold)).tracking(3)
                    Text("The world can wait.")
                        .font(.system(.largeTitle, design: .serif, weight: .regular))
                        .frame(maxWidth: 240, alignment: .leading)
                }.foregroundStyle(AdventDesign.paper).padding(24)
            }.frame(height: 255)
            VStack(alignment: .leading, spacing: 14) {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    if let location = place.location, let zone = place.timeZone {
                        if let sabbath = SabbathTimeService.shared.getNextSabbath(for: location, now: context.date, timeZone: zone) {
                            SabbathBanner(sabbath: sabbath, now: context.date)
                        } else {
                            Text("No sunset at this location for this Sabbath.").font(.headline)
                            Text("At high latitudes, check local guidance for Sabbath observance.").font(.caption).foregroundStyle(AdventDesign.muted)
                        }
                    } else if place.isResolving {
                        ProgressView("Checking local sunset times…").padding(.vertical, 12)
                    } else {
                        Text("Sunset, in your corner of the world.").font(.headline)
                        Text(place.error ?? "Choose a location to see Friday and Saturday sunset in its local time zone.")
                            .font(.subheadline).foregroundStyle(AdventDesign.muted)
                        Button("Set your location", systemImage: "location") { showingSearch = true }
                            .font(.subheadline.weight(.semibold))
                    }
                }
                if place.timeZone != nil {
                    HStack(spacing: 5) {
                        Image(systemName: "mappin")
                        Text(place.name + " · Calculated sunset")
                    }.font(.caption2).foregroundStyle(AdventDesign.muted)
                }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                .background(AdventDesign.panel)
        }.clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private var discoveryInvitation: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "Less searching. More belonging.")
            Text("There’s a place\nfor you here.")
                .font(.system(.largeTitle, design: .serif)).foregroundStyle(AdventDesign.paper)
            Text("Across town or far from home, find a Seventh-day Adventist community to share your Sabbath.")
                .font(.subheadline).foregroundStyle(AdventDesign.muted).lineSpacing(4)
            Button { tab = 1; if viewModel.churches.isEmpty { showingSearch = true } } label: {
                HStack { Text("Find your community"); Spacer(); Image(systemName: "arrow.right") }
                    .font(.subheadline.weight(.semibold)).padding(18)
                    .foregroundStyle(AdventDesign.ink)
                    .background(AdventDesign.orange, in: RoundedRectangle(cornerRadius: 18))
            }.buttonStyle(.plain)
        }.padding(.vertical, 6)
    }

    private func exploreHeader(showMapToggle: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow(text: "Go where you belong")
            HStack {
                Text("Find a community.").font(.system(.largeTitle, design: .serif))
                Spacer()
                Button { showingSearch = true } label: { Image(systemName: "location.magnifyingglass").font(.title2) }
                    .accessibilityLabel("Search another place")
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(AdventDesign.muted)
                TextField("Filter churches by name or address", text: $viewModel.searchText)
                    .font(.subheadline)
                    .focused($filterIsFocused)
                    .submitLabel(.done)
                    .onSubmit { filterIsFocused = false }
                if !viewModel.searchText.isEmpty {
                    Button { viewModel.searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Clear filter")
                }
            }.padding(15).background(AdventDesign.panel, in: RoundedRectangle(cornerRadius: 16))
            HStack {
                Button { showingSearch = true } label: { Label(place.name, systemImage: "mappin") }.lineLimit(1)
                Spacer()
                Menu {
                    ForEach(SearchRadius.allCases) { radius in
                        Button(radius.displayName) { settings.searchRadius = radius }
                    }
                } label: { Text(settings.searchRadius.displayName) }
                if showMapToggle {
                    Button { mapMode.toggle() } label: { Image(systemName: mapMode ? "list.bullet" : "map") }
                        .accessibilityLabel(mapMode ? "Show list" : "Show map")
                }
            }.font(.caption.weight(.medium))
            Button { showingConnecticutDirectory = true } label: {
                Label("Browse church directory", systemImage: "books.vertical")
            }.font(.caption.weight(.semibold))
        }.padding(24)
    }

    private var explore: some View {
        GeometryReader { geometry in
            let dualPane = isUnfoldedCanvas(geometry.size.width)
            if dualPane {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        exploreHeader(showMapToggle: false)
                        resultList
                        Text("Maps by Apple · Names from church websites where matched")
                            .font(.system(size: 10)).foregroundStyle(AdventDesign.muted).padding(10)
                    }
                    .frame(width: geometry.size.width * 0.48)
                    explorerMap
                        .padding(.top, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    exploreHeader(showMapToggle: true)
                    if mapMode { explorerMap } else { resultList }
                    Text("Maps by Apple · Names from church websites where matched")
                        .font(.system(size: 10)).foregroundStyle(AdventDesign.muted).padding(10)
                }
            }
        }
        .background(AdventDesign.ink)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { filterIsFocused = false }
            }
        }
    }

    private var resultList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if viewModel.isLoading {
                    ProgressView("Looking for churches…").padding(32).frame(maxWidth: .infinity)
                } else if let error = viewModel.error {
                    AdventEmptyState(symbol: "wifi.exclamationmark", title: "Let’s try that again", message: error)
                    Button("Choose a place") { showingSearch = true }.frame(maxWidth: .infinity)
                } else if viewModel.filteredChurches.isEmpty {
                    AdventEmptyState(symbol: "map", title: viewModel.churches.isEmpty ? "Start somewhere new" : "No matches yet", message: viewModel.churches.isEmpty ? "Choose a city, ZIP code, or your current location. Your next community is out there." : "Try a different church name or clear your filter.")
                    Button("Choose a place") { showingSearch = true }.frame(maxWidth: .infinity)
                } else {
                    Eyebrow(text: "\(viewModel.filteredChurches.count) places to connect")
                    ForEach(viewModel.filteredChurches) { church in churchCard(church) }
                }
            }.padding(.horizontal, 24).padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var explorerMap: some View {
        Map(position: $camera) {
            UserAnnotation()
            ForEach(viewModel.filteredChurches) { church in
                Annotation(church.displayName, coordinate: church.coordinate) {
                    Button { selected = church } label: {
                        Image(systemName: "building.2.fill").font(.subheadline)
                            .foregroundStyle(AdventDesign.ink).padding(12)
                            .background(AdventDesign.orange, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AdventDesign.paper, lineWidth: 2))
                    }.accessibilityLabel("View \(church.displayName)")
                }
            }
        }.mapStyle(.standard(elevation: .flat))
            .mapControls { MapCompass(); MapScaleView() }
            .onChange(of: viewModel.filteredChurches) { _, _ in camera = .automatic }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 16).padding(.bottom, 8)
    }

    private var saved: some View {
        GeometryReader { geometry in
            let dualPane = isUnfoldedCanvas(geometry.size.width)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Eyebrow(text: "Keep a little community close")
                    Text("Places to return to.").font(.system(.largeTitle, design: .serif))
                    let churches = viewModel.savedChurches
                    if churches.isEmpty {
                        AdventEmptyState(symbol: "bookmark", title: "A place worth keeping", message: "Save a church while you explore. You’ll find it here when you’re ready to visit.")
                    } else if dualPane {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)], spacing: 18) {
                            ForEach(churches) { church in churchCard(church) }
                        }
                    } else {
                        ForEach(churches) { church in churchCard(church) }
                    }
                }
                .padding(24)
                .frame(maxWidth: 1200)
                .frame(maxWidth: .infinity)
            }
        }
        .background(AdventDesign.ink)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func churchCard(_ church: Church) -> some View {
        ChurchCardView(church: church, distance: viewModel.distance(to: church), onTap: { selected = church },
                       onFavorite: { viewModel.toggleFavorite(church) })
    }

    private var locationSearchView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Eyebrow(text: "A new place. A familiar faith.")
                Text("Where are you headed?").font(.system(.largeTitle, design: .serif))
                Text("Search a city, state, or ZIP code. Sunset times will follow the place you choose.")
                    .font(.subheadline).foregroundStyle(AdventDesign.muted)
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("City or ZIP code", text: $destination).submitLabel(.search).onSubmit { searchPlace() }
                        .autocorrectionDisabled()
                        .focused($destinationIsFocused)
                }.padding(18).background(AdventDesign.panel, in: RoundedRectangle(cornerRadius: 16))
                if locatingPlace { ProgressView("Finding your place…") }
                if let searchError { Text(searchError).font(.caption).foregroundStyle(AdventDesign.orange) }
                Button(action: searchPlace) {
                    HStack { Text("Explore this place"); Spacer(); Image(systemName: "arrow.right") }
                        .padding(18).foregroundStyle(AdventDesign.ink)
                        .background(AdventDesign.orange, in: RoundedRectangle(cornerRadius: 16))
                }.disabled(destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || locatingPlace)
                Button(action: useMyLocation) { Label("Use my current location", systemImage: "location.fill") }
                    .frame(maxWidth: .infinity).padding(12)
                if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                    Text("Location access is off. Search above, or enable it in Settings.")
                        .font(.caption).foregroundStyle(AdventDesign.muted)
                }
                Spacer(minLength: 0)
            }.padding(24).background(AdventDesign.ink)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { showingSearch = false } }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { destinationIsFocused = false }
                    }
                }
        }.presentationDetents([.large]).preferredColorScheme(.dark).tint(AdventDesign.orange)
    }

    private func searchPlace() {
        guard !locatingPlace else { return }
        let query = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        destinationIsFocused = false
        locatingPlace = true
        searchError = nil
        Task {
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                request.resultTypes = [.address]
                let response = try await MKLocalSearch(request: request).start()
                guard let item = response.mapItems.first else { throw MapError.locationNotFound }
                let location = item.location
                locationTask?.cancel()
                await place.resolve(location, label: item.name ?? query)
                await viewModel.searchAt(location)
                showingSearch = false
                tab = 1
            } catch { searchError = "We couldn’t find that place. Try a city and state or a ZIP code." }
            locatingPlace = false
        }
    }

    private func useMyLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined: locationManager.requestPermission()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
            showingSearch = false
        default: searchError = "Location access is off. You can still search any city or ZIP code."
        }
    }
}
