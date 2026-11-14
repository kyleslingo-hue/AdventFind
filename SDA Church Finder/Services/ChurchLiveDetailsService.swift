import Foundation
import OSLog

private let logger = Logger(subsystem: "finder.AdventFind", category: "ChurchLiveDetailsService")

/// Live-discovered church details and AdventistGiving metadata fetched when opening any church worldwide.
struct ChurchLiveDetails: Equatable, Hashable {
    var trueCongregationName: String?
    var discoveredWebsite: URL?
    var givingURL: URL?
    var adventistGivingOrgID: String?
    var conferenceFromOrgID: String?
    var conferenceFromWebsite: String?
    var pastorName: String?
    var serviceTimesSummary: String?
    var phone: String?
    var email: String?
    var isLikelyClosed: Bool = false
    var closedReason: String? = nil

    var resolvedConference: String? {
        conferenceFromOrgID ?? conferenceFromWebsite
    }

    var conferenceSourceDescription: String? {
        if let orgID = adventistGivingOrgID, conferenceFromOrgID != nil {
            return "Derived from AdventistGiving OrgID (\(orgID))"
        }
        if conferenceFromWebsite != nil {
            return "Discovered on church website"
        }
        return nil
    }
}

final class ChurchLiveDetailsService {
    static let shared = ChurchLiveDetailsService()

    private struct CacheEntry {
        let details: ChurchLiveDetails
        let timestamp: Date
    }

    private var cache: [String: CacheEntry] = [:]
    private let cacheTTL: TimeInterval = 3600

    private init() {}

    /// Maps North American Division (`AN...`) 4-character AdventistGiving / eAdventist OrgID prefixes to their official Conference.
    static let nadConferenceByPrefix: [String: String] = [
        // Atlantic Union (AN4...)
        "AN44": "Bermuda Conference",
        "AN48": "Greater New York Conference",
        "AN4B": "New York Conference",
        "AN4F": "Northeastern Conference",
        "AN4I": "Northern New England Conference",
        "AN4M": "Southern New England Conference",
        // Seventh-day Adventist Church in Canada (AN6...)
        "AN64": "Alberta Conference",
        "AN68": "British Columbia Conference",
        "AN6B": "Manitoba-Saskatchewan Conference",
        "AN6F": "Maritime Conference",
        "AN6I": "Seventh-day Adventist Church in Newfoundland and Labrador",
        "AN6M": "Ontario Conference",
        "AN6P": "Quebec Conference",
        // Columbia Union (ANB...)
        "ANB4": "Allegheny East Conference",
        "ANB6": "Allegheny West Conference",
        "ANB8": "Chesapeake Conference",
        "ANB9": "Mountain View Conference",
        "ANBB": "New Jersey Conference",
        "ANBF": "Ohio Conference",
        "ANBI": "Pennsylvania Conference",
        "ANBM": "Potomac Conference",
        // Lake Union (ANF...)
        "ANF4": "Illinois Conference",
        "ANF8": "Indiana Conference",
        "ANFB": "Lake Region Conference",
        "ANFF": "Michigan Conference",
        "ANFI": "Wisconsin Conference",
        // Mid-America Union (ANG...)
        "ANG4": "Central States Conference",
        "ANG6": "Dakota Conference",
        "ANG8": "Iowa-Missouri Conference",
        "ANGB": "Kansas-Nebraska Conference",
        "ANGF": "Minnesota Conference",
        "ANGI": "Minnesota Conference",
        "ANGM": "Rocky Mountain Conference",
        // North Pacific Union (ANI...)
        "ANI4": "Alaska Conference",
        "ANI8": "Idaho Conference",
        "ANIB": "Montana Conference",
        "ANIF": "Oregon Conference",
        "ANII": "Upper Columbia Conference",
        "ANIM": "Washington Conference",
        // Pacific Union (ANP...)
        "ANP4": "Arizona Conference",
        "ANP8": "Central California Conference",
        "ANPB": "Hawaii Conference",
        "ANPF": "Nevada-Utah Conference",
        "ANPI": "Northern California Conference",
        "ANPM": "Southeastern California Conference",
        "ANPP": "Southern California Conference",
        // Southern Union (ANT...)
        "ANT4": "Carolina Conference",
        "ANT8": "Florida Conference",
        "ANTB": "Georgia-Cumberland Conference",
        "ANTF": "Gulf States Conference",
        "ANTI": "Kentucky-Tennessee Conference",
        "ANTM": "South Atlantic Conference",
        "ANTP": "South Central Conference",
        "ANTT": "Southeastern Conference",
        // Southwestern Union (ANW...)
        "ANW4": "Arkansas-Louisiana Conference",
        "ANW8": "Oklahoma Conference",
        "ANWB": "Southwest Region Conference",
        "ANWF": "Texas Conference",
        "ANWI": "Texico Conference"
    ]

