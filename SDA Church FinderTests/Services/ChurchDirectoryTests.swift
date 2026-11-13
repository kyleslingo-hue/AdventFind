import XCTest
@testable import AdventFind

@MainActor
final class ChurchDirectoryTests: XCTestCase {
    private var directory: ChurchDirectory { ChurchDirectory.shared }

    private func church(_ name: String = "Seventh-day Adventist Church", street: String = "250 Brooklawn Avenue", city: String = "Bridgeport", state: String = "CT", zip: String = "06604") -> Church {
        Church(id: "apple-existing-id", name: name, address: street, city: city, state: state,
               zipCode: zip, country: "United States", latitude: 41.18, longitude: -73.21)
    }

    func testBundledResearchLoadsAndHasSources() {
        XCTAssertEqual(directory.records.count, 198)
        XCTAssertEqual(Set(directory.records.map(\.id)).count, directory.records.count)
        for record in directory.records {
            XCTAssertTrue(["CT", "MA", "RI", ""].contains(record.state))
            XCTAssertEqual(record.denomination, "Seventh-day Adventist")
            if record.hasCompleteLocation { XCTAssertFalse(record.sourceURLs.isEmpty) }
            XCTAssertTrue(record.sourceURLs.allSatisfy { URL(string: $0)?.scheme == "https" })
            XCTAssertFalse(record.sourceURLs.contains { $0.contains("eadventist") })
        }
    }

    func testGenericNameReplacedByExactAddressAndSourcePreserved() throws {
        let original = church()
        let result = directory.enriching([original])[0]
        XCTAssertEqual(result.name, "Brooklawn SDA Church")
        XCTAssertEqual(result.id, original.id)
        XCTAssertEqual(result.latitude, original.latitude)
        XCTAssertEqual(result.longitude, original.longitude)
        let source = try XCTUnwrap(result.directoryAttribution)
        XCTAssertEqual(source.originalMapName, original.name)
        XCTAssertEqual(source.recordID, "ct-brooklawn")
        XCTAssertEqual(result.website, "https://brooklawn.org/contact/")
    }

    func testDifferentStateNumberOrStreetNeverGetsRenamed() {
        XCTAssertNil(directory.match(for: church(state: "CA")))
        XCTAssertNil(directory.match(for: church(street: "251 Brooklawn Ave")))
        XCTAssertNil(directory.match(for: church(street: "250 Other Ave")))
        XCTAssertNil(directory.match(for: church(street: "Brooklawn Avenue")))
        XCTAssertNil(directory.match(for: church(city: "New Haven", zip: "06511")))
    }

    func testSharedBuildingDoesNotAssignGenericName() {
        let generic = church(street: "244 East Avenue", city: "Norwalk", zip: "06855")
        XCTAssertNil(directory.match(for: generic))
        XCTAssertEqual(directory.enriching([generic])[0].name, generic.name)
        let spanish = church("Norwalk Spanish Seventh-day Adventist Church", street: "244 East Ave", city: "Norwalk", zip: "06855")
        XCTAssertEqual(directory.match(for: spanish)?.id, "ct-norwalk-spanish")
        let french = church("Mont des Oliviers French SDA Church", street: "244 East Ave", city: "Norwalk", zip: "06855")
        XCTAssertEqual(directory.match(for: french)?.id, "ct-mont-des-oliviers")
    }

    func testKnownUnlistedCohostDoesNotGetOtherCongregationsName() {
        let covenant = church("Covenant Church", street: "94 West Main Street", city: "New Britain", zip: "06051")
        XCTAssertNil(directory.match(for: covenant))
        let generic = church(street: "94 W Main St", city: "New Britain", zip: "06051")
        XCTAssertNil(directory.match(for: generic))
    }

    func testMovedChurchOldAddressNotMatched() {
        XCTAssertNil(directory.match(for: church(street: "1541 Iranistan Ave")))
        XCTAssertNil(directory.match(for: church(street: "57 Derby Avenue", city: "New Haven", zip: "06511")))
        XCTAssertEqual(directory.match(for: church(street: "3160 Park Avenue"))?.id, "ct-ephraim-french")
    }

    func testStreetDirectionsAndAliases() {
        XCTAssertEqual(ChurchDirectory.normalizedStreet(" 76 East Dudley Town Road. "), "76 e dudley town rd")
        let grace = church("Grace SDA Church", street: "870 Prospect Avenue", city: "Hartford", state: "Connecticut", zip: "06105")
        XCTAssertEqual(directory.match(for: grace)?.name, "Prospect Avenue SDA Church")
    }

    func testBorderAddressUsesVerifiedCityOverMapKitTownLabel() {
        // 1535 Forbes Street is right on the East Hartford / Glastonbury town line, so Apple Maps
        // sometimes labels the city as "Glastonbury" while keeping zip "06118".
        let charityFromMaps = church(
            "Charity Seventh-day Adventist Church",
            street: "1535 Forbes St",
            city: "Glastonbury",
            state: "CT",
            zip: "06118"
        )
        let enriched = directory.enriching([charityFromMaps])[0]
        XCTAssertEqual(enriched.name, "Charity Seventh-day Adventist Church")
        XCTAssertEqual(enriched.city, "East Hartford")
        XCTAssertEqual(enriched.zipCode, "06118")
        XCTAssertEqual(enriched.fullAddress, "1535 Forbes Street, East Hartford, CT 06118")
    }

