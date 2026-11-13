import Foundation
import SwiftUI
import CoreLocation
import Combine

@MainActor
class ChurchViewModel: ObservableObject {
    @Published var churches: [Church] = [] {
        didSet { updateFilteredChurches() }
    }
    @Published var savedChurches: [Church] = FavoritesManager.shared.savedChurches()
    @Published var filteredChurches: [Church] = []
    @Published var selectedChurch: Church?
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchText = "" {
        didSet { updateFilteredChurches() }
    }
    @Published var selectedLanguages: Set<String> = [] {
        didSet { updateFilteredChurches() }
    }
    @Published var showMapView = true
    @Published var searchCenterLocation: CLLocation?
    
    private let apiService = EAdventistService.shared
    let locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    private var hasPerformedInitialSearch = false
    private let settings = UserSettings.shared
    private var distanceCache: [String: Double] = [:]
    private var lastLocationForCache: CLLocation?
    private var isLocationBasedSearch = false
    private var lastSearchRadius: SearchRadius
    
    var maxDistance: Double {
        Double(settings.searchRadius.rawValue)
    }
    
    private var referenceLocation: CLLocation? {
        if isLocationBasedSearch {
            return locationManager.location ?? searchCenterLocation
        }
        return searchCenterLocation ?? locationManager.location
    }
    
