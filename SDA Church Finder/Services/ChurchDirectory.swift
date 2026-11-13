import Foundation
import OSLog
import CoreLocation

struct DirectoryAttribution: Codable, Hashable {
    let recordID: String
    let sourceURLs: [String]
    let checkedOn: String
    let originalMapName: String
    let reviewNotes: String
    var verification: [String: FieldVerification]? = nil
}

struct ChurchDirectoryRecord: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let street: String
    let city: String
    let state: String
    let postalCode: String
    let website: String
    var phone: String? = nil
    let sourceURLs: [String]
    let checkedOn: String
    let denomination: String
    let aliases: [String]
    let reviewNotes: String
    let allowsAddressOnlyMatch: Bool
    var conference: String? = nil
    var conferenceSourcePage: Int? = nil

    var verification: [String: FieldVerification]? = nil
    var worshipLanguages: [String]? = nil
    var eventsURL: String? = nil
    var calendarFeedURL: String? = nil
    var givingURL: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil

    func asChurch(fallbackCoordinate: CLLocationCoordinate2D? = nil) -> Church? {
        guard let lat = latitude ?? fallbackCoordinate?.latitude,
              let lon = longitude ?? fallbackCoordinate?.longitude else {
            return nil
        }
        var church = Church(
            id: id,
            name: name,
            address: street,
            city: city,
            state: state,
            zipCode: postalCode,
            country: "United States",
            latitude: lat,
            longitude: lon,
            phone: evidence(for: .phone).isSourced ? phone : nil,
            website: evidence(for: .website).isSourced ? website : nil,
            email: nil,
            pastorName: nil,
            languages: indicatedLanguages,
            sabbathServiceTime: nil,
            weeklyServices: [],
            isAccessible: false,
            photoURLs: []
        )
        church.conference = evidence(for: .conference).isSourced ? conference : nil
        church.eventsURL = evidence(for: .website).isSourced ? eventsURL : nil
        church.calendarFeedURL = evidence(for: .website).isSourced ? calendarFeedURL : nil
        church.givingURL = givingURL
        church.directoryAttribution = DirectoryAttribution(
            recordID: id,
            sourceURLs: sourceURLs,
            checkedOn: checkedOn,
            originalMapName: name,
            reviewNotes: reviewNotes,
            verification: verification
        )
        return church
    }

    func evidence(for field: DirectoryField) -> FieldVerification {
        verification?[field.rawValue] ?? .unknown
    }

    var hasCompleteLocation: Bool { !street.isEmpty && !city.isEmpty && !state.isEmpty }
    var hasUsableLocation: Bool { hasCompleteLocation && evidence(for: .address).isSourced }
    var confirmedWorshipLanguages: [String] {
        let evidence = evidence(for: .languages)
        guard evidence.status == .confirmed, evidence.isSourced else { return [] }
        return worshipLanguages ?? []
    }
    var sourcedWorshipLanguages: [String] {
        evidence(for: .languages).isSourced ? (worshipLanguages ?? []) : []
    }
    var filterLanguages: [String] { Array(Set(sourcedWorshipLanguages + indicatedLanguages)).sorted() }
    var addressStatusLabel: String {
        guard hasCompleteLocation else { return "Address not yet listed" }
        let evidence = evidence(for: .address)
        guard evidence.isSourced else { return "Address needs review" }
        return evidence.status == .confirmed ? "Address confirmed with church" : "Address from published source"
    }

    var indicatedLanguages: [String] { ChurchLanguage.indicated(in: ([name] + aliases).joined(separator: " ")) }

    var fullAddress: String {
        guard hasCompleteLocation else { return "Address not yet listed" }
        return "\(street), \(city), \(state) \(postalCode)".trimmingCharacters(in: .whitespaces)
    }
    var directionsURL: URL? {
        guard hasUsableLocation else { return nil }
        var url = URLComponents(string: "https://maps.apple.com/")
        url?.queryItems = [URLQueryItem(name: "daddr", value: fullAddress)]
        return url?.url
    }
}

struct ChurchDirectoryDocument: Decodable {
    let schemaVersion: Int
    let records: [ChurchDirectoryRecord]
}

extension Notification.Name {
    static let churchDirectoryDidUpdate = Notification.Name("churchDirectoryDidUpdate")
}

/// A reviewed local directory. The app never scrapes websites at search time.
struct ChurchDirectory {
    private static let lock = NSLock()
    private static var _shared: ChurchDirectory = ChurchDirectory.load()

