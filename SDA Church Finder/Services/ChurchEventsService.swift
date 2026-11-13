import Foundation
import OSLog

private let logger = Logger(subsystem: "finder.AdventFind", category: "ChurchEventsService")

struct ChurchEvent: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date?
    let isAllDay: Bool
    let location: String?
    let summary: String?
    let url: URL?
    var recurrenceLabel: String? = nil

    var formattedDateRange: String {
        if let recurrenceLabel, !recurrenceLabel.isEmpty {
            return recurrenceLabel
        }
        if isAllDay {
            return startDate.formatted(date: .abbreviated, time: .omitted)
        }
        let dayPart = startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let startPart = startDate.formatted(date: .omitted, time: .shortened)
        if let endDate, Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            let endPart = endDate.formatted(date: .omitted, time: .shortened)
            return "\(dayPart) · \(startPart) – \(endPart)"
        }
        return "\(dayPart) · \(startPart)"
    }

    var googleCalendarAddURL: URL? {
        var components = URLComponents(string: "https://calendar.google.com/calendar/render")
        let compact = DateFormatter()
        compact.locale = Locale(identifier: "en_US_POSIX")
        compact.timeZone = TimeZone(secondsFromGMT: 0)
        compact.dateFormat = isAllDay ? "yyyyMMdd" : "yyyyMMdd'T'HHmmss'Z'"
        let end = endDate ?? startDate.addingTimeInterval(isAllDay ? 86400 : 3600)
        let dates = "\(compact.string(from: startDate))/\(compact.string(from: end))"
        var queryItems = [
            URLQueryItem(name: "action", value: "TEMPLATE"),
            URLQueryItem(name: "text", value: title),
            URLQueryItem(name: "dates", value: dates)
        ]
        if let location, !location.isEmpty {
            queryItems.append(URLQueryItem(name: "location", value: location))
        }
        if let summary, !summary.isEmpty {
            queryItems.append(URLQueryItem(name: "details", value: summary))
        }
        components?.queryItems = queryItems
        return components?.url
    }
}

final class ChurchEventsService {
    static let shared = ChurchEventsService()

    private struct CacheEntry {
        let events: [ChurchEvent]
        let resolvedCalendarURL: URL?
        let timestamp: Date
    }

    private var cache: [String: CacheEntry] = [:]
    private let cacheTTL: TimeInterval = 3600

    private init() {}

    /// Returns a best-effort web URL where the user can view a church's calendar or events page.
    func defaultEventsWebURL(for website: String?, explicitEventsURL: String? = nil) -> URL? {
        if let explicitEventsURL, let url = URL(string: explicitEventsURL), ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
            return url
        }
        guard let website, let base = URL(string: website), ["https", "http"].contains(base.scheme?.lowercased() ?? ""),
              let host = base.host?.lowercased() else {
            return nil
        }
        var rootComponents = URLComponents()
        rootComponents.scheme = base.scheme
        rootComponents.host = base.host
        rootComponents.port = base.port

