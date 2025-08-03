import SwiftUI

struct MessagesView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @Binding var selectedChatId: UUID?
    @Binding var showTabBar: Bool
    @State private var navigationPath = NavigationPath()
    @State private var chatToDelete: Chat?
    @State private var showingDeleteConfirmation = false
    @State private var animate = false
    @State private var userDogs: [Dog] = []
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var dogProfileViewModel: DogProfileViewModel
    
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
                    HStack(spacing: 8) {
                        Image(systemName: "pawprint.fill")
                            .scaleEffect(animate ? 1.5 : 1.0)
                            .foregroundColor(.purple)
                        Text("Messages")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .frame(width: 1000, height: 10)
                    .onAppear { animate = true }
                    
                    ForEach(chatViewModel.chats) { chat in
                        ChatRow(chat: chat, userDogs: userDogs)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                navigationPath.append(chat)
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
            .onAppear {
                Task {
                    await chatViewModel.fetchChatsByCurrentUserId(currentUserId: authService.currentUser!.id)
                    await dogProfileViewModel.fetchUserDogs(userId: authService.currentUser!.id)
                    userDogs = dogProfileViewModel.dogs
                    
                    if let chatId = selectedChatId,
                       let chat = chatViewModel.chats.first(where: { $0.id == chatId }) {
                        navigationPath.append(chat)
                        selectedChatId = nil
                    }
                }
            }
            .onChange(of: selectedChatId) { oldValue, newValue in
                if let chatId = newValue,
                   let chat = chatViewModel.chats.first(where: { $0.id == chatId }) {
                    navigationPath.append(chat)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        selectedChatId = nil
                    }
                } else if newValue != nil {
                    print("❌ Chat not found in chats array - chats count: \(chatViewModel.chats.count)")
                }
            }
            .onChange(of: navigationPath) { oldPath, newPath in
                // Hide tab bar when navigating to chat, show when back to messages list
                withAnimation(.easeInOut(duration: 0.3)) {
                    showTabBar = newPath.isEmpty
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
                    Text("Are you sure you want to delete your conversation between your dog and \(chat.otherDogName)? This action cannot be undone.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationDestination(for: Chat.self) { chat in
                ChatView(
                    showTabBar: $showTabBar,
                    chatViewModel: chatViewModel,
                    selectedChatId: $selectedChatId,
                    chatId: chat.id
                )
            }
        }
    }
}

struct ChatRow: View {
    let chat: Chat
    let userDogs: [Dog]
    
    private func getCurrentDogPhoto() -> String {
        // Find the current dog in userDogs array using currentDogId
        if let currentDogId = chat.currentDogId,
           let currentDog = userDogs.first(where: { $0.id == currentDogId }) {
            return currentDog.photos.first ?? ""
        }
        return ""
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Dog-to-dog conversation display
            HStack(spacing: -8) {
                // Your dog (left, slightly behind) - using current dog's photo
                AcatarView(photoName: getCurrentDogPhoto())
                    .frame(width: 35, height: 35)
                    .zIndex(0)
                
                // Other dog (right, in front) - using their avatar
                AcatarView(photoName: chat.otherDogAvatar)
                    .frame(width: 40, height: 40)
                    .zIndex(1)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Show both dog names
                    Text("\(chat.currentDogName ?? "Your Dog") & \(chat.otherDogName)")
                        .font(.headline)
                        .lineLimit(1)
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
