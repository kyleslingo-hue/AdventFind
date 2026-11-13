import Foundation

enum ChurchLanguage {
    /// Name clues are not a verified service schedule. Never infer language from location.
    static func indicated(in name: String) -> [String] {
        let normalized = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let words = Set(normalized.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty })
        let keywords: [(String, Set<String>)] = [
            ("English", ["english"]),
            ("Spanish", ["spanish", "espanol", "espanola", "hispanic", "hispana", "hispano"]),
            ("Portuguese", ["portuguese", "portugues", "portuguesa"]),
            ("French", ["french", "francais", "francaise", "francophone"]),
            ("Korean", ["korean", "한국", "한국어"]),
            ("Chinese", ["chinese", "中文"]),
            ("Mandarin", ["mandarin"]),
            ("Cantonese", ["cantonese"]),
            ("Tagalog", ["tagalog"]),
            ("Haitian Creole", ["kreyol", "kreyòl"]),
            ("Russian", ["russian", "русский"]),
            ("German", ["german", "deutsch", "deutsche"]),
            ("Italian", ["italian", "italiano", "italiana"]),
            ("Arabic", ["arabic"]),
            ("Romanian", ["romanian"]),
            ("ASL", ["asl"])
        ]
        return keywords.compactMap { language, clues in
            words.isDisjoint(with: clues) ? nil : language
        }.sorted()
    }
}