        if host.hasSuffix(".adventistchurch.org") {
            rootComponents.path = "/events"
            return rootComponents.url ?? base
        }
        return base
    }

    func fetchUpcomingEvents(
        cacheKey: String,
        website: String?,
        eventsURL: String? = nil,
        calendarFeedURL: String? = nil,
        now: Date = Date()
    ) async -> (events: [ChurchEvent], webCalendarURL: URL?) {
        let fallbackWebURL = defaultEventsWebURL(for: website, explicitEventsURL: eventsURL)

        if let cached = cache[cacheKey], now.timeIntervalSince(cached.timestamp) < cacheTTL {
            return (cached.events, cached.resolvedCalendarURL ?? fallbackWebURL)
        }

        // 1. Check structured JSON APIs & iCal (.ics) feeds first
        let structuredEndpoints = buildStructuredCandidateURLs(website: website, eventsURL: eventsURL, calendarFeedURL: calendarFeedURL)
        for endpoint in structuredEndpoints {
            guard let data = await downloadData(from: endpoint),
                  let text = String(data: data, encoding: .utf8) else { continue }

            // Check /api/events JSON (e.g., Rockville-Tolland church-core API)
            let apiEvents = Self.parseChurchCoreAPIEvents(from: data, baseURL: endpoint, now: now)
            if !apiEvents.isEmpty {
                cache[cacheKey] = CacheEntry(events: apiEvents, resolvedCalendarURL: fallbackWebURL, timestamp: now)
                return (apiEvents, fallbackWebURL)
            }

            // Check WordPress Tribe Events v1 REST API (/wp-json/tribe/events/v1/events)
            let tribeEvents = Self.parseTribeEventsJSON(from: data, now: now)
            if !tribeEvents.isEmpty {
                cache[cacheKey] = CacheEntry(events: tribeEvents, resolvedCalendarURL: fallbackWebURL, timestamp: now)
                return (tribeEvents, fallbackWebURL)
            }

            // Check RFC 5545 iCalendar (.ics)
            if text.contains("BEGIN:VCALENDAR") {
                let parsed = Self.parseICS(text, now: now)
                if !parsed.isEmpty {
                    cache[cacheKey] = CacheEntry(events: parsed, resolvedCalendarURL: fallbackWebURL, timestamp: now)
                    return (parsed, fallbackWebURL)
                }
            }
        }

        // 2. Fetch the church's events/home HTML page to discover embedded .ics links, JSON-LD events, or published weekly service schedules
        let pageURLs = buildHTMLCandidateURLs(website: website, eventsURL: eventsURL)
        for pageURL in pageURLs {
            guard let data = await downloadData(from: pageURL),
                  let html = String(data: data, encoding: .utf8) else { continue }

            if let discoveredICS = Self.discoverICSFeedURL(inHTML: html, baseURL: pageURL),
               let icsData = await downloadData(from: discoveredICS),
               let icsText = String(data: icsData, encoding: .utf8),
               icsText.contains("BEGIN:VCALENDAR") {
                let parsed = Self.parseICS(icsText, now: now)
                if !parsed.isEmpty {
                    cache[cacheKey] = CacheEntry(events: parsed, resolvedCalendarURL: pageURL, timestamp: now)
                    return (parsed, pageURL)
                }
            }

            let jsonLDEvents = Self.parseJSONLDEvents(inHTML: html, now: now)
            if !jsonLDEvents.isEmpty {
                cache[cacheKey] = CacheEntry(events: jsonLDEvents, resolvedCalendarURL: pageURL, timestamp: now)
                return (jsonLDEvents, pageURL)
            }

            let scheduleEvents = Self.extractServiceScheduleFromHTML(html, pageURL: pageURL, now: now)
            if !scheduleEvents.isEmpty {
                cache[cacheKey] = CacheEntry(events: scheduleEvents, resolvedCalendarURL: pageURL, timestamp: now)
                return (scheduleEvents, pageURL)
            }
        }

        cache[cacheKey] = CacheEntry(events: [], resolvedCalendarURL: fallbackWebURL, timestamp: now)
        return ([], fallbackWebURL)
    }

    private func buildStructuredCandidateURLs(website: String?, eventsURL: String?, calendarFeedURL: String?) -> [URL] {
        var urls: [URL] = []
        if let calendarFeedURL, let url = URL(string: calendarFeedURL) {
            urls.append(url)
        }
        guard let root = rootURLComponents(from: website ?? eventsURL) else { return urls }

        let endpoints: [(path: String, query: String?)] = [
            ("/api/events", nil),
            ("/wp-json/tribe/events/v1/events", "per_page=10"),
            ("/events/", "ical=1")
        ]
        for ep in endpoints {
            var c = root
            c.path = ep.path
            c.query = ep.query
            if let u = c.url, !urls.contains(u) {
                urls.append(u)
            }
        }
        return urls
    }

    private func buildHTMLCandidateURLs(website: String?, eventsURL: String?) -> [URL] {
        var urls: [URL] = []
        if let eventsURL, let u = URL(string: eventsURL) {
            urls.append(u)
        }
        if let website, let u = URL(string: website), !urls.contains(u) {
            urls.append(u)
        }
        if let root = rootURLComponents(from: website ?? eventsURL), let rootURL = root.url, !urls.contains(rootURL) {
            urls.append(rootURL)
        }
        return urls
    }

    private func rootURLComponents(from urlString: String?) -> URLComponents? {
        guard let urlString, let base = URL(string: urlString), let scheme = base.scheme, let host = base.host else {
            return nil
        }
        var root = URLComponents()
        root.scheme = scheme
        root.host = host
        root.port = base.port
        return root
    }

    private func downloadData(from url: URL) async -> Data? {
        var request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 8)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 27_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json, text/calendar, text/html;q=0.9, */*;q=0.8", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), data.count <= 2_000_000 else {
                return nil
            }
            return data
        } catch {
            logger.debug("Event fetch skipped for \(url.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Parses `/api/events` JSON returned by church-core sites (such as `rockvilletollandsda.church`).
    static func parseChurchCoreAPIEvents(from data: Data, baseURL: URL? = nil, now: Date = Date()) -> [ChurchEvent] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = root["data"] as? [String: Any],
              let items = dataObj["items"] as? [[String: Any]] else {
            return []
        }

        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoStandard = ISO8601DateFormatter()

        var results: [ChurchEvent] = []
        for item in items {
            guard let title = item["title"] as? String, !title.isEmpty,
                  let startRaw = item["start_time"] as? String,
                  let startDate = isoFractional.date(from: startRaw) ?? isoStandard.date(from: startRaw) ?? parseFlexibleDate(startRaw) else {
                continue
            }
            let endDate = (item["end_time"] as? String).flatMap {
                isoFractional.date(from: $0) ?? isoStandard.date(from: $0) ?? parseFlexibleDate($0)
            }
            let recurring = (item["recurring_type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let cutoff = endDate ?? startDate.addingTimeInterval(3600)

            // Keep upcoming events OR active recurring weekly/daily/biweekly church events
            if cutoff < now.addingTimeInterval(-3600) && (recurring == nil || recurring!.isEmpty) {
                continue
            }

            let id = (item["id"] as? String) ?? "\(title)-\(startDate.timeIntervalSince1970)"
            let location = (item["location"] as? String).map(cleanHTMLText)
            let description = (item["description"] as? String).map(cleanHTMLText)

            var eventURL: URL?
            if let base = baseURL, let scheme = base.scheme, let host = base.host, let rawID = item["id"] as? String {
                eventURL = URL(string: "\(scheme)://\(host)/events/\(rawID)")
            }

            var recurrenceLabel: String?
            if let recurring, !recurring.isEmpty {
                let dayAndTime = ChurchEvent(
                    id: id,
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    isAllDay: false,
                    location: nil,
                    summary: nil,
                    url: nil
                ).formattedDateRange
                recurrenceLabel = "\(dayAndTime) (\(recurring.capitalized))"
            }

            results.append(ChurchEvent(
                id: id,
                title: cleanHTMLText(title),
                startDate: startDate,
                endDate: endDate,
                isAllDay: false,
                location: location,
                summary: description,
                url: eventURL,
                recurrenceLabel: recurrenceLabel
            ))
        }

        return results
            .sorted { $0.startDate < $1.startDate }
            .prefix(8)
            .map { $0 }
    }

    /// Parses WordPress The Events Calendar REST API (`/wp-json/tribe/events/v1/events`) used by AdventistChurch Connect and WordPress churches.
    static func parseTribeEventsJSON(from data: Data, now: Date = Date()) -> [ChurchEvent] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventsArray = root["events"] as? [[String: Any]] else {
            return []
        }

        var results: [ChurchEvent] = []
        for item in eventsArray {
            guard let rawTitle = item["title"] as? String, !rawTitle.isEmpty,
                  let startRaw = item["start_date"] as? String else {
                continue
            }
            let tzIdentifier = item["timezone"] as? String
            let tz = tzIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
            guard let startDate = parseFlexibleDate(startRaw, timeZone: tz) else { continue }
            let endDate = (item["end_date"] as? String).flatMap { parseFlexibleDate($0, timeZone: tz) }
            let cutoff = endDate ?? startDate.addingTimeInterval(3600)
            guard cutoff >= now.addingTimeInterval(-3600) else { continue }

            let id: String
            if let intID = item["id"] as? Int {
                id = "tribe-\(intID)"
            } else if let strID = item["id"] as? String {
                id = "tribe-\(strID)"
            } else {
                id = "\(rawTitle)-\(startDate.timeIntervalSince1970)"
            }

            let isAllDay = (item["all_day"] as? Bool) ?? false
            var location: String?
            if let venue = item["venue"] as? [String: Any] {
                let venueName = (venue["venue"] as? String).map(cleanHTMLText)
                let city = venue["city"] as? String
                location = [venueName, city].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            }
            let description = (item["description"] as? String).map(cleanHTMLText)
            let url = (item["url"] as? String).flatMap(URL.init(string:))

            results.append(ChurchEvent(
                id: id,
                title: cleanHTMLText(rawTitle),
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                location: (location?.isEmpty == false) ? location : nil,
                summary: (description?.isEmpty == false) ? description : nil,
                url: url
            ))
        }

        return results
            .sorted { $0.startDate < $1.startDate }
            .prefix(8)
            .map { $0 }
    }

    /// Extracts published weekly worship/Sabbath School/prayer schedules from church HTML when no calendar feed is populated.
    static func extractServiceScheduleFromHTML(_ html: String, pageURL: URL, now: Date = Date()) -> [ChurchEvent] {
        let stripped = html
            .replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")

        let lines = stripped
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 6 && $0.count <= 140 }

        let patterns: [(title: String, regex: String, defaultDay: String)] = [
            ("Sabbath School", #"(?i)sabbath\s+school[^\d\n]{0,25}(\d{1,2}(?::\d{2})?\s*(?:a\.?m\.?|p\.?m\.?))"#, "Saturdays"),
            ("Worship Service", #"(?i)(?:divine\s+worship|worship\s+service|church\s+service)[^\d\n]{0,25}(\d{1,2}(?::\d{2})?\s*(?:a\.?m\.?|p\.?m\.?))"#, "Saturdays"),
            ("Bible Study", #"(?i)bible\s+study[^\d\n]{0,25}(\d{1,2}(?::\d{2})?\s*(?:a\.?m\.?|p\.?m\.?))"#, "Weekly"),
            ("Prayer Meeting", #"(?i)prayer\s+(?:meeting|service|session)[^\d\n]{0,30}((?:(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)s?\s*(?:at\s*)?)?\d{1,2}(?::\d{2})?\s*(?:a\.?m\.?|p\.?m\.?))"#, "Weekly")
        ]

        var extracted: [ChurchEvent] = []
        var seenTitles = Set<String>()

        for line in lines {
            for item in patterns where !seenTitles.contains(item.title) {
                guard let regex = try? NSRegularExpression(pattern: item.regex),
                      let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)),
                      match.numberOfRanges >= 2 else { continue }
                let timeText = (line as NSString).substring(with: match.range(at: 1))
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                seenTitles.insert(item.title)
                extracted.append(ChurchEvent(
                    id: "schedule-\(item.title.lowercased())",
                    title: item.title,
                    startDate: now,
                    endDate: nil,
                    isAllDay: false,
                    location: nil,
                    summary: cleanHTMLText(line),
                    url: pageURL,
                    recurrenceLabel: "\(item.defaultDay) · \(timeText)"
                ))
            }
        }
        return extracted
    }

    static func discoverICSFeedURL(inHTML html: String, baseURL: URL) -> URL? {
        let patterns = [
            #"href=["'](webcal://[^"']+)["']"#,
            #"href=["'](https?://[^"']*\.ics[^"']*)["']"#,
            #"href=["'](https?://[^"']*[?&]ical=1[^"']*)["']"#,
            #"href=["'](/[^"']*\.ics[^"']*)["']"#,
            #"href=["'](/[^"']*[?&]ical=1[^"']*)["']"#
        ]
        let nsString = html as NSString
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            if let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: nsString.length)),
               match.numberOfRanges >= 2 {
                var raw = nsString.substring(with: match.range(at: 1))
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&#038;", with: "&")
                if raw.lowercased().hasPrefix("webcal://") {
                    raw = "https://" + raw.dropFirst("webcal://".count)
                }
                if let resolved = URL(string: raw, relativeTo: baseURL)?.absoluteURL {
                    return resolved
                }
            }
        }
        return nil
    }

    static func parseJSONLDEvents(inHTML html: String, now: Date = Date()) -> [ChurchEvent] {
        let pattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        var results: [ChurchEvent] = []
        let isoFormatter = ISO8601DateFormatter()

        for match in matches where match.numberOfRanges >= 2 {
            let jsonText = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = jsonText.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) else { continue }
            let items: [[String: Any]]
            if let array = object as? [[String: Any]] {
                items = array
            } else if let dict = object as? [String: Any] {
                if let graph = dict["@graph"] as? [[String: Any]] {
                    items = graph
                } else {
                    items = [dict]
                }
            } else {
                continue
            }

            for item in items {
                let type = (item["@type"] as? String) ?? ""
                guard type.lowercased().contains("event"),
                      let name = item["name"] as? String,
                      let startRaw = item["startDate"] as? String,
                      let startDate = isoFormatter.date(from: startRaw) ?? parseFlexibleDate(startRaw) else {
                    continue
                }
                let endDate = (item["endDate"] as? String).flatMap { isoFormatter.date(from: $0) ?? parseFlexibleDate($0) }
                let cutoff = endDate ?? startDate.addingTimeInterval(7200)
                guard cutoff >= now.addingTimeInterval(-3600) else { continue }

                var locationName: String?
                if let loc = item["location"] as? [String: Any] {
                    locationName = loc["name"] as? String
                } else if let locString = item["location"] as? String {
                    locationName = locString
                }
                let summary = (item["description"] as? String).map(cleanHTMLText)
                let eventURL = (item["url"] as? String).flatMap(URL.init(string:))
                results.append(ChurchEvent(
                    id: "\(name)-\(startDate.timeIntervalSince1970)",
                    title: cleanHTMLText(name),
                    startDate: startDate,
                    endDate: endDate,
                    isAllDay: !startRaw.contains("T"),
                    location: locationName,
                    summary: summary,
                    url: eventURL
                ))
            }
        }
        return results
            .sorted { $0.startDate < $1.startDate }
            .prefix(8)
            .map { $0 }
    }

    /// Parses RFC 5545 iCalendar (.ics) text into upcoming `ChurchEvent` records.
    static func parseICS(_ ics: String, now: Date = Date()) -> [ChurchEvent] {
        let unfolded = ics
            .replacingOccurrences(of: "\r\n ", with: "")
            .replacingOccurrences(of: "\r\n\t", with: "")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\n\t", with: "")

        let lines = unfolded.components(separatedBy: .newlines)
        var events: [ChurchEvent] = []

        var inEvent = false
        var uid: String?
        var summary: String?
        var descriptionText: String?
        var locationText: String?
        var urlString: String?
        var startDate: Date?
        var endDate: Date?
        var isAllDay = false

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line == "BEGIN:VEVENT" {
                inEvent = true
                uid = nil
                summary = nil
                descriptionText = nil
                locationText = nil
                urlString = nil
                startDate = nil
                endDate = nil
                isAllDay = false
                continue
            }
            if line == "END:VEVENT" {
                if inEvent, let title = summary, !title.isEmpty, let start = startDate {
                    let cutoff = endDate ?? start.addingTimeInterval(isAllDay ? 86400 : 3600)
                    if cutoff >= now.addingTimeInterval(-3600) {
                        let eventID = uid ?? "\(title)-\(start.timeIntervalSince1970)"
                        events.append(ChurchEvent(
                            id: eventID,
                            title: cleanHTMLText(unescapeICS(title)),
                            startDate: start,
                            endDate: endDate,
                            isAllDay: isAllDay,
                            location: locationText.map(unescapeICS).map(cleanHTMLText),
                            summary: descriptionText.map(unescapeICS).map(cleanHTMLText),
                            url: urlString.flatMap(URL.init(string:))
                        ))
                    }
                }
                inEvent = false
                continue
            }
            guard inEvent, let colonIndex = line.firstIndex(of: ":") else { continue }
            let propAndParams = String(line[..<colonIndex])
            let value = String(line[line.index(after: colonIndex)...])
            let parts = propAndParams.split(separator: ";")
            guard let propName = parts.first?.uppercased() else { continue }
            let params = parts.dropFirst().map { String($0) }

            switch propName {
            case "UID":
                uid = value
            case "SUMMARY":
                summary = value
            case "DESCRIPTION":
                descriptionText = value
            case "LOCATION":
                locationText = value
            case "URL":
                urlString = value
            case "DTSTART":
                let parsed = parseICSDate(value: value, params: params)
                startDate = parsed.date
                isAllDay = parsed.isAllDay
            case "DTEND":
                endDate = parseICSDate(value: value, params: params).date
            default:
                break
            }
        }

        return events
            .sorted { $0.startDate < $1.startDate }
            .prefix(8)
            .map { $0 }
    }

    private static func parseICSDate(value: String, params: [String]) -> (date: Date?, isAllDay: Bool) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        var tz = TimeZone.current
        var valueIsDateOnly = trimmed.count == 8 && !trimmed.contains("T")

        for param in params {
            let upper = param.uppercased()
            if upper == "VALUE=DATE" {
                valueIsDateOnly = true
            } else if upper.hasPrefix("TZID=") {
                let tzid = String(param.dropFirst(5)).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                if let resolved = TimeZone(identifier: tzid) {
                    tz = resolved
                }
            }
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        if valueIsDateOnly {
            formatter.timeZone = tz
            formatter.dateFormat = "yyyyMMdd"
            return (formatter.date(from: String(trimmed.prefix(8))), true)
        }

        if trimmed.hasSuffix("Z") {
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            return (formatter.date(from: trimmed), false)
        }

        formatter.timeZone = tz
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        return (formatter.date(from: trimmed), false)
    }

    private static func parseFlexibleDate(_ raw: String, timeZone: TimeZone = .current) -> Date? {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                return date
            }
        }
        return nil
    }

    nonisolated private static func unescapeICS(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func cleanHTMLText(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#038;", with: "&")
            .replacingOccurrences(of: "&#8211;", with: "–")
            .replacingOccurrences(of: "&#8212;", with: "—")
            .replacingOccurrences(of: "&#8217;", with: "’")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
