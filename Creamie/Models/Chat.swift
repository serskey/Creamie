import Foundation

// Represents a chat conversation between two users
struct Chat: Identifiable, Hashable {
    let id: UUID
    let currentUserId: UUID
    let otherDogId: UUID
    let otherDogName: String
    let otherDogAvatar: String
    var createdAt: Date?
    var messages: [Message]?
    var lastMessageDate: Date = Date()
    
    var safeMessages: [Message] {
        return messages ?? []
    }
    
    var lastMessageText: String {
        guard let messages = messages else { return "" }
        return messages.last?.text ?? ""
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Chat, rhs: Chat) -> Bool {
        lhs.id == rhs.id
    }
}

extension Chat {
    static var empty: Chat {
        Chat(id: UUID(),
             currentUserId: UUID(),
             otherDogId: UUID(),
             otherDogName: "",
             otherDogAvatar: "",
             createdAt: Date(),
             messages: []
        )
    }
}


struct SupabaseChat: Decodable {
    let id: UUID
    let current_user_id: UUID
    let other_dog_id: UUID
    let other_dog_name: String
    let other_dog_avatar: String
    let inserted_at: Date
}


// Represents an individual message in a chat
struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isFromCurrentUser: Bool
    let timestamp: Date
}

struct SupabaseMessagePayload: Decodable {
    let chat_id: UUID
    let sender_id: UUID
    let text: String
    let created_at: String
}

