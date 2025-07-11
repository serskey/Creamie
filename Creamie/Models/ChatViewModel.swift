import SwiftUI
import Combine

class ChatViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    
    init() {
        // Initialize with sample chats for demo purposes
        loadSampleChats()
    }
    
    private func loadSampleChats() {
        // Sample chat data - in production, this would come from a backend
        chats = [
            Chat(
                otherUserName: "Sarah Johnson",
                otherUserDogName: "Max",
                otherUserDogPhoto: "dog_Max",
                messages: [
                    Message(text: "Hi! I saw Max on the map. He's adorable!", isFromCurrentUser: true, timestamp: Date().addingTimeInterval(-3600)),
                    Message(text: "Thank you! Your Creamie is so cute too! Would love to set up a playdate", isFromCurrentUser: false, timestamp: Date().addingTimeInterval(-3000)),
                    Message(text: "That would be great! When are you usually at the park?", isFromCurrentUser: true, timestamp: Date().addingTimeInterval(-1800))
                ],
                lastMessageDate: Date().addingTimeInterval(-1800)
            )
        ]
    }
    
    // Find or create a chat with a specific dog owner
    func findOrCreateChat(for dog: Dog) -> Chat {
        // Check if chat already exists
        if let existingChat = chats.first(where: { $0.otherUserDogName == dog.name }) {
            return existingChat
        }
        
        // Create new chat
        let newChat = Chat(
            otherUserName: dog.ownerName ?? "Dog Owner",
            otherUserDogName: dog.name,
            otherUserDogPhoto: dog.photos.first ?? "dog.fill",
            messages: [],
            lastMessageDate: Date()
        )
        
        chats.append(newChat)
        return newChat
    }
    
    // Send a message in a chat
    func sendMessage(_ text: String, in chat: Chat) {
        let newMessage = Message(
            text: text,
            isFromCurrentUser: true,
            timestamp: Date()
        )
        
        if let index = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[index].messages.append(newMessage)
            chats[index].lastMessageDate = Date()
            
            // Sort chats by most recent first
            chats.sort { $0.lastMessageDate > $1.lastMessageDate }
            
            // Simulate a reply after a delay (in production, this would come from backend)
            simulateReply(to: chat)
        }
    }
    
    private func simulateReply(to chat: Chat) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            let replies = [
                "Sounds great! Looking forward to it 🐕",
                "That works for me! See you there",
                "Perfect! My dog loves making new friends",
                "Awesome! What time works best for you?"
            ]
            
            let replyMessage = Message(
                text: replies.randomElement()!,
                isFromCurrentUser: false,
                timestamp: Date()
            )
            
            if let index = self?.chats.firstIndex(where: { $0.id == chat.id }) {
                self?.chats[index].messages.append(replyMessage)
                self?.chats[index].lastMessageDate = Date()
                self?.chats.sort { $0.lastMessageDate > $1.lastMessageDate }
            }
        }
    }
    
    // Delete a chat
    func deleteChat(_ chat: Chat) {
        chats.removeAll { $0.id == chat.id }
    }
    
    // Delete chats by IDs (for batch deletion)
    func deleteChats(withIds chatIds: Set<UUID>) {
        chats.removeAll { chatIds.contains($0.id) }
    }
} 