    static var shared: ChurchDirectory {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _shared
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _shared = newValue
        }
    }

    static func reload(cacheDirectory: URL? = nil, bundle: Bundle = .main) {
        shared = ChurchDirectory.load(cacheDirectory: cacheDirectory, bundle: bundle)
        NotificationCenter.default.post(name: .churchDirectoryDidUpdate, object: nil)
    }

    let records: [ChurchDirectoryRecord]

    static func load(cacheDirectory: URL? = nil, bundle: Bundle = .main) -> ChurchDirectory {
        if let cacheDirectory = cacheDirectory {
            if let dir = loadFromDirectory(cacheDirectory) {
                return dir
            }
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let defaultCache = appSupport?.appendingPathComponent("AdventFind/DirectoryCache/churches", isDirectory: true),
           FileManager.default.fileExists(atPath: defaultCache.path) {
            if let dir = loadFromDirectory(defaultCache) {
                return dir
            }
        }
        return loadBundled(bundle: bundle)
    }

    private static func loadFromDirectory(_ dirURL: URL) -> ChurchDirectory? {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "json" && $0.lastPathComponent != "manifest.json" }
            guard !fileURLs.isEmpty else { return nil }

            var documents: [(filename: String, records: [ChurchDirectoryRecord])] = []
            for fileURL in fileURLs {
                guard let data = try? Data(contentsOf: fileURL),
                      let document = try? JSONDecoder().decode(ChurchDirectoryDocument.self, from: data),
                      document.schemaVersion == 1 else {
                    continue
                }
                documents.append((fileURL.lastPathComponent, document.records))
            }
            guard !documents.isEmpty else { return nil }
            return assembleCombined(documents: documents)
        } catch {
            return nil
        }
    }

    private static func loadBundled(bundle: Bundle = .main) -> ChurchDirectory {
        do {
            guard let url = bundle.url(forResource: "connecticut-churches", withExtension: "json")
                    ?? bundle.url(forResource: "connecticut-churches", withExtension: "json", subdirectory: "Resources") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let document = try JSONDecoder().decode(ChurchDirectoryDocument.self, from: Data(contentsOf: url))
            guard document.schemaVersion == 1 else { throw CocoaError(.coderReadCorrupt) }
            let snecRecords = loadSNEC(bundle: bundle)
            return assembleCombined(documents: [
                ("connecticut-churches.json", document.records),
                ("snec-churches.json", snecRecords)
            ])
        } catch {
            Logger(subsystem: "finder.AdventFind", category: "ChurchDirectory")
                .error("Bundled directory unavailable: \(error.localizedDescription, privacy: .public)")
            return ChurchDirectory(records: [])
        }
    }

    private static func assembleCombined(documents: [(filename: String, records: [ChurchDirectoryRecord])]) -> ChurchDirectory {
        var baseDocs: [ChurchDirectoryRecord] = []
        var conferenceDocs: [ChurchDirectoryRecord] = []

        for doc in documents {
            if doc.filename.contains("connecticut") {
                baseDocs.append(contentsOf: doc.records)
            } else {
                conferenceDocs.append(contentsOf: doc.records)
            }
        }

        let baseByID = Dictionary(uniqueKeysWithValues: baseDocs.map { ($0.id, $0) })
        let confIDs = Set(conferenceDocs.map(\.id))

        let enrichedConf = conferenceDocs.map { record -> ChurchDirectoryRecord in
            guard let base = baseByID[record.id] else { return record }
            var merged = record
            if merged.givingURL == nil { merged.givingURL = base.givingURL }
            if merged.latitude == nil { merged.latitude = base.latitude }
            if merged.longitude == nil { merged.longitude = base.longitude }
            if merged.eventsURL == nil { merged.eventsURL = base.eventsURL }
            if merged.phone == nil { merged.phone = base.phone }
            if merged.conference == nil { merged.conference = base.conference }
            return merged
        }

        let remainingBase = baseDocs.filter { !confIDs.contains($0.id) }
        let combined = remainingBase + enrichedConf
        return ChurchDirectory(records: combined.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
    }

    private static func loadSNEC(bundle: Bundle) -> [ChurchDirectoryRecord] {
        do {
            guard let url = bundle.url(forResource: "snec-churches", withExtension: "json")
                    ?? bundle.url(forResource: "snec-churches", withExtension: "json", subdirectory: "Resources") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let document = try JSONDecoder().decode(ChurchDirectoryDocument.self, from: Data(contentsOf: url))
            guard document.schemaVersion == 1 else { throw CocoaError(.coderReadCorrupt) }
            return document.records
        } catch {
            Logger(subsystem: "finder.AdventFind", category: "ChurchDirectory")
                .error("SNEC directory unavailable: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func enriching(_ churches: [Church]) -> [Church] {
        churches.map { church in
            guard let record = match(for: church) else { return church }
            var result = church
            result.name = record.name
            if record.hasUsableLocation {
                result.address = record.street
                result.city = record.city
                result.state = record.state
                if !record.postalCode.isEmpty {
                    result.zipCode = record.postalCode
                }
            }
            if record.evidence(for: .conference).isSourced { result.conference = record.conference }
            result.languages = record.indicatedLanguages
            if record.evidence(for: .website).isSourced {
                result.website = record.website
                result.eventsURL = record.eventsURL
                result.calendarFeedURL = record.calendarFeedURL
            }
            if let giving = record.givingURL, !giving.isEmpty {
                result.givingURL = giving
            }
            // Use the church-published contact when available; otherwise preserve Maps.
            if record.evidence(for: .phone).isSourced { result.phone = record.phone ?? church.phone }
            result.directoryAttribution = DirectoryAttribution(recordID: record.id, sourceURLs: record.sourceURLs,
                checkedOn: record.checkedOn, originalMapName: church.directoryAttribution?.originalMapName ?? church.name,
                reviewNotes: record.reviewNotes, verification: record.verification)
            return result
        }
    }

    func churches(near location: CLLocation, withinMeters radius: Double) -> [Church] {
        records.compactMap { record in
            guard record.hasUsableLocation, let church = record.asChurch() else { return nil }
            let churchLocation = CLLocation(latitude: church.latitude, longitude: church.longitude)
            guard churchLocation.distance(from: location) <= radius else { return nil }
            return church
        }
    }

    func match(for church: Church) -> ChurchDirectoryRecord? {
        // A street number and the whole normalized street are required. Never infer
        // a name from proximity, city alone, or a previous (possibly moved) address.
        let street = Self.normalizedStreet(church.address)
        let state = Self.normalizedState(church.state)
        guard street.first?.isNumber == true, ["ct", "ma", "ri"].contains(state),
              ["", "us", "usa", "united states", "united states of america"].contains(Self.words(church.country)) else { return nil }
        let candidates = records.filter { record in
            record.hasUsableLocation && record.evidence(for: .name).isSourced && Self.normalizedState(record.state) == state && Self.normalizedStreet(record.street) == street &&
            (Self.words(record.city) == Self.words(church.city) ||
             (!record.postalCode.isEmpty && String(record.postalCode.prefix(5)) == String(church.zipCode.prefix(5))))
        }
        guard !candidates.isEmpty else { return nil }
        let mapTokens = Self.nameTokens(church.name, city: church.city)
        if mapTokens.isEmpty {
            guard candidates.count == 1, candidates[0].allowsAddressOnlyMatch else { return nil }
            return candidates[0]
        }
        // At shared addresses only a congregation-specific name can resolve a match.
        let named = candidates.filter { record in
            ([record.name] + record.aliases).contains { name in
                let tokens = Self.nameTokens(name, city: record.city)
                return !tokens.isEmpty && (tokens.isSubset(of: mapTokens) || mapTokens.isSubset(of: tokens))
            }
        }
        return named.count == 1 ? named[0] : nil
    }

    static func normalizedStreet(_ text: String) -> String {
        let replacements = ["street": "st", "avenue": "ave", "road": "rd", "drive": "dr", "boulevard": "blvd",
                            "turnpike": "tpke", "lane": "ln", "court": "ct", "place": "pl", "terrace": "ter",
                            "north": "n", "south": "s", "east": "e", "west": "w", "highway": "hwy"]
        return words(text).split(separator: " ").map { replacements[String($0)] ?? String($0) }.joined(separator: " ")
    }

    private static func normalizedState(_ text: String) -> String {
        let value = words(text)
        return ["connecticut": "ct", "massachusetts": "ma", "rhode island": "ri"][value] ?? value
    }

    private static func words(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func nameTokens(_ name: String, city: String) -> Set<String> {
        let noise = Set(["seventh", "day", "adventist", "adventists", "church", "sda", "7th", "the", "of", "in", "company", "group", "mission", "connecticut", "ct"])
            .union(words(city).split(separator: " ").map(String.init))
        return Set(words(name).split(separator: " ").map(String.init)).subtracting(noise)
    }
}
