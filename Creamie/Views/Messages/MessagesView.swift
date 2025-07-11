import SwiftUI

struct MessagesView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @Binding var selectedChatId: UUID?
    @State private var navigationPath = NavigationPath()
    @State private var chatToDelete: Chat?
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if chatViewModel.chats.isEmpty {
                    ContentUnavailableView {
                        Label("No Conversations", systemImage: "message")
                    } description: {
                        Text("Start a conversation by contacting a dog owner from the map")
                    }
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(chatViewModel.chats) { chat in
                        NavigationLink(value: chat) {
                            ChatRow(chat: chat)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                chatToDelete = chat
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Messages")
            .listStyle(PlainListStyle())
            .navigationDestination(for: Chat.self) { chat in
                NewFigmaChatView(chatViewModel: chatViewModel, chat: chat)
            }
        }
        .onChange(of: selectedChatId) { oldValue, newValue in
            if let chatId = newValue,
               let chat = chatViewModel.chats.first(where: { $0.id == chatId }) {
                navigationPath.append(chat)
                // Reset the selectedChatId after navigation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectedChatId = nil
                }
            }
        }
        .alert("Delete Conversation", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                chatToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let chat = chatToDelete {
                    withAnimation {
                        chatViewModel.deleteChat(chat)
                    }
                }
                chatToDelete = nil
            }
        } message: {
            if let chat = chatToDelete {
                Text("Are you sure you want to delete your conversation with \(chat.otherUserDogName)'s owner? This action cannot be undone.")
            }
        }
    }
}

struct ChatRow: View {
    let chat: Chat
    
    var body: some View {
        HStack(spacing: 12) {
            // Dog photo
            Image(chat.otherUserDogPhoto)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.otherUserDogName)
                        .font(.headline)
                    Spacer()
                    Text(chat.lastMessageDate, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(chat.lastMessageText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MessagesView(chatViewModel: ChatViewModel(), selectedChatId: .constant(nil))
} 
