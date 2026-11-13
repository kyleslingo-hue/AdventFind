import XCTest
@testable import AdventFind

final class ChurchEventsServiceTests: XCTestCase {
    private let referenceNow = ISO8601DateFormatter().date(from: "2026-11-13T12:00:00Z")!

    func testParseChurchCoreAPIEventsExtractsRockvilleTollandEvents() {
        let json = """
        {
          "success": true,
          "data": {
            "items": [
              {
                "id": "6b244136-57de-42cf-a8a5-d88f01674510",
                "title": "Plant-based Friendsgiving Dinner",
                "description": "Enjoy healthy food and fellowship",
                "start_time": "2026-11-22T11:00:00Z",
                "end_time": "2026-11-22T15:00:00Z",
                "location": "Rockville Tolland SDA Church",
                "recurring_type": null
              },
              {
                "id": "a320a47c-7364-42a8-bbaa-6361019bc6d2",
                "title": "Bible Study",
                "description": "You are invited to a Weekly Bible Study",
                "start_time": "2026-11-14T16:30:00Z",
                "end_time": "2026-11-14T18:50:00Z",
                "location": "Rockville Tolland SDA",
                "recurring_type": "weekly"
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let events = ChurchEventsService.parseChurchCoreAPIEvents(
            from: json,
            baseURL: URL(string: "https://rockvilletollandsda.church/api/events"),
            now: referenceNow
        )
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].title, "Bible Study")
        XCTAssertTrue(events[0].formattedDateRange.contains("Weekly"))
        XCTAssertEqual(events[0].url?.absoluteString, "https://rockvilletollandsda.church/events/a320a47c-7364-42a8-bbaa-6361019bc6d2")
        XCTAssertEqual(events[1].title, "Plant-based Friendsgiving Dinner")
        XCTAssertEqual(events[1].location, "Rockville Tolland SDA Church")
    }

    func testParseTribeEventsJSONExtractsWordPressEvents() {
        let json = """
        {
          "events": [
            {
              "id": 101,
              "title": "Personal Ministries &amp; Men&#8217;s Ministries",
              "description": "<p>Join us this Sabbath morning.</p>",
              "url": "https://brooklawn.org/event/personal-ministries/",
              "start_date": "2026-11-14 11:00:00",
              "end_date": "2026-11-14 12:00:00",
              "timezone": "America/New_York",
              "all_day": false,
              "venue": {
                "venue": "Brooklawn SDA Church",
                "city": "Bridgeport"
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let events = ChurchEventsService.parseTribeEventsJSON(from: json, now: referenceNow)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].id, "tribe-101")
        XCTAssertEqual(events[0].title, "Personal Ministries & Men’s Ministries")
        XCTAssertEqual(events[0].location, "Brooklawn SDA Church, Bridgeport")
        XCTAssertEqual(events[0].summary, "Join us this Sabbath morning.")
    }

    func testExtractServiceScheduleFromHTMLFindsSabbathAndPrayerTimes() {
        let html = """
        <html><body>
        <div>Sabbath School 9:30 am</div>
        <div>Divine Worship 11:00 am</div>
        <div>Prayer Meeting Wednesday 7:00 pm</div>
        </body></html>
        """
        let events = ChurchEventsService.extractServiceScheduleFromHTML(
            html,
            pageURL: URL(string: "https://schilosda.org/")!,
            now: referenceNow
        )
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events[0].title, "Sabbath School")
        XCTAssertEqual(events[0].formattedDateRange, "Saturdays · 9:30 am")
        XCTAssertEqual(events[1].title, "Worship Service")
        XCTAssertEqual(events[2].title, "Prayer Meeting")
    }

    func testParseICSUnfoldsAndFiltersUpcomingEvents() throws {
        let ics = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//AdventFind//Test//EN
        BEGIN:VEVENT
        UID:past-event@adventfind.test
        DTSTART:20261001T150000Z
        DTEND:20261001T163000Z
        SUMMARY:Past Event
        END:VEVENT
        BEGIN:VEVENT
        UID:friendsgiving-2026@adventfind.test
        DTSTART:20261122T160000Z
        DTEND:20261122T200000Z
        SUMMARY:Plant-based Friendsgiving
          Dinner
        LOCATION:9 Hartford Tpke\\, Tolland\\, CT
        DESCRIPTION:Fellowship and healthy food at the church.
        END:VEVENT
        BEGIN:VEVENT
        UID:christmas-concert-2026@adventfind.test
        DTSTART;VALUE=DATE:20261212
        SUMMARY:Sacred Christmas Concert
        END:VEVENT
        END:VCALENDAR
        """

        let events = ChurchEventsService.parseICS(ics, now: referenceNow)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].id, "friendsgiving-2026@adventfind.test")
        XCTAssertEqual(events[0].title, "Plant-based Friendsgiving Dinner")
        XCTAssertEqual(events[0].location, "9 Hartford Tpke, Tolland, CT")
        XCTAssertFalse(events[0].isAllDay)
        XCTAssertNotNil(events[0].googleCalendarAddURL)

        XCTAssertEqual(events[1].id, "christmas-concert-2026@adventfind.test")
        XCTAssertEqual(events[1].title, "Sacred Christmas Concert")
        XCTAssertTrue(events[1].isAllDay)
    }

    func testDiscoverICSFeedURLSupportsWebcalAndQueryLinks() {
        let base = URL(string: "https://rockvilletollandsda.church/events")!
        let html = #"<a class="ical" href="webcal://rockvilletollandsda.church/events/?ical=1">Subscribe</a>"#
        let feedURL = ChurchEventsService.discoverICSFeedURL(inHTML: html, baseURL: base)
        XCTAssertEqual(feedURL?.absoluteString, "https://rockvilletollandsda.church/events/?ical=1")
    }

    func testParseJSONLDEventsExtractsSchemaOrgEvents() {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@type": "Event",
          "name": "Sabbath Worship & Fellowship",
          "startDate": "2026-11-14T11:00:00-05:00",
          "endDate": "2026-11-14T12:30:00-05:00",
          "location": { "@type": "Place", "name": "Rockville-Tolland SDA Church" },
          "description": "<p>Join us for Sabbath worship.</p>"
        }
        </script>
        </head><body></body></html>
        """
        let events = ChurchEventsService.parseJSONLDEvents(inHTML: html, now: referenceNow)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].title, "Sabbath Worship & Fellowship")
        XCTAssertEqual(events[0].location, "Rockville-Tolland SDA Church")
        XCTAssertEqual(events[0].summary, "Join us for Sabbath worship.")
    }

    func testAdventistChurchConnectDefaultEventsWebURL() {
        let url = ChurchEventsService.shared.defaultEventsWebURL(for: "https://faithct.adventistchurch.org/contact-us/")
        XCTAssertEqual(url?.absoluteString, "https://faithct.adventistchurch.org/events")
    }

    func testExtractAdventistGivingOrgIDAndResolveConference() {
        XCTAssertEqual(
            ChurchLiveDetailsService.extractAdventistGivingOrgID(from: "https://adventistgiving.org/donate/AN4MJG"),
            "AN4MJG"
        )
        XCTAssertEqual(
            ChurchLiveDetailsService.extractAdventistGivingOrgID(from: "https://adventistgiving.org/?OrgID=AN4MI1"),
            "AN4MI1"
        )
        XCTAssertEqual(
            ChurchLiveDetailsService.extractAdventistGivingOrgID(from: "https://adventistgiving.org/#/org/AN4FBV/envelope/start"),
            "AN4FBV"
        )
        XCTAssertEqual(
            ChurchLiveDetailsService.conferenceName(forOrgID: "AN4MJG"),
            "Southern New England Conference"
        )
        XCTAssertEqual(
            ChurchLiveDetailsService.conferenceName(forOrgID: "AN4FBV"),
            "Northeastern Conference"
        )
        XCTAssertEqual(
            ChurchLiveDetailsService.conferenceName(forOrgID: "ANT812"),
            "Florida Conference"
        )
        XCTAssertEqual(
            ChurchLiveDetailsService.conferenceName(forOrgID: "ANPM10"),
            "Southeastern California Conference"
        )
    }

    func testParseChurchCoreConfigJSONExtractsGivingAndServiceDetails() throws {
        let json = """
        {
          "success": true,
          "data": {
            "church_name": "Rockville Tolland SDA Church",
            "contact_phone": "(860) 875-0450",
            "contact_email": "admin@rockvilletollandsda.church",
            "donation_url": "https://adventistgiving.org/donate/AN4MJG",
            "service_times": [
              { "day": "Saturday", "service": "Sabbath School", "time": "9:15 AM" },
              { "day": "Saturday", "service": "Worship Service", "time": "11:00 AM" },
              { "day": "Wednesday", "service": "Prayer Meeting", "time": "6:30 PM" }
            ]
          }
        }
        """.data(using: .utf8)!

        let details = try XCTUnwrap(ChurchLiveDetailsService.parseChurchCoreConfigJSON(from: json))
        XCTAssertEqual(details.adventistGivingOrgID, "AN4MJG")
        XCTAssertEqual(details.givingURL?.absoluteString, "https://adventistgiving.org/donate/AN4MJG")
        XCTAssertEqual(details.resolvedConference, "Southern New England Conference")
        XCTAssertEqual(details.phone, "(860) 875-0450")
        XCTAssertEqual(details.email, "admin@rockvilletollandsda.church")
        XCTAssertEqual(
            details.serviceTimesSummary,
            "Sabbath School 9:15 AM · Worship Service 11:00 AM · Prayer Meeting: Wednesday 6:30 PM"
        )
    }

    func testExtractDetailsFromHTMLDiscoversOrgIDConferenceAndPastor() {
        let html = """
        <html><body>
        <header>
          <a href="https://adventistgiving.org/donate/AN4MB6">Online Giving</a>
        </header>
        <main>
          <p>Welcome to Amesbury Seventh-day Adventist Church, part of the Southern New England Conference.</p>
          <p>Pastor Jeremiah Davis welcomes you every Sabbath.</p>
          <div>Sabbath School 9:30 AM</div>
          <div>Worship Service 11:00 AM</div>
        </main>
        </body></html>
        """
        let details = ChurchLiveDetailsService.extractDetailsFromHTML(
            html,
            baseURL: URL(string: "https://amesburyma.adventistchurch.org/")
        )
        XCTAssertEqual(details.adventistGivingOrgID, "AN4MB6")
        XCTAssertEqual(details.givingURL?.absoluteString, "https://adventistgiving.org/donate/AN4MB6")
        XCTAssertEqual(details.conferenceFromOrgID, "Southern New England Conference")
        XCTAssertEqual(details.conferenceFromWebsite, "Southern New England Conference")
        XCTAssertEqual(details.pastorName, "Pastor Jeremiah Davis")
        XCTAssertEqual(details.serviceTimesSummary, "Sabbath School 9:30 AM · Worship Service 11:00 AM")
    }

    func testTerritoryConferenceResolutionAndSearchURL() {
        // Default conference by state is eliminated so conference remains blank unless AdventistGiving or website supplies it
        let unverifiedDetails = ChurchLiveDetails()
        XCTAssertNil(unverifiedDetails.resolvedConference)

        // AdventistGiving OrgID fills in the conference accurately
        XCTAssertEqual(ChurchLiveDetailsService.conferenceName(forOrgID: "AN4FHO"), "Northeastern Conference")
        XCTAssertEqual(ChurchLiveDetailsService.conferenceName(forOrgID: "AN4MCL"), "Southern New England Conference")
        XCTAssertEqual(ChurchLiveDetailsService.conferenceName(forOrgID: "ANB801"), "Chesapeake Conference")
        XCTAssertEqual(ChurchLiveDetailsService.conferenceName(forOrgID: "ANFF01"), "Michigan Conference")

        let searchURL = ChurchLiveDetailsService.adventistGivingPortalURL()
        XCTAssertEqual(searchURL.absoluteString, "https://adventistgiving.org/donate")

        let cleaned = ChurchLiveDetailsService.cleanCongregationName("Orlando Central Seventh-day Adventist Church")
        XCTAssertEqual(cleaned, "Orlando Central")
    }

    func testGenericCongregationNameAndTrueNameExtraction() {
        XCTAssertTrue(Church.isGenericCongregationName("Seventh-day Adventist Church"))
        XCTAssertTrue(Church.isGenericCongregationName("Seventh Day Adventist Church"))
        XCTAssertTrue(Church.isGenericCongregationName("SDA Church"))
        XCTAssertTrue(Church.isGenericCongregationName("Adventist Church"))
        XCTAssertFalse(Church.isGenericCongregationName("Rockville Tolland SDA Church"))
        XCTAssertFalse(Church.isGenericCongregationName("Orlando Central SDA Church"))

        let html = """
        <html><head>
          <meta property="og:site_name" content="Orlando Central Seventh-day Adventist Church | Home" />
          <title>Orlando Central SDA Church</title>
        </head><body>
          <a href="https://adventistgiving.org/donate/ANT812">Give Online</a>
        </body></html>
        """
        let details = ChurchLiveDetailsService.extractDetailsFromHTML(html)
        XCTAssertEqual(details.trueCongregationName, "Orlando Central Seventh-day Adventist Church")
        XCTAssertEqual(details.adventistGivingOrgID, "ANT812")
        XCTAssertEqual(details.resolvedConference, "Florida Conference")
    }
}
