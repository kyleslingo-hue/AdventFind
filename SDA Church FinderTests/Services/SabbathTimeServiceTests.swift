import XCTest
import CoreLocation
@testable import AdventFind

final class SabbathTimeServiceTests: XCTestCase {
    private let service = SabbathTimeService.shared
    private let ny = CLLocation(latitude: 40.7128, longitude: -74.0060)
    private let zone = TimeZone(identifier: "America/New_York")!
    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    func testFridaySunsetBoundaryAndSaturdayRollover() throws {
        let early = date("2026-11-06T12:00:00Z")
        let sabbath = try XCTUnwrap(service.getNextSabbath(for: ny, now: early, timeZone: zone))
        XCTAssertFalse(sabbath.contains(sabbath.start.addingTimeInterval(-1)))
        XCTAssertTrue(sabbath.contains(sabbath.start))
        XCTAssertTrue(sabbath.contains(sabbath.end.addingTimeInterval(-1)))
        XCTAssertFalse(sabbath.contains(sabbath.end))
        let during = try XCTUnwrap(service.getNextSabbath(for: ny, now: sabbath.start.addingTimeInterval(1), timeZone: zone))
        XCTAssertEqual(during.start, sabbath.start)
        let next = try XCTUnwrap(service.getNextSabbath(for: ny, now: sabbath.end, timeZone: zone))
        XCTAssertGreaterThan(next.start.timeIntervalSince(sabbath.start), 6 * 86400)
    }

    func testNewYorkNovemberSunsetClockAndCivilDate() throws {
        let sunset = try XCTUnwrap(service.sunset(on: date("2026-11-06T12:00:00Z"), at: ny, timeZone: zone))
        var cal = Calendar(identifier: .gregorian); cal.timeZone = zone
        XCTAssertEqual(cal.component(.day, from: sunset), 6)
        XCTAssertEqual(cal.component(.hour, from: sunset), 16)
        // NYC early-November sunset is about 4:46pm EST, not UTC or the phone's clock.
        XCTAssertEqual(Double(cal.component(.minute, from: sunset)), 46, accuracy: 3)
    }

    func testWestCoastSunsetUsesFollowingUTCDay() throws {
        let la = CLLocation(latitude: 34.0522, longitude: -118.2437)
        let zone = TimeZone(identifier: "America/Los_Angeles")!
        let sunset = try XCTUnwrap(service.sunset(on: date("2026-07-03T19:00:00Z"), at: la, timeZone: zone))
        var local = Calendar(identifier: .gregorian); local.timeZone = zone
        XCTAssertEqual(local.component(.day, from: sunset), 3)
        XCTAssertEqual(local.component(.hour, from: sunset), 20)
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
        XCTAssertEqual(utc.component(.day, from: sunset), 4)
    }

    func testSydneyFridayAfterUTCMidnightAndAucklandDateLine() throws {
        for (city, lat, lon, localZone) in [("Sydney", -33.8688, 151.2093, "Australia/Sydney"), ("Auckland", -36.8485, 174.7633, "Pacific/Auckland")] {
            let zone = TimeZone(identifier: localZone)!
            let location = CLLocation(latitude: lat, longitude: lon)
            // Friday at 00:30 UTC+11, still Thursday in UTC.
            let now = date("2026-11-05T13:30:00Z")
            let sabbath = try XCTUnwrap(service.getNextSabbath(for: location, now: now, timeZone: zone), city)
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
            XCTAssertEqual(calendar.component(.weekday, from: sabbath.start), 6, city)
            XCTAssertEqual(calendar.component(.day, from: sabbath.start), 6, city)
            XCTAssertEqual(calendar.component(.weekday, from: sabbath.end), 7, city)
            XCTAssertGreaterThan(sabbath.start, now)
        }
    }

    func testDSTUsesOffsetOfEventDate() throws {
        let before = try XCTUnwrap(service.getNextSabbath(for: ny, now: date("2026-10-30T12:00:00Z"), timeZone: zone))
        let after = try XCTUnwrap(service.getNextSabbath(for: ny, now: date("2026-11-06T12:00:00Z"), timeZone: zone))
        XCTAssertEqual(zone.secondsFromGMT(for: before.start), -4 * 3600)
        XCTAssertEqual(zone.secondsFromGMT(for: after.start), -5 * 3600)
        XCTAssertEqual(before.timeZone.identifier, zone.identifier)
        XCTAssertEqual(after.timeZone.identifier, zone.identifier)
    }

    func testNoInventedSunsetInPolarDay() {
        let tromso = CLLocation(latitude: 69.6492, longitude: 18.9553)
        XCTAssertNil(service.getNextSabbath(for: tromso, now: date("2026-06-19T12:00:00Z"), timeZone: TimeZone(identifier: "Europe/Oslo")!))
    }
}
