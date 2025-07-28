import SwiftUI
import Combine
import Supabase

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

    func findOrCreateChat(for selectedDog: Dog) async -> Chat {
        let currentUserId = authService.currentUser!.id
        // fetch all conversations by userId
        await fetchChatsByCurrentUserId(currentUserId: currentUserId)
        
        // existing conversation
        if let existing = self.chats.first(where: { $0.otherDogId == selectedDog.id }) {
            print("There is already a conversation \(existing.id) between user \(currentUserId) and dog \(selectedDog.id)")
            return existing
        }

        // create new conversation
        let chatId = UUID()
        let newChat = Chat(
            id: chatId,
            currentUserId: currentUserId,
            otherDogId: selectedDog.id,
            otherDogName: selectedDog.name,
            otherDogAvatar: selectedDog.photos[0]
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
                    "other_dog_avatar": newChat.otherDogAvatar
                ])
                .execute()
            
            // Only append locally after successful insert
            chats.append(newChat)
            print("Created new conversation \(chatId) between user \(currentUserId) and dog \(selectedDog.id)")
        } catch {
            print("❌ Failed to create chat \(newChat.id) on Supabase:", error)
        }

        return newChat
    }
    
    func fetchChatsByCurrentUserId(currentUserId: UUID) async {
        let currentUserId = authService.currentUser!.id
        
        do {
            let response = try await supabase
                .from("chats")
                .select("*")
                .eq("current_user_id", value: currentUserId)
                .execute()
            
            let data = response.data
            
            let decoder = JSONDecoder()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
            decoder.dateDecodingStrategy = .formatted(formatter)

            let decoded = try decoder.decode([SupabaseChat].self, from: data)

            let loadedChats = decoded.map { supaChat -> Chat in
                return Chat(
                    id: supaChat.id,
                    currentUserId: supaChat.current_user_id,
                    otherDogId: supaChat.other_dog_id,
                    otherDogName: supaChat.other_dog_name,
                    otherDogAvatar: supaChat.other_dog_avatar,
                    messages: [],
                    lastMessageDate: supaChat.inserted_at
                )
            }

            self.chats = loadedChats
            
            print("📥 Loaded \(self.chats.count) conversations from user \(currentUserId)")
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
}
