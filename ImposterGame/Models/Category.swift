import Foundation

struct Category: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let icon: String
    let description: String
    let words: [String]
    let imposterHints: [String]
    let isPremium: Bool

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        description: String,
        words: [String],
        imposterHints: [String] = [],
        isPremium: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.description = description
        self.words = words
        self.imposterHints = imposterHints
        self.isPremium = isPremium
    }
}

struct WordPack: Codable {
    let category: String
    let icon: String
    let description: String
    let isPremium: Bool
    let words: [String]
    let imposterHints: [String]?
}