    func testDifferentNamedChurchAtSameAddressIsNotOverwritten() {
        XCTAssertNil(directory.match(for: church("St Paul Catholic Church")))
    }

    func testUnmatchedMapRecordAndLegacySavedDataRemainUsable() throws {
        let unknown = church(street: "999 Unknown Road")
        XCTAssertEqual(directory.enriching([unknown])[0], unknown)
        let data = try JSONEncoder().encode(unknown)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "directoryAttribution")
        let legacy = try JSONDecoder().decode(Church.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.id, unknown.id)
        XCTAssertNil(legacy.directoryAttribution)
    }

    func testGenericCongregationNameDetection() {
        XCTAssertTrue(Church.isGenericCongregationName("Seventh-day Adventist Church"))
        XCTAssertTrue(Church.isGenericCongregationName("Seventh Day Adventist Church"))
        XCTAssertTrue(Church.isGenericCongregationName("Seventh-day Adventist"))
        XCTAssertTrue(Church.isGenericCongregationName("SDA Church"))
        XCTAssertTrue(Church.isGenericCongregationName("Iglesia Adventista del Séptimo Día"))
        XCTAssertTrue(Church.isGenericCongregationName("Eglise Adventiste du Septieme Jour"))

        XCTAssertFalse(Church.isGenericCongregationName("Charity Seventh-day Adventist Church"))
        XCTAssertFalse(Church.isGenericCongregationName("Hope SDA Church"))
        XCTAssertFalse(Church.isGenericCongregationName("Sligo Church"))
        XCTAssertFalse(Church.isGenericCongregationName("Hartford SDA Church"))
    }

    func testChurchDisplayNameFallbacks() {
        let genericChurch = church("Seventh-day Adventist Church", street: "100 Main St", city: "Manchester", state: "CT", zip: "06040")
        XCTAssertEqual(genericChurch.displayName, "Manchester SDA Church")

        let specificChurch = church("South Lancaster Village Church", street: "75 Sawyer St", city: "South Lancaster", state: "MA", zip: "01561")
        XCTAssertEqual(specificChurch.displayName, "South Lancaster Village Church")
    }

    func testWebsiteDomainDeduction() {
        XCTAssertEqual(
            AppleMapsService.deduceCongregationName(fromWebsite: "https://amesburyma.adventistchurch.org"),
            "Amesbury SDA Church"
        )
        XCTAssertEqual(
            AppleMapsService.deduceCongregationName(fromWebsite: "https://sligochurch.org"),
            "Sligo SDA Church"
        )
        XCTAssertEqual(
            AppleMapsService.deduceCongregationName(fromWebsite: "https://forestlake.church"),
            "Forestlake SDA Church"
        )
        XCTAssertEqual(
            AppleMapsService.deduceCongregationName(fromWebsite: "https://hartfordfirstsda.org"),
            "Hartfordfirst SDA Church"
        )
    }

    func testStreetLabelExtraction() {
        XCTAssertEqual(AppleMapsService.extractStreetLabel(from: "250 Brooklawn Ave"), "Brooklawn Ave")
        XCTAssertEqual(AppleMapsService.extractStreetLabel(from: "1052 Blue Hills Ave, Bloomfield, CT"), "Blue Hills Ave")
        XCTAssertEqual(AppleMapsService.extractStreetLabel(from: "Forbes St"), "Forbes St")
    }

    func testHTMLTitleCleaningForCongregationName() {
        XCTAssertEqual(
            ChurchLiveDetailsService.cleanHTMLTitle("Amesbury Seventh-day Adventist Church - Home"),
            "Amesbury Seventh-day Adventist Church"
        )
        XCTAssertEqual(
            ChurchLiveDetailsService.cleanHTMLTitle("Welcome to Forest Lake Church"),
            "Forest Lake Church"
        )
        XCTAssertEqual(
            ChurchLiveDetailsService.cleanHTMLTitle("Sligo Church | Takoma Park, MD"),
            "Sligo Church"
        )
        XCTAssertEqual(
            ChurchLiveDetailsService.cleanHTMLTitle("Hope Seventh-day Adventist Church : Bloomfield, CT"),
            "Hope Seventh-day Adventist Church"
        )
    }

    func testClosedStatusDetectionFromHTML() {
        let closedHTML = "<html><body><h1>Welcome</h1><p>This church is permanently closed. Services have been discontinued.</p></body></html>"
        let details = ChurchLiveDetailsService.extractDetailsFromHTML(closedHTML)
        XCTAssertTrue(details.isLikelyClosed)
        XCTAssertNotNil(details.closedReason)

        let parkingHTML = "<html><body><h1>Dan.com</h1><p>This domain is for sale. Parked free courtesy of GoDaddy.</p></body></html>"
        let parkingDetails = ChurchLiveDetailsService.extractDetailsFromHTML(parkingHTML)
        XCTAssertTrue(parkingDetails.isLikelyClosed)
        XCTAssertNotNil(parkingDetails.closedReason)

        let activeHTML = "<html><head><title>Danbury SDA Church</title></head><body><p>Worship Sabbath 11:00 AM</p></body></html>"
        let activeDetails = ChurchLiveDetailsService.extractDetailsFromHTML(activeHTML)
        XCTAssertFalse(activeDetails.isLikelyClosed)
        XCTAssertNil(activeDetails.closedReason)
    }

    func testInactiveChurchModelProperty() {
        var testChurch = church("South Lancaster Village Church")
        XCTAssertFalse(testChurch.isInactive)

        testChurch.isLikelyInactive = true
        testChurch.operationalNotes = "Closed by user report"
        XCTAssertTrue(testChurch.isInactive)
        XCTAssertEqual(testChurch.operationalNotes, "Closed by user report")
    }

    func testPlainvilleSDAChurchMatchedEnrichedWithAdventistGivingAndConference() throws {
        let mapChurch = Church(
            id: "plainville-apple-map-item",
            name: "Seventh-Day Adventist Church",
            address: "97 Broad St",
            city: "Plainville",
            state: "CT",
            zipCode: "06062",
            country: "United States",
            latitude: 41.6677735,
            longitude: -72.8709827
        )
        let enriched = directory.enriching([mapChurch])[0]
        XCTAssertEqual(enriched.name, "Plainville SDA Church")
        XCTAssertEqual(enriched.conference, "Southern New England Conference")
        XCTAssertEqual(enriched.givingURL, "https://adventistgiving.org/donate/AN4MIQ")
        XCTAssertEqual(enriched.phone, "(860) 747-5867")

        let orgID = ChurchLiveDetailsService.extractAdventistGivingOrgID(from: enriched.givingURL ?? "")
        XCTAssertEqual(orgID, "AN4MIQ")
        XCTAssertEqual(ChurchLiveDetailsService.conferenceName(forOrgID: orgID ?? ""), "Southern New England Conference")

        let location = CLLocation(latitude: 41.6677735, longitude: -72.8709827)
        let nearby = directory.churches(near: location, withinMeters: 5000)
        XCTAssertTrue(nearby.contains(where: { $0.id == "snec-plainville-sda-church" }))
    }

    func testSundayChurchesFilteredOut() {
        XCTAssertFalse(AppleMapsService.isAdventistAffiliation(name: "For His Glory Church Ministries, Inc."))
        XCTAssertFalse(AppleMapsService.isAdventistAffiliation(name: "First Baptist Church"))
        XCTAssertFalse(AppleMapsService.isAdventistAffiliation(name: "Grace Community Church"))
        XCTAssertFalse(AppleMapsService.isAdventistAffiliation(name: "St. Paul Episcopal Church"))
        XCTAssertFalse(AppleMapsService.isAdventistAffiliation(name: "First Presbyterian Church"))
        XCTAssertFalse(AppleMapsService.isAdventistAffiliation(name: "Seventh Day Baptist Cemetery"))

        XCTAssertTrue(AppleMapsService.isAdventistAffiliation(name: "Seventh-day Adventist Church"))
        XCTAssertTrue(AppleMapsService.isAdventistAffiliation(name: "Meriden SDA Church"))
        XCTAssertTrue(AppleMapsService.isAdventistAffiliation(name: "Meriden Spanish SDA Church"))
        XCTAssertTrue(AppleMapsService.isAdventistAffiliation(name: "Iglesia Adventista Del Séptimo Día"))
        XCTAssertTrue(AppleMapsService.isAdventistAffiliation(name: "Nouvelle Jerusalem Haitian SDA Church"))
        XCTAssertTrue(AppleMapsService.isAdventistAffiliation(name: "Three Angels Seventh-day Adventist Church"))
    }

    func testMeridenChurchesBothIncludedNearMeriden() {
        let meridenCenter = CLLocation(latitude: 41.5382, longitude: -72.8071)
        let nearby = directory.churches(near: meridenCenter, withinMeters: 10000)
        let ids = Set(nearby.map(\.id))

        XCTAssertTrue(ids.contains("ct-meriden"), "Meriden SDA Church at 300 Paddock Ave must be included")
        XCTAssertTrue(ids.contains("ct-meriden-spanish"), "Meriden Spanish SDA Church at 24 Columbus Ave must be included")

        let meridenEnglish = nearby.first { $0.id == "ct-meriden" }
        XCTAssertEqual(meridenEnglish?.name, "Meriden SDA Church")
        XCTAssertEqual(meridenEnglish?.address, "300 Paddock Ave")
        XCTAssertEqual(meridenEnglish?.givingURL, "https://adventistgiving.org/donate/AN4MGG")

        let meridenSpanish = nearby.first { $0.id == "ct-meriden-spanish" }
        XCTAssertEqual(meridenSpanish?.name, "Meriden Spanish SDA Church")
        XCTAssertEqual(meridenSpanish?.address, "24 Columbus Ave")
        XCTAssertEqual(meridenSpanish?.givingURL, "https://adventistgiving.org/donate/AN4MGL")
    }
}
