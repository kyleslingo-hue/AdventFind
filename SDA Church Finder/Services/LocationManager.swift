import Foundation
import CoreLocation
import Combine

@MainActor
class LocationManager: NSObject, ObservableObject {
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var error: LocationError?
    
    private let locationManager = CLLocationManager()
    private static let lastLatKey = "adventfind.lastKnownLatitude"
    private static let lastLonKey = "adventfind.lastKnownLongitude"
    private var isOneShotRequestActive = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            location = locationManager.location ?? Self.loadSavedLocation()
        }
    }

    private static func loadSavedLocation() -> CLLocation? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: lastLatKey) != nil,
              defaults.object(forKey: lastLonKey) != nil else { return nil }
        let lat = defaults.double(forKey: lastLatKey)
        let lon = defaults.double(forKey: lastLonKey)
        guard CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lon)),
              (lat != 0 || lon != 0) else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }

    private static func saveLocation(_ loc: CLLocation) {
        let defaults = UserDefaults.standard
        defaults.set(loc.coordinate.latitude, forKey: lastLatKey)
        defaults.set(loc.coordinate.longitude, forKey: lastLonKey)
    }
    
    deinit {
        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdating() {
        isOneShotRequestActive = false
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdating() {
        isOneShotRequestActive = false
        locationManager.stopUpdatingLocation()
    }
    
    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else { return }
        isOneShotRequestActive = true
        locationManager.startUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            self.location = location
            Self.saveLocation(location)
            if self.isOneShotRequestActive {
                self.isOneShotRequestActive = false
                manager.stopUpdatingLocation()
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.error = .permissionDenied
                case .network:
                    self.error = .networkUnavailable
                default:
                    self.error = .locationUnavailable
                }
            } else {
                self.error = .locationUnavailable
            }
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            
            if manager.authorizationStatus == .authorizedWhenInUse || 
               manager.authorizationStatus == .authorizedAlways {
                self.requestLocation()
            }
        }
    }
}

enum LocationError: Error, LocalizedError {
    case locationUnavailable
    case permissionDenied
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            return "Unable to determine your location"
        case .permissionDenied:
            return "Location permission denied"
        case .networkUnavailable:
            return "Network connection required for location services"
        }
    }
}
