import XCTest
@testable import AdventFind

@MainActor
final class DirectoryVerificationTests: XCTestCase {
    private var records: [ChurchDirectoryRecord] { ChurchDirectory.shared.records }

    func testSparseUnknownEvidenceDecodesSafely() throws {
        let evidence = try JSONDecoder().decode(FieldVerification.self, from: Data(#"{"status":"unknown"}"#.utf8))
        XCTAssertEqual(evidence.status, .unknown)
        XCTAssertEqual(evidence.sourceURLs, [])
        XCTAssertFalse(evidence.isSourced)
    }

    func testAddressEvidenceAloneCannotRenameAChurch() throws {
        var record = try XCTUnwrap(records.first { $0.id == "ct-brooklawn" })
        record.verification?[DirectoryField.name.rawValue] = .unknown
        let mapChurch = Church(id: "map", name: "Seventh-day Adventist Church", address: "250 Brooklawn Ave", city: "Bridgeport", state: "CT", zipCode: "06604", country: "USA", latitude: 41.18, longitude: -73.21)
        XCTAssertNil(ChurchDirectory(records: [record]).match(for: mapChurch))
        XCTAssertEqual(FieldVerification(status: .confirmed).displayStatus, .needsReview)
    }

    func testMissingEvidenceDoesNotTurnFilledAddressIntoVerifiedLocation() throws {
        var record = try XCTUnwrap(records.first { $0.id == "ct-brooklawn" })
        XCTAssertTrue(record.hasCompleteLocation)
        record.verification = nil
        XCTAssertFalse(record.hasUsableLocation)
        XCTAssertNil(record.directionsURL)
        XCTAssertEqual(record.evidence(for: .phone).status, .unknown)
        XCTAssertEqual(record.addressStatusLabel, "Address needs review")
    }

    func testBundledMigrationPreservesUnknownFieldsAndNoDirectConfirmations() throws {
        XCTAssertEqual(records.count, 198)
        for record in records {
            XCTAssertEqual(record.verification?.count, DirectoryField.allCases.count)
            XCTAssertEqual(record.evidence(for: .worshipTimes).status, .unknown)
            XCTAssertEqual(record.evidence(for: .languages).status, .unknown)
            XCTAssertFalse(record.verification?.values.contains { $0.status == .confirmed } ?? false)
            if !record.hasCompleteLocation {
                XCTAssertFalse(record.hasUsableLocation)
                XCTAssertNil(record.directionsURL)
            }
        }
        let orion = try XCTUnwrap(records.first { $0.id == "ct-orion-spanish" })
        XCTAssertEqual(orion.evidence(for: .address).status, .published)
        XCTAssertEqual(orion.evidence(for: .address).checkedOn, "2026-11-07")
        XCTAssertEqual(orion.evidence(for: .phone).status, .unknown)
    }

    func testConferenceEvidenceIsSeparateFromWebsiteEvidence() throws {
        let record = try XCTUnwrap(records.first { $0.id == "ct-brooklawn" })
        let conference = record.evidence(for: .conference)
        XCTAssertEqual(conference.sourceTitle, "Sabbath Attendance Report 2026")
        XCTAssertEqual(conference.sourcePage, 3)
        XCTAssertEqual(conference.sourceDate, "2026-10-30")
        XCTAssertEqual(conference.sourceSHA256?.count, 64)
        XCTAssertTrue(conference.isSourced)
        XCTAssertFalse(record.evidence(for: .address).sourceURLs.isEmpty)
        XCTAssertNil(record.evidence(for: .address).sourcePage)
    }

    func testCombinedFiltersAndUnknownsRemainAccessible() {
        var filters = DirectoryFilters()
        XCTAssertEqual(records.filter { filters.includes($0) }.count, 198)
        filters.state = DirectoryFilters.unknown
        XCTAssertEqual(records.filter { filters.includes($0) }.count, 68)
        filters = DirectoryFilters()
        filters.conference = DirectoryFilters.unknown
        XCTAssertEqual(records.filter { filters.includes($0) }.count, 14)
        filters = DirectoryFilters()
        filters.state = "CT"
        filters.conference = "Southern New England Conference"
        filters.language = "Spanish"
        let matches = records.filter { filters.includes($0) }
        XCTAssertFalse(matches.isEmpty)
        XCTAssertTrue(matches.allSatisfy { $0.state == "CT" && $0.conference == filters.conference && $0.filterLanguages.contains("Spanish") })
        XCTAssertTrue(records.filter { filters.includes($0, query: "impossible-no-matching-church") }.isEmpty)
        filters = DirectoryFilters()
        XCTAssertFalse(filters.isActive)
        filters.confirmedLanguagesOnly = true
        XCTAssertTrue(records.filter { filters.includes($0) }.isEmpty)
    }

    func testLanguageClueDoesNotBecomeConfirmedWorshipLanguage() throws {
        var record = try XCTUnwrap(records.first { $0.id == "ct-norwalk-spanish" })
        var filters = DirectoryFilters()
        filters.language = "Spanish"
        XCTAssertTrue(filters.includes(record))
        filters.confirmedLanguagesOnly = true
        XCTAssertFalse(filters.includes(record))
        record.worshipLanguages = ["Spanish"]
        record.verification?[DirectoryField.languages.rawValue] = FieldVerification(status: .confirmed)
        XCTAssertFalse(filters.includes(record), "A status without supporting source/date must not count")
        record.verification?[DirectoryField.languages.rawValue] = FieldVerification(status: .published, sourceURLs: record.sourceURLs, checkedOn: "2026-11-07")
        XCTAssertFalse(filters.includes(record), "A published language is not a direct church confirmation")
        record.verification?[DirectoryField.languages.rawValue] = FieldVerification(status: .confirmed, sourceURLs: record.sourceURLs, checkedOn: "2026-11-07")
        XCTAssertTrue(filters.includes(record))
    }

    func testLegacyRecordDecodesWithoutInventingEvidence() throws {
        let record = try XCTUnwrap(records.first)
        let data = try JSONEncoder().encode(record)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "verification")
        let decoded = try JSONDecoder().decode(ChurchDirectoryRecord.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.verification)
        XCTAssertEqual(decoded.evidence(for: .address).status, .unknown)
        XCTAssertFalse(decoded.hasUsableLocation)
    }

    func testEvidenceSurvivesMapEnrichmentAndSaveRoundTrip() throws {
        let church = Church(id: "map-id", name: "Seventh-day Adventist Church", address: "250 Brooklawn Ave", city: "Bridgeport", state: "CT", zipCode: "06604", country: "USA", latitude: 41.18, longitude: -73.21)
        let enriched = ChurchDirectory.shared.enriching([church])[0]
        let restored = try JSONDecoder().decode(Church.self, from: JSONEncoder().encode(enriched))
        XCTAssertEqual(restored.id, church.id)
        XCTAssertEqual(restored.directoryAttribution?.verification?["conference"]?.sourcePage, 3)
        XCTAssertEqual(restored.directoryAttribution?.verification?["address"]?.status, .published)
    }
}
