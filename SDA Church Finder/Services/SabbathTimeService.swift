import Foundation
import CoreLocation
import MapKit
import Solar
import Combine

/// Civil dates belong to the place being viewed, never implicitly to the phone.
final class SabbathTimeService {
    static let shared = SabbathTimeService()
    private init() {}

    func getNextSabbath(for location: CLLocation, now: Date = Date(), timeZone: TimeZone = .current) -> SabbathTime? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        // First consider this week's Friday, including an active Saturday.
        let offset = weekday == 7 ? -1 : (6 - weekday + 7) % 7
        guard let friday = calendar.date(byAdding: .day, value: offset, to: today),
              let interval = interval(friday: friday, location: location, calendar: calendar) else { return nil }
        if now < interval.end { return interval }
        guard let nextFriday = calendar.date(byAdding: .day, value: 7, to: friday) else { return nil }
        return self.interval(friday: nextFriday, location: location, calendar: calendar)
    }

    func getCurrentSabbath(for location: CLLocation, date: Date = Date(), timeZone: TimeZone = .current) -> SabbathTime? {
        guard let sabbath = getNextSabbath(for: location, now: date, timeZone: timeZone),
              sabbath.contains(date) else { return nil }
        return sabbath
    }

    func isCurrentlySabbath(at location: CLLocation, now: Date = Date(), timeZone: TimeZone = .current) -> Bool {
        getCurrentSabbath(for: location, date: now, timeZone: timeZone) != nil
    }

    private func interval(friday: Date, location: CLLocation, calendar: Calendar) -> SabbathTime? {
        guard let saturday = calendar.date(byAdding: .day, value: 1, to: friday),
              let start = sunset(on: friday, at: location, timeZone: calendar.timeZone),
              let end = sunset(on: saturday, at: location, timeZone: calendar.timeZone), start < end else { return nil }
        return SabbathTime(start: start, end: end, location: location, timeZone: calendar.timeZone)
    }

    /// Solar 3 uses UTC date components. Seed it with the requested local civil
    /// date, then place its UTC clock time on that civil day (west of UTC can roll over).
    func sunset(on date: Date, at location: CLLocation, timeZone: TimeZone) -> Date? {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = timeZone
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = local.dateComponents([.year, .month, .day], from: date)
        components.hour = 12
        guard let seed = utc.date(from: components),
              let raw = Solar(for: seed, coordinate: location.coordinate)?.sunset else { return nil }
        for shift in -2...2 {
            let candidate = raw.addingTimeInterval(Double(shift) * 86400)
            if local.isDate(candidate, inSameDayAs: date) { return candidate }
        }
        return nil // No sunset: do not substitute a made-up clock time in polar regions.
    }
}

struct SabbathTime {
    let start: Date
    let end: Date
    let location: CLLocation
    var timeZone: TimeZone = .current

    func contains(_ date: Date) -> Bool { date >= start && date < end }
    var isActive: Bool { contains(Date()) }
    var timeUntilStart: TimeInterval { start.timeIntervalSinceNow }
    var formattedStart: String { formatted(start) }
    var formattedEnd: String { formatted(end) }

    func formattedClock(_ date: Date) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return date.formatted(style)
    }

    private func formatted(_ date: Date) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .shortened)
        style.timeZone = timeZone
        return date.formatted(style)
    }
}

@MainActor
final class SabbathPlace: ObservableObject {
    @Published private(set) var location: CLLocation?
    @Published private(set) var timeZone: TimeZone?
    @Published private(set) var name = "Choose your place"
    @Published private(set) var isResolving = false
    @Published private(set) var error: String?
    private var geocodingRequest: MKReverseGeocodingRequest?
    private var generation = UUID()

    func resolve(_ location: CLLocation, label: String? = nil) async {
        let token = UUID()
        generation = token
        geocodingRequest?.cancel()
        geocodingRequest = nil
        self.location = location
        timeZone = nil
        name = label ?? "Your location"
        error = nil
        isResolving = true
        do {
            guard let request = MKReverseGeocodingRequest(location: location) else {
                throw MKError(.placemarkNotFound)
            }
            geocodingRequest = request
            let mapItems = try await request.mapItems
            guard generation == token else { return }
            guard let place = mapItems.first, let zone = place.timeZone else {
                throw MKError(.placemarkNotFound)
            }
            timeZone = zone
            name = label ?? place.addressRepresentations?.cityName ?? place.name ?? "Your location"
        } catch {
            guard generation == token else { return }
            self.error = "Couldn’t verify this place’s time zone. Try choosing the place again."
        }
        if generation == token {
            geocodingRequest = nil
            isResolving = false
        }
    }
}
