/**
  This is an original chat window style created by Cursor itself
    Created on 07/08/2025
 
 Styles can be switched b/w this ChatView/FigmaChatView/ModernChatView by updating
 ```
 .navigationDestination(for: Chat.self) { chat in
     FigmaChatView(chatViewModel: chatViewModel, chat: chat)
 }
 ```
 in MessagesView File
 */

import SwiftUI

struct ChatView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    let chat: Chat
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(currentChat.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: currentChat.messages.count) { _, _ in
                    // Scroll to the latest message
                    if let lastMessage = currentChat.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Message input
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(messageText.isEmpty ? .gray : .blue)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
            .background(Color(.systemGray6))
        }
        .navigationTitle(chat.otherUserDogName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        // Show delete confirmation
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Conversation", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.blue)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption)
                    Text(chat.otherUserName)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .alert("Delete Conversation", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                chatViewModel.deleteChat(chat)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete your conversation with \(chat.otherUserDogName)'s owner? This action cannot be undone.")
        }
    }
    
    private var currentChat: Chat {
        chatViewModel.chats.first(where: { $0.id == chat.id }) ?? chat
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        chatViewModel.sendMessage(messageText, in: chat)
        messageText = ""
    }
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(message.isFromCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(message.isFromCurrentUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 250, alignment: message.isFromCurrentUser ? .trailing : .leading)
            
            if !message.isFromCurrentUser {
                Spacer()
            }
        }
    }
} 
