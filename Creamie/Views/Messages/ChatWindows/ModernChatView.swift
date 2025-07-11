/**
  This is a more practical implementation which combines Figma design with current project implementation
    Created on 07/10/2025
 
 ✅ Uses my existing Chat and Message models
 ✅ Integrates with my ChatViewModel
 ✅ Groups consecutive messages intelligently
 ✅ Shows timestamps based on time intervals
 ✅ Maintains the Figma design aesthetics
 */


import SwiftUI

struct ModernChatView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    let chat: Chat
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            ChatHeader(
                userName: chat.otherUserName,
                userStatus: "Active 11m ago",
                onBackTapped: { dismiss() },
                onPhoneTapped: { /* Handle phone call */ },
                onVideoTapped: { /* Handle video call */ }
            )
            
            // Chat Messages
            chatMessages
            
            // Input Area
            ChatInputArea(
                messageText: $messageText,
                isTextFieldFocused: $isTextFieldFocused,
                onSendMessage: sendMessage
            )
        }
        .background(Color.white)
        .navigationBarHidden(true)
    }
    
    // MARK: - Chat Messages
    private var chatMessages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if currentChat.messages.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Spacer(minLength: 100)
                            Text("Start a conversation")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    } else {
                        // Group messages by sender and time proximity
                        let messageGroups = groupMessages(currentChat.messages)
                        
                        ForEach(Array(messageGroups.enumerated()), id: \.offset) { index, group in
                            MessageGroupView(
                                group: group,
                                showAvatar: !group.isFromCurrentUser,
                                showTimestamp: shouldShowTimestamp(for: index, in: messageGroups)
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, index == 0 ? 20 : 16)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .background(Color.white)
            .onChange(of: currentChat.messages.count) { _, _ in
                if let lastMessage = currentChat.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
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
    
    // Group consecutive messages from the same sender
    private func groupMessages(_ messages: [Message]) -> [MessageGroup] {
        var groups: [MessageGroup] = []
        var currentGroup: [Message] = []
        var lastSender: Bool?
        
        for message in messages {
            if lastSender == nil || lastSender != message.isFromCurrentUser {
                // Start a new group
                if !currentGroup.isEmpty {
                    groups.append(MessageGroup(
                        messages: currentGroup,
                        isFromCurrentUser: currentGroup.first?.isFromCurrentUser ?? false
                    ))
                }
                currentGroup = [message]
                lastSender = message.isFromCurrentUser
            } else {
                // Add to current group
                currentGroup.append(message)
            }
        }
        
        // Add the last group
        if !currentGroup.isEmpty {
            groups.append(MessageGroup(
                messages: currentGroup,
                isFromCurrentUser: currentGroup.first?.isFromCurrentUser ?? false
            ))
        }
        
        return groups
    }
    
    private func shouldShowTimestamp(for index: Int, in groups: [MessageGroup]) -> Bool {
        // Show timestamp for first message, or if significant time has passed
        if index == 0 { return true }
        
        let currentGroup = groups[index]
        let previousGroup = groups[index - 1]
        
        let timeDifference = currentGroup.messages.first?.timestamp.timeIntervalSince(
            previousGroup.messages.last?.timestamp ?? Date()
        ) ?? 0
        
        return timeDifference > 300 // Show timestamp if more than 5 minutes apart
    }
}

// MARK: - Message Group
private struct MessageGroup {
    let messages: [Message]
    let isFromCurrentUser: Bool
}

private struct MessageGroupView: View {
    let group: MessageGroup
    let showAvatar: Bool
    let showTimestamp: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Timestamp
            if showTimestamp {
                Text(group.messages.first?.timestamp ?? Date(), style: .date)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(hex: "828282"))
                    .padding(.bottom, 8)
            }
            
            // Messages
            HStack(alignment: .bottom, spacing: 8) {
                if showAvatar && !group.isFromCurrentUser {
                    // Avatar
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24, height: 24)
                } else if !group.isFromCurrentUser {
                    // Spacer to maintain alignment
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 24, height: 24)
                }
                
                if group.isFromCurrentUser {
                    Spacer()
                }
                
                VStack(spacing: 2) {
                    ForEach(Array(group.messages.enumerated()), id: \.element.id) { index, message in
                        ModernMessageBubble(
                            message: message,
                            isFirstInGroup: index == 0,
                            isLastInGroup: index == group.messages.count - 1
                        )
                    }
                }
                
                if !group.isFromCurrentUser {
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    ModernChatView(
        chatViewModel: ChatViewModel(),
        chat: Chat(
            otherUserName: "Helena Hills",
            otherUserDogName: "Max",
            otherUserDogPhoto: "dog_Max",
            messages: [
                Message(text: "Hi there!", isFromCurrentUser: false, timestamp: Date().addingTimeInterval(-3600)),
                Message(text: "How are you?", isFromCurrentUser: false, timestamp: Date().addingTimeInterval(-3550)),
                Message(text: "I'm doing great, thanks!", isFromCurrentUser: true, timestamp: Date().addingTimeInterval(-3000)),
                Message(text: "Would love to set up a playdate", isFromCurrentUser: true, timestamp: Date().addingTimeInterval(-2990))
            ],
            lastMessageDate: Date()
        )
    )
} 
