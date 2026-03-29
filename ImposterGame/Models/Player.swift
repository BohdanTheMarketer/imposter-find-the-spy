import Foundation

struct Player: Identifiable, Hashable {
    let id: UUID
    var name: String
    var isImposter: Bool = false
    var secretWord: String = ""
    var avatarIndex: Int = 0

    init(id: UUID = UUID(), name: String, avatarIndex: Int = 0) {
        self.id = id
        self.name = name
        self.avatarIndex = avatarIndex
    }
}
