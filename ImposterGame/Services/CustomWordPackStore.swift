import Foundation

/// Persists AI-generated "Custom Pack" categories locally on-device (no cloud sync).
/// Backed by a single JSON file in the app's Documents directory.
@MainActor
final class CustomWordPackStore: ObservableObject {
    static let shared = CustomWordPackStore()

    /// Hard cap requested by product: at most 10 custom packs stored on-device at once.
    static let maxPackCount = 10

    @Published private(set) var packs: [Category] = []

    private let fileURL: URL

    private init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsURL.appendingPathComponent("custom_word_packs.json")
        load()
    }

    var canCreateMore: Bool {
        packs.count < Self.maxPackCount
    }

    var remainingSlots: Int {
        max(0, Self.maxPackCount - packs.count)
    }

    @discardableResult
    func add(_ category: Category) -> Bool {
        guard canCreateMore else { return false }
        // Guarantee the stored flag/timestamp regardless of what the caller passed in.
        let stored = Category(
            id: category.id,
            name: category.name,
            icon: category.icon,
            description: category.description,
            words: category.words,
            imposterHints: category.imposterHints,
            isPremium: true,
            isCustom: true,
            createdAt: Date()
        )
        packs.insert(stored, at: 0)
        persist()
        return true
    }

    func delete(_ category: Category) {
        packs.removeAll { $0.id == category.id }
        persist()
    }

    func delete(id: UUID) {
        packs.removeAll { $0.id == id }
        persist()
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([Category].self, from: data)
            packs = decoded.sorted { $0.createdAt > $1.createdAt }
        } catch {
            // No file yet on first launch, or unreadable — start empty.
            packs = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(packs)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[CustomWordPackStore] Failed to persist custom packs: \(error)")
        }
    }
}
