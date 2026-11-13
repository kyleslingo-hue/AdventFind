import Foundation

enum DirectoryField: String, Codable, CaseIterable, Identifiable {
    case name, address, website, phone, conference, worshipTimes, languages
    var id: String { rawValue }
    var title: String {
        switch self {
        case .name: "Church name"
        case .address: "Meeting address"
        case .website: "Website"
        case .phone: "Phone"
        case .conference: "Conference"
        case .worshipTimes: "Worship times"
        case .languages: "Worship language"
        }
    }
}

enum VerificationStatus: String, Codable {
    case unknown, needsReview, indicated, published, confirmed
    var title: String {
        switch self {
        case .unknown: "Not yet verified"
        case .needsReview: "Needs review"
        case .indicated: "Name clue only"
        case .published: "Published source"
        case .confirmed: "Confirmed with church"
        }
    }
    var supportsUse: Bool { self == .published || self == .confirmed }
}

/// Evidence belongs to one field; checking an address does not confirm a phone or schedule.
struct FieldVerification: Codable, Hashable {
    let status: VerificationStatus
    var sourceURLs: [String] = []
    var sourceTitle: String? = nil
    var sourceDate: String? = nil
    var sourcePage: Int? = nil
    var sourceSHA256: String? = nil
    var checkedOn: String? = nil

    private enum CodingKeys: String, CodingKey {
        case status, sourceURLs, sourceTitle, sourceDate, sourcePage, sourceSHA256, checkedOn
    }
    static let unknown = FieldVerification(status: .unknown)
    var hasEvidence: Bool { !sourceURLs.isEmpty || !(sourceTitle ?? "").isEmpty }
    var isSourced: Bool { status.supportsUse && hasEvidence && !(checkedOn ?? "").isEmpty }
    var displayStatus: VerificationStatus { status.supportsUse && !isSourced ? .needsReview : status }
}

extension FieldVerification {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(status: try values.decodeIfPresent(VerificationStatus.self, forKey: .status) ?? .unknown,
                  sourceURLs: try values.decodeIfPresent([String].self, forKey: .sourceURLs) ?? [],
                  sourceTitle: try values.decodeIfPresent(String.self, forKey: .sourceTitle),
                  sourceDate: try values.decodeIfPresent(String.self, forKey: .sourceDate),
                  sourcePage: try values.decodeIfPresent(Int.self, forKey: .sourcePage),
                  sourceSHA256: try values.decodeIfPresent(String.self, forKey: .sourceSHA256),
                  checkedOn: try values.decodeIfPresent(String.self, forKey: .checkedOn))
    }
}

struct DirectoryFilters: Equatable {
    static let all = "__all__"
    static let unknown = "__unknown__"
    var state = Self.all
    var conference = Self.all
    var language = Self.all
    var confirmedLanguagesOnly = false

    var isActive: Bool { state != Self.all || conference != Self.all || language != Self.all || confirmedLanguagesOnly }

    func includes(_ record: ChurchDirectoryRecord, query: String = "") -> Bool {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchesText = text.isEmpty || ([record.name, record.city, record.street, record.conference ?? ""] + record.aliases)
            .contains { $0.localizedCaseInsensitiveContains(text) }
        let recordState = record.state.isEmpty ? Self.unknown : record.state
        let recordConference = (record.conference?.isEmpty == false) ? record.conference! : Self.unknown
        let languages = confirmedLanguagesOnly ? record.confirmedWorshipLanguages : record.filterLanguages
        return matchesText && (state == Self.all || state == recordState) &&
            (conference == Self.all || conference == recordConference) &&
            (language == Self.all ? (!confirmedLanguagesOnly || !languages.isEmpty) :
             (language == Self.unknown ? languages.isEmpty : languages.contains(language)))
    }
}