    /// Official donation portal URL on AdventistGiving when a congregation's direct OrgID is not yet known.
    static func adventistGivingPortalURL() -> URL {
        URL(string: "https://adventistgiving.org/donate")!
    }

    /// Legacy helper returning the reliable official portal URL.
    static func adventistGivingSearchURL(churchName: String = "", city: String = "") -> URL {
        adventistGivingPortalURL()
    }

    /// Cleans generic Adventist noise words to produce search and domain slugs.
    static func cleanCongregationName(_ name: String) -> String {
        name
            .replacingOccurrences(of: #"(?i)\b(seventh-day|seventh\s+day|adventist|adventists|sda|church|company|group|mission|fellowship)\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[^\w\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func fetchLiveDetails(
        cacheKey: String,
        churchName: String = "",
        city: String = "",
        state: String = "",
        website: String?,
        explicitGivingURL: String? = nil,
        now: Date = Date()
    ) async -> ChurchLiveDetails {
        if let cached = cache[cacheKey], now.timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.details
        }

        var result = ChurchLiveDetails()

        // 1. Seed from explicit givingURL if already known
        if let explicitGivingURL, !explicitGivingURL.isEmpty {
            if let orgID = Self.extractAdventistGivingOrgID(from: explicitGivingURL) {
                result.adventistGivingOrgID = orgID
                result.givingURL = Self.normalizedAdventistGivingURL(forOrgID: orgID)
                result.conferenceFromOrgID = Self.conferenceName(forOrgID: orgID)
            } else if let url = URL(string: explicitGivingURL) {
                result.givingURL = url
            }
        }

        // 3. Assemble base websites: explicit website first, or probe candidate Adventist domains
        var sitesToInspect: [URL] = []
        if let website, let base = URL(string: website), ["https", "http"].contains(base.scheme?.lowercased() ?? ""), base.host != nil {
            sitesToInspect.append(base)
            result.discoveredWebsite = base
        } else if !churchName.isEmpty {
            let candidates = buildCandidateWebsites(churchName: churchName, city: city, state: state)
            sitesToInspect.append(contentsOf: candidates)
        }

        for base in sitesToInspect {
            guard let scheme = base.scheme?.lowercased(), ["https", "http"].contains(scheme),
                  let host = base.host else { continue }

            var rootComponents = URLComponents()
            rootComponents.scheme = scheme
            rootComponents.host = host
            rootComponents.port = base.port

            // A. Check structured `/api/config` endpoint (church-core sites)
            var configComponents = rootComponents
            configComponents.path = "/api/config"
            if let configURL = configComponents.url,
               let configData = await downloadData(from: configURL),
               let parsedConfig = Self.parseChurchCoreConfigJSON(from: configData) {
                result.discoveredWebsite = base
                if result.givingURL == nil, let url = parsedConfig.givingURL {
                    result.givingURL = url
                }
                if result.adventistGivingOrgID == nil, let orgID = parsedConfig.adventistGivingOrgID {
                    result.adventistGivingOrgID = orgID
                    result.conferenceFromOrgID = Self.conferenceName(forOrgID: orgID)
                }
                result.serviceTimesSummary = parsedConfig.serviceTimesSummary
                result.phone = parsedConfig.phone
                result.email = parsedConfig.email
                result.pastorName = parsedConfig.pastorName
                break
            }

            // B. Probe homepage and subpages
            var pageCandidates: [URL] = [base]
            if let rootURL = rootComponents.url, rootURL != base {
                pageCandidates.append(rootURL)
            }
            if result.givingURL == nil {
                for sub in ["/give", "/giving", "/online-giving", "/donate"] {
                    var subComp = rootComponents
                    subComp.path = sub
                    if let subURL = subComp.url, !pageCandidates.contains(subURL) {
                        pageCandidates.append(subURL)
                    }
                }
            }

            var verifiedSite = false
            for pageURL in pageCandidates {
                guard let data = await downloadData(from: pageURL),
                      let html = String(data: data, encoding: .utf8) else { continue }

                // Check that this is actually an Adventist church page
                if !html.localizedCaseInsensitiveContains("Adventist") && !html.localizedCaseInsensitiveContains("Sabbath") {
                    continue
                }
                verifiedSite = true
                if result.discoveredWebsite == nil {
                    result.discoveredWebsite = base
                }

                let htmlDetails = Self.extractDetailsFromHTML(html, baseURL: pageURL)
                if result.adventistGivingOrgID == nil, let orgID = htmlDetails.adventistGivingOrgID {
                    result.adventistGivingOrgID = orgID
                    result.givingURL = Self.normalizedAdventistGivingURL(forOrgID: orgID)
                    result.conferenceFromOrgID = Self.conferenceName(forOrgID: orgID)
                }
                if result.givingURL == nil, let givingURL = htmlDetails.givingURL {
                    result.givingURL = givingURL
                }
                if result.conferenceFromWebsite == nil, let conf = htmlDetails.conferenceFromWebsite {
                    result.conferenceFromWebsite = conf
                }
                if result.pastorName == nil, let pastor = htmlDetails.pastorName {
                    result.pastorName = pastor
                }
                if result.serviceTimesSummary == nil, let serviceSummary = htmlDetails.serviceTimesSummary {
                    result.serviceTimesSummary = serviceSummary
                }

                if result.adventistGivingOrgID != nil {
                    break
                }
            }

            if verifiedSite && result.adventistGivingOrgID != nil {
                break
            }
        }

        cache[cacheKey] = CacheEntry(details: result, timestamp: now)
        return result
    }

