import Foundation

// Represents a chat conversation between two users
struct Chat: Identifiable, Hashable {
    let id = UUID()
    let otherUserName: String
    let otherUserDogName: String
    let otherUserDogPhoto: String
    var messages: [Message]
    var lastMessageDate: Date
    
    var lastMessageText: String {
        messages.last?.text ?? ""
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Chat, rhs: Chat) -> Bool {
        lhs.id == rhs.id
    }
}

// Represents an individual message in a chat
struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isFromCurrentUser: Bool
    let timestamp: Date
} 