import SwiftUI
import Combine
import Supabase

struct Chat: Identifiable, Hashable {
    let id: UUID
    let currentUserId: UUID
    let otherDogId: UUID
    let otherDogName: String
    let otherDogAvatar: String
    let currentDogId: UUID?
    let currentDogName: String?
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
             currentDogId: nil,
             currentDogName: nil,
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
    let current_dog_id: UUID?
    let current_dog_name: String?
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

@MainActor
class ChatViewModel: ObservableObject {
    @Published var chats: [Chat] = []

    private let authService = AuthenticationService.shared
    private let messagesTableName = "messages"
    private var messageChannel: RealtimeChannelV2?
    private let chatsTableName = "chats"
    

    init() {
        Task {
            await observeSocketStatus()
        }
    }

    private func observeSocketStatus() async {
        for await status in supabase.realtimeV2.statusChange {
            print("RealtimeV2 Socket status: \(status)")
        }
    }

    func findOrCreateChatBetweenDogs(fromDog: Dog, toDog: Dog) async -> Chat {
        let currentUserId = authService.currentUser!.id
        
        // Fetch all conversations for current user's dogs
        await fetchChatsByCurrentUserId(currentUserId: currentUserId)
        
        // Check if conversation already exists between these two specific dogs
        if let existing = self.chats.first(where: {
            ($0.currentDogId == fromDog.id && $0.otherDogId == toDog.id) ||
            ($0.currentDogId == toDog.id && $0.otherDogId == fromDog.id)
        }) {
            print("Found existing conversation \(existing.id) between \(fromDog.name) and \(toDog.name)")
            return existing
        }

        // Create new conversation between dogs
        let chatId = UUID()
        let newChat = Chat(
            id: chatId,
            currentUserId: currentUserId,
            otherDogId: toDog.id,
            otherDogName: toDog.name,
            otherDogAvatar: toDog.photos.first ?? "",
            currentDogId: fromDog.id,
            currentDogName: fromDog.name,
            createdAt: Date(),
            messages: [],
            lastMessageDate: Date()
        )
            
        // Insert new chat on Supabase
        do {
            try await supabase
                .from(chatsTableName)
                .insert([
                    "id": newChat.id.uuidString,
                    "current_user_id": newChat.currentUserId.uuidString,
                    "other_dog_id": newChat.otherDogId.uuidString,
                    "other_dog_name": newChat.otherDogName,
                    "other_dog_avatar": newChat.otherDogAvatar,
                    "current_dog_id": fromDog.id.uuidString,
                    "current_dog_name": fromDog.name
                ])
                .execute()
            
            chats.append(newChat)
            print("Created new conversation \(chatId) between \(fromDog.name) and \(toDog.name)")
        } catch {
            print("❌ Failed to create chat \(newChat.id) on Supabase:", error)
        }

        return newChat
    }
    
    func fetchChatsByCurrentUserId(currentUserId: UUID) async {
        let currentUserId = authService.currentUser!.id
        
        do {
            // First, get all dogs owned by the current user
            let dogsResponse = try await supabase
                .from("dogs")
                .select("id")
                .eq("owner_id", value: currentUserId)
                .execute()
            
            let dogsData = dogsResponse.data
            let userDogIds = try JSONDecoder().decode([DogId].self, from: dogsData).map { $0.id }
            
            // Now fetch chats where:
            // 1. Current user started the chat (current_user_id), OR
            // 2. Someone wants to chat with any of current user's dogs (other_dog_id)
            var orConditions = ["current_user_id.eq.\(currentUserId)"]
            for dogId in userDogIds {
                orConditions.append("other_dog_id.eq.\(dogId)")
            }
            
            let response = try await supabase
                .from("chats")
                .select("*")
                .or(orConditions.joined(separator: ","))
                .execute()
            
            let data = response.data
            
            let decoder = JSONDecoder()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
            decoder.dateDecodingStrategy = .formatted(formatter)

            let decoded = try decoder.decode([SupabaseChat].self, from: data)

            let loadedChats = decoded.map { supaChat -> Chat in
                let isCurrentUserTheSender = supaChat.current_user_id == currentUserId
                
                if isCurrentUserTheSender {
                    // Current user started the chat, use the stored info
                    return Chat(
                        id: supaChat.id,
                        currentUserId: currentUserId,
                        otherDogId: supaChat.other_dog_id,
                        otherDogName: supaChat.other_dog_name,
                        otherDogAvatar: supaChat.other_dog_avatar,
                        currentDogId: supaChat.current_dog_id,
                        currentDogName: supaChat.current_dog_name,
                        createdAt: supaChat.inserted_at,
                        messages: [],
                        lastMessageDate: supaChat.inserted_at
                    )
                } else {
                    // Someone else started a chat with current user's dog
                    // The "other" dog is actually the sender's dog, "current" dog is yours
                    return Chat(
                        id: supaChat.id,
                        currentUserId: currentUserId,
                        otherDogId: supaChat.current_dog_id ?? supaChat.current_user_id,
                        otherDogName: supaChat.current_dog_name ?? "Other Dog",
                        otherDogAvatar: "", // TODO: Fetch sender's dog avatar
                        currentDogId: supaChat.other_dog_id,
                        currentDogName: supaChat.other_dog_name,
                        createdAt: supaChat.inserted_at,
                        messages: [],
                        lastMessageDate: supaChat.inserted_at
                    )
                }
            }

            self.chats = loadedChats
            
            print("📥 Loaded \(self.chats.count) conversations for user \(currentUserId)")
        } catch {
            print("❌ Failed to load chats: \(error)")
        }
    }
    
    func fetchMessagesByChatId(for chatId: UUID) async {
        let currentUserId = authService.currentUser!.id
        
        do {
            let response = try await supabase
                .from(messagesTableName)
                .select("*")
                .eq("chat_id", value: chatId.uuidString)
                .order("created_at", ascending: true)
                .execute()
            
            let data = response.data
            let decoder = JSONDecoder()
            
            let decoded = try decoder.decode([SupabaseMessagePayload].self, from: data)
            
            let messages = decoded.map { supaMessage -> Message in
                return Message(
                    text: supaMessage.text,
                    isFromCurrentUser: supaMessage.sender_id == currentUserId,
                    timestamp: ISO8601DateFormatter().date(from: supaMessage.created_at) ?? Date()
                )
            }
            
            // Update the specific chat with loaded messages
            if let index = self.chats.firstIndex(where: { $0.id == chatId }) {
                self.chats[index].messages = messages
            }
            
            print("📥 Loaded \(messages.count) messages for chat \(chatId)")
        } catch {
            print("❌ Failed to load messages for chat \(chatId): \(error)")
        }
    }

    func sendMessage(_ text: String, in chat: Chat) {
        let currentUserId = authService.currentUser!.id
        let newMessage = Message(text: text,
                                 isFromCurrentUser: true,
                                 timestamp: Date())

        // load in frontend
        if let index = self.chats.firstIndex(where: { $0.id == chat.id }) {
            if self.chats[index].messages == nil {
                self.chats[index].messages = []
            }
            
            self.chats[index].messages!.append(newMessage)
            self.chats[index].lastMessageDate = newMessage.timestamp
            self.chats.sort { $0.lastMessageDate > $1.lastMessageDate }
        }
        
        // save to backend
        let chatId = chat.id
        let senderId = currentUserId
        let messageId = UUID()

        Task {
            do {
                _ = try await supabase
                    .from(messagesTableName)
                    .insert([
                        "chat_id": chatId.uuidString,
                        "sender_id": senderId.uuidString,
                        "text": text
                    ])
                    .execute()
                print("📤 Message \(messageId) sent for chat \(chatId)")
            } catch {
                print("❌ Failed to send message to chat \(chatId):", error)
            }
        }
    }

    func deleteChat(_ chat: Chat) {
        chats.removeAll { $0.id == chat.id }
        // TODO: Delete backend
    }

    func deleteChats(withIds chatIds: Set<UUID>) {
        chats.removeAll { chatIds.contains($0.id) }
        // TODO: Delete backend
    }

    func subscribeToMessages(for chatID: UUID) {
        let currentUserId = authService.currentUser!.id
        
        Task {
            let channel = supabase.realtimeV2.channel("public:messages")
            self.messageChannel = channel

            Task {
                for await insert in channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "messages",
                    filter: "chat_id=eq.\(chatID.uuidString)"
                ) {
                    do {
                        let newRecord = try insert.decodeRecord(
                            as: SupabaseMessagePayload.self,
                            decoder: JSONDecoder()
                        )

                        let newMessage = Message(
                            text: newRecord.text,
                            isFromCurrentUser: newRecord.sender_id == currentUserId,
                            timestamp: ISO8601DateFormatter().date(from: newRecord.created_at) ?? Date()
                        )

                        if let index = self.chats.firstIndex(where: { $0.id == chatID }) {
                            if chats[index].messages == nil {
                                chats[index].messages = []
                            }
                            
                            self.chats[index].messages?.append(newMessage)
                            self.chats[index].lastMessageDate = newMessage.timestamp
                            self.chats.sort { $0.lastMessageDate > $1.lastMessageDate }
                        }
                    } catch {
                        print("❌ Failed to decode message:", error)
                    }
                }
            }

            await channel.subscribe()
        }
    }
    
    private struct DogId: Decodable {
        let id: UUID
    }
}
