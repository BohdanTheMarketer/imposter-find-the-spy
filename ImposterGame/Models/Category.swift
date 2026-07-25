import Foundation

struct Category: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let icon: String
    let description: String
    let words: [String]
    let imposterHints: [String]
    let isPremium: Bool
    /// True for AI-generated packs created and stored locally by the user (see `CustomWordPackStore`).
    var isCustom: Bool = false
    /// Timestamp used to order custom packs (most recent first). Unused for bundled packs.
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        description: String,
        words: [String],
        imposterHints: [String] = [],
        isPremium: Bool = false,
        isCustom: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.description = description
        self.words = words
        self.imposterHints = imposterHints
        self.isPremium = isPremium
        self.isCustom = isCustom
        self.createdAt = createdAt
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