    private func updateFilteredChurches() {
        var filtered = churches
        
        if !searchText.isEmpty {
            filtered = filtered.filter { church in
                church.name.localizedCaseInsensitiveContains(searchText) ||
                church.city.localizedCaseInsensitiveContains(searchText) ||
                church.address.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if !selectedLanguages.isEmpty {
            filtered = filtered.filter { church in
                !Set(church.languages).isDisjoint(with: selectedLanguages)
            }
        }
        
        if let location = referenceLocation {
            filtered = filtered.filter { church in
                church.distance(from: location) <= maxDistance * 1609.34
            }
        }
        
        filteredChurches = filtered
    }
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        self.lastSearchRadius = settings.searchRadius
        
        settings.objectWillChange
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    let radiusChanged = self.settings.searchRadius != self.lastSearchRadius
                    self.lastSearchRadius = self.settings.searchRadius
                    if radiusChanged {
                        if self.isLocationBasedSearch {
                            await self.searchNearby()
                        } else if let center = self.searchCenterLocation {
                            await self.searchAt(center)
                        } else {
                            self.updateFilteredChurches()
                        }
                    } else {
                        self.objectWillChange.send()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    func searchNearby() async {
        guard let location = locationManager.location else {
            if hasPerformedInitialSearch {
                error = "Location not available"
            }
            return
        }
        
        isLoading = true
        error = nil
        hasPerformedInitialSearch = true
        isLocationBasedSearch = true
        searchCenterLocation = location
        
        do {
            let results = try await apiService.searchChurches(near: location, radius: maxDistance * 1609.34)
            churches = results.sorted { church1, church2 in
                church1.distance(from: location) < church2.distance(from: location)
            }
            clearDistanceCache()
            updateFilteredChurches()
            startBackgroundEnrichment(for: churches)
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func searchByZipCode(_ zipCode: String) async {
        isLoading = true
        error = nil
        isLocationBasedSearch = false
        
        do {
            churches = try await apiService.searchChurches(zipCode: zipCode, radius: maxDistance * 1609.34)
            if let firstChurch = churches.first {
                searchCenterLocation = CLLocation(latitude: firstChurch.latitude, longitude: firstChurch.longitude)
            }
            clearDistanceCache()
            updateFilteredChurches()
            startBackgroundEnrichment(for: churches)
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func searchByCity(_ city: String, state: String) async {
        isLoading = true
        error = nil
        isLocationBasedSearch = false
        
        do {
            churches = try await apiService.searchChurches(city: city, state: state, radius: maxDistance * 1609.34)
            if let firstChurch = churches.first {
                searchCenterLocation = CLLocation(latitude: firstChurch.latitude, longitude: firstChurch.longitude)
            }
            clearDistanceCache()
            updateFilteredChurches()
            startBackgroundEnrichment(for: churches)
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func refreshSavedChurches() {
        savedChurches = FavoritesManager.shared.savedChurches()
        objectWillChange.send()
    }

    func toggleFavorite(_ church: Church) {
        FavoritesManager.shared.toggleFavorite(church)
        savedChurches = FavoritesManager.shared.savedChurches()
        churches = churches.map { $0 }
        updateFilteredChurches()
    }

    func searchAt(_ location: CLLocation) async {
        isLoading = true
        error = nil
        isLocationBasedSearch = false
        searchCenterLocation = location
        do {
            churches = try await apiService.searchChurches(near: location, radius: maxDistance * 1609.34)
                .sorted { $0.distance(from: location) < $1.distance(from: location) }
            clearDistanceCache()
            updateFilteredChurches()
            startBackgroundEnrichment(for: churches)
        } catch { self.error = error.localizedDescription }
        isLoading = false
    }

    func updateChurch(_ updated: Church) {
        if let idx = churches.firstIndex(where: { $0.id == updated.id }) {
            churches[idx] = updated
        }
        if let savedIdx = savedChurches.firstIndex(where: { $0.id == updated.id }) {
            savedChurches[savedIdx] = updated
            FavoritesManager.shared.updateFavorite(updated)
        }
        updateFilteredChurches()
    }

    private var enrichmentTask: Task<Void, Never>?

    private func startBackgroundEnrichment(for targetChurches: [Church]) {
        enrichmentTask?.cancel()
        enrichmentTask = Task { [weak self] in
            guard let self = self else { return }
            for church in targetChurches.prefix(15) {
                guard !Task.isCancelled else { break }
                if church.conference != nil && !church.isGenericName && church.givingURL != nil {
                    continue
                }
                let details = await ChurchLiveDetailsService.shared.fetchLiveDetails(
                    cacheKey: church.id,
                    churchName: church.displayName,
                    city: church.city,
                    state: church.state,
                    website: church.website,
                    explicitGivingURL: church.givingURL
                )
                guard !Task.isCancelled else { break }
                var updated = church
                var changed = false
                if let trueName = details.trueCongregationName, !trueName.isEmpty, trueName != updated.name {
                    updated.name = trueName
                    changed = true
                }
                if let conf = details.resolvedConference, updated.conference == nil {
                    updated.conference = conf
                    changed = true
                }
                if let site = details.discoveredWebsite?.absoluteString, updated.website == nil {
                    updated.website = site
                    changed = true
                }
                if let giving = details.givingURL?.absoluteString, updated.givingURL == nil {
                    updated.givingURL = giving
                    changed = true
                }
                if let pastor = details.pastorName, updated.pastorName == nil {
                    updated.pastorName = pastor
                    changed = true
                }
                if let time = details.serviceTimesSummary, updated.sabbathServiceTime == nil {
                    updated.sabbathServiceTime = time
                    changed = true
                }
                if let phone = details.phone, updated.phone == nil {
                    updated.phone = phone
                    changed = true
                }
                if let email = details.email, updated.email == nil {
                    updated.email = email
                    changed = true
                }
                if details.isLikelyClosed {
                    updated.isLikelyInactive = true
                    updated.operationalNotes = details.closedReason
                    changed = true
                }
                if changed {
                    self.updateChurch(updated)
                }
            }
        }
    }

    func sortByDistance() {
        guard let location = referenceLocation else { return }
        churches.sort { church1, church2 in
            church1.distance(from: location) < church2.distance(from: location)
        }
        updateFilteredChurches()
    }
    
    func sortByName() {
        churches.sort { $0.name < $1.name }
        updateFilteredChurches()
    }
    
    func distance(to church: Church) -> String {
        guard let location = referenceLocation else {
            return "Unknown"
        }
        
        if let lastLocation = lastLocationForCache,
           lastLocation.distance(from: location) > 500 {
            distanceCache.removeAll()
        }
        lastLocationForCache = location
        
        let meters: Double
        if let cached = distanceCache[church.id] {
            meters = cached
        } else {
            meters = church.distance(from: location)
            distanceCache[church.id] = meters
        }
        
        let miles = meters / 1609.34
        let distance = settings.distanceUnit.convert(miles)
        let unit = settings.distanceUnit.abbreviation
        
        if distance < 1 {
            return String(format: "%.1f %@", distance, unit)
        } else {
            return String(format: "%.0f %@", distance, unit)
        }
    }
    
    func clearDistanceCache() {
        distanceCache.removeAll()
        lastLocationForCache = nil
    }
}