    private func buildCandidateWebsites(churchName: String, city: String, state: String) -> [URL] {
        let cleanName = Self.cleanCongregationName(churchName).lowercased().replacingOccurrences(of: " ", with: "")
        let cleanCity = city.lowercased().replacingOccurrences(of: #"[^\w]"#, with: "", options: .regularExpression)
        let rawState = state.lowercased().replacingOccurrences(of: #"[^\w]"#, with: "", options: .regularExpression)
        let stateAbbreviations: [String: String] = [
            "alabama": "al", "alaska": "ak", "arizona": "az", "arkansas": "ar", "california": "ca",
            "colorado": "co", "connecticut": "ct", "delaware": "de", "florida": "fl", "georgia": "ga",
            "hawaii": "hi", "idaho": "id", "illinois": "il", "indiana": "in", "iowa": "ia",
            "kansas": "ks", "kentucky": "ky", "louisiana": "la", "maine": "me", "maryland": "md",
            "massachusetts": "ma", "michigan": "mi", "minnesota": "mn", "mississippi": "ms", "missouri": "mo",
            "montana": "mt", "nebraska": "ne", "nevada": "nv", "newhampshire": "nh", "newjersey": "nj",
            "newmexico": "nm", "newyork": "ny", "northcarolina": "nc", "northdakota": "nd", "ohio": "oh",
            "oklahoma": "ok", "oregon": "or", "pennsylvania": "pa", "rhodeisland": "ri", "southcarolina": "sc",
            "southdakota": "sd", "tennessee": "tn", "texas": "tx", "utah": "ut", "vermont": "vt",
            "virginia": "va", "washington": "wa", "westvirginia": "wv", "wisconsin": "wi", "wyoming": "wy"
        ]
        let stateCode = stateAbbreviations[rawState] ?? rawState

        var candidateStrings: [String] = []
        if !cleanName.isEmpty && !stateCode.isEmpty {
            candidateStrings.append("https://\(cleanName)\(stateCode).adventistchurch.org")
        }
        if !cleanCity.isEmpty && !stateCode.isEmpty && cleanCity != cleanName {
            candidateStrings.append("https://\(cleanCity)\(stateCode).adventistchurch.org")
        }
        if !cleanName.isEmpty {
            candidateStrings.append("https://\(cleanName).adventistchurch.org")
            candidateStrings.append("https://\(cleanName)sda.org")
            candidateStrings.append("https://\(cleanName)church.org")
            candidateStrings.append("https://\(cleanName)sda.church")
        }
        if !cleanCity.isEmpty && cleanCity != cleanName {
            candidateStrings.append("https://\(cleanCity)sda.org")
            candidateStrings.append("https://\(cleanCity)sda.church")
        }

        return candidateStrings.compactMap(URL.init(string:))
    }

    /// Extracts an AdventistGiving `OrgID` (e.g. `AN4MJG`, `AN4MCL`, `AN4FBV`) from any URL or HTML snippet.
    nonisolated static func extractAdventistGivingOrgID(from text: String) -> String? {
        let patterns = [
            #"adventistgiving\.org/donate/([A-Za-z0-9]{5,8})"#,
            #"adventistgiving\.org/#/org/([A-Za-z0-9]{5,8})"#,
            #"adventistgiving\.org/[^\s"'<>]*?[?&]OrgID=([A-Za-z0-9]{5,8})"#
        ]
        let nsString = text as NSString
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)),
               match.numberOfRanges >= 2 {
                return nsString.substring(with: match.range(at: 1)).uppercased()
            }
        }
        return nil
    }

    static func normalizedAdventistGivingURL(forOrgID orgID: String) -> URL? {
        URL(string: "https://adventistgiving.org/donate/\(orgID.uppercased())")
    }

    /// Resolves the official Conference name from a 6-character AdventistGiving / eAdventist `OrgID`.
    static func conferenceName(forOrgID orgID: String) -> String? {
        let upper = orgID.uppercased()
        guard upper.count >= 4 else { return nil }
        let prefix = String(upper.prefix(4))
        return nadConferenceByPrefix[prefix]?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parses `/api/config` JSON returned by church-core sites (such as `rockvilletollandsda.church`).
    static func parseChurchCoreConfigJSON(from data: Data) -> ChurchLiveDetails? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let config = (root["data"] as? [String: Any]) ?? root as [String: Any]? else {
            return nil
        }

        var details = ChurchLiveDetails()
        if let churchName = config["church_name"] as? String,
           !churchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !Church.isGenericCongregationName(churchName) {
            details.trueCongregationName = churchName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let donationRaw = config["donation_url"] as? String, !donationRaw.isEmpty {
            if let orgID = extractAdventistGivingOrgID(from: donationRaw) {
                details.adventistGivingOrgID = orgID
                details.givingURL = normalizedAdventistGivingURL(forOrgID: orgID)
                details.conferenceFromOrgID = conferenceName(forOrgID: orgID)
            } else if let url = URL(string: donationRaw) {
                details.givingURL = url
            }
        }

        if let phone = config["contact_phone"] as? String, !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            details.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let email = config["contact_email"] as? String, !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            details.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let services = config["service_times"] as? [[String: Any]], !services.isEmpty {
            let formatted = services.compactMap { item -> String? in
                guard let service = item["service"] as? String,
                      let time = item["time"] as? String,
                      !service.isEmpty, !time.isEmpty else { return nil }
                if let day = item["day"] as? String, !day.isEmpty, day.lowercased() != "saturday" {
                    return "\(service): \(day) \(time)"
                }
                return "\(service) \(time)"
            }
            if !formatted.isEmpty {
                details.serviceTimesSummary = formatted.joined(separator: " · ")
            }
        }

        guard details.givingURL != nil || details.phone != nil || details.email != nil || details.serviceTimesSummary != nil else {
            return nil
        }
        return details
    }

    /// Extracts AdventistGiving OrgID, third-party giving links, Conference name, Pastor name, and service times from church HTML.
    static func extractDetailsFromHTML(_ html: String, baseURL: URL? = nil) -> ChurchLiveDetails {
        var details = ChurchLiveDetails()

        // Extract real congregation name from OpenGraph or HTML title if church was generic
        let namePatterns = [
            #"<meta\s+property=["']og:site_name["']\s+content=["']([^"']+)["']"#,
            #"<meta\s+property=["']og:title["']\s+content=["']([^"']+)["']"#,
            #"<title[^>]*>([^<]+)</title>"#
        ]
        let nsHTML = html as NSString
        for pat in namePatterns {
            guard let regex = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) else { continue }
            if let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: nsHTML.length)),
               match.numberOfRanges >= 2 {
                let candidateRaw = nsHTML.substring(with: match.range(at: 1))
                let cleaned = cleanHTMLTitle(candidateRaw)
                if !cleaned.isEmpty && !Church.isGenericCongregationName(cleaned) && cleaned.count >= 4 && cleaned.count <= 64 {
                    details.trueCongregationName = cleaned
                    break
                }
            }
        }

        if let orgID = extractAdventistGivingOrgID(from: html) {
            details.adventistGivingOrgID = orgID
            details.givingURL = normalizedAdventistGivingURL(forOrgID: orgID)
            details.conferenceFromOrgID = conferenceName(forOrgID: orgID)
        } else {
            // Check for other known church giving platforms (Tithe.ly, Subsplash, Pushpay, PayPal)
            let thirdPartyPattern = #"href=["'](https?://(?:[^"']*?(?:tithe\.ly|pushpay\.com|subsplash\.com|adventistgiving\.org)[^"']*))["']"#
            if let regex = try? NSRegularExpression(pattern: thirdPartyPattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: (html as NSString).length)),
               match.numberOfRanges >= 2 {
                let raw = (html as NSString).substring(with: match.range(at: 1))
                details.givingURL = URL(string: raw)
            }
        }

        let plainText = html
            .replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")

        let lower = plainText.lowercased()
        let expiredDomainPatterns = [
            "domain is for sale", "domain for sale", "buy this domain", "parked free courtesy of",
            "hugedomains.com", "godaddy parking", "this domain has expired"
        ]
        if expiredDomainPatterns.contains(where: { lower.contains($0) }) {
            details.isLikelyClosed = true
            details.closedReason = "Website domain has expired or is listed for sale"
        }

        let closedTextPatterns = [
            "permanently closed", "temporarily closed", "no longer meeting",
            "services have been discontinued", "services discontinued", "congregation has disbanded",
            "this church has closed", "this church is permanently closed"
        ]
        if closedTextPatterns.contains(where: { lower.contains($0) }) {
            details.isLikelyClosed = true
            details.closedReason = "Website indicates congregation may be inactive or closed"
        }

        // Extract Conference name mentioned on the church website (e.g., "Southern New England Conference", "Greater New York Conference")
        let conferencePattern = #"\b((?:[A-Z][a-z]+(?:\s+|-)){1,4}Conference)\b"#
        if let confRegex = try? NSRegularExpression(pattern: conferencePattern) {
            let nsPlain = plainText as NSString
            let matches = confRegex.matches(in: plainText, range: NSRange(location: 0, length: nsPlain.length))
            let ignoredPrefixes = Set(["General", "Annual", "Youth", "Women", "Men", "Family", "Leadership", "Press", "Video", "Audio", "Our", "The", "This", "Local", "State"])
            for match in matches where match.numberOfRanges >= 2 {
                let candidate = nsPlain.substring(with: match.range(at: 1))
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let firstWord = candidate.components(separatedBy: " ").first ?? ""
                if !ignoredPrefixes.contains(firstWord) && candidate.count >= 12 && candidate.count <= 48 {
                    details.conferenceFromWebsite = candidate
                    break
                }
            }
        }

        // Extract Pastor name if listed (e.g. "Pastor Jeremiah Davis", "Lead Pastor: John Smith")
        let pastorPattern = #"\b(?:Lead\s+|Senior\s+|Head\s+|Associate\s+)?Pastor[:\s]+([A-Z][a-z]+(?:\s+[A-Z]\.?)?\s+[A-Z][a-z\-]+)\b"#
        if let pastorRegex = try? NSRegularExpression(pattern: pastorPattern) {
            let nsPlain = plainText as NSString
            if let match = pastorRegex.firstMatch(in: plainText, range: NSRange(location: 0, length: nsPlain.length)),
               match.numberOfRanges >= 2 {
                let name = nsPlain.substring(with: match.range(at: 1))
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let disallowed = ["Profile", "Card", "Message", "Corner", "Desk", "Blog", "Office", "Search", "Contact"]
                if !disallowed.contains(where: { name.localizedCaseInsensitiveContains($0) }) {
                    details.pastorName = "Pastor \(name)"
                }
            }
        }

        if let baseURL {
            let events = ChurchEventsService.extractServiceScheduleFromHTML(html, pageURL: baseURL)
            let sabbathItems = events.compactMap { event -> String? in
                guard let label = event.recurrenceLabel else { return nil }
                let timePart = label.components(separatedBy: "·").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? label
                return "\(event.title) \(timePart)"
            }
            if !sabbathItems.isEmpty {
                details.serviceTimesSummary = sabbathItems.prefix(2).joined(separator: " · ")
            }
        }

        return details
    }

    static func cleanHTMLTitle(_ raw: String) -> String {
        var text = raw
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#038;", with: "&")
            .replacingOccurrences(of: "&#8211;", with: "–")
            .replacingOccurrences(of: "&#8212;", with: "—")
            .replacingOccurrences(of: "&#8217;", with: "’")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        text = text.replacingOccurrences(of: #"(?i)^(welcome\s+(to\s+)?|home\s*(?:\||–|—|-)\s*)"#, with: "", options: .regularExpression)

        let delimiters = CharacterSet(charactersIn: "|:•/–—")
        let parts = text.components(separatedBy: delimiters)
            .flatMap { $0.components(separatedBy: " - ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if parts.count > 1 {
            if let churchPart = parts.first(where: {
                let lower = $0.lowercased()
                return (lower.contains("church") || lower.contains("sda") || lower.contains("adventist") || lower.contains("congregation"))
                    && !Church.isGenericCongregationName($0)
            }) {
                text = churchPart
            } else if let first = parts.first, !first.isEmpty {
                text = first
            }
        }

        return text
            .replacingOccurrences(of: #"(?i)\s*(?:\||–|—|-)\s*(home|official\s+site|official\s+website|welcome|connect|main)\s*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func downloadData(from url: URL) async -> Data? {
        var request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 5)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 27_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json, text/html;q=0.9, */*;q=0.8", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), data.count <= 1_500_000 else {
                return nil
            }
            return data
        } catch {
            logger.debug("Live details fetch skipped for \(url.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
