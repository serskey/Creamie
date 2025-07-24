import SwiftUI
import MapKit

struct ChatView: View {
    @Binding var showTabBar: Bool
    @ObservedObject var chatViewModel: ChatViewModel
    @Binding var selectedChatId: UUID?
    let chatId: UUID
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var isButtonSelected = false
    
    @State private var selectedDog: Dog?
    
    // Computed property to get the current chat from chatViewModel
    private var chat: Chat {
        return chatViewModel.chats.first(where: { $0.id == chatId }) ?? Chat.empty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            chatHeader
            
            // Chat Messages
            chatMessages
            
            // Input Area
            messageInputArea
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .onAppear {
            // Hide tab bar when this view appears
            withAnimation(.easeInOut(duration: 0.3)) {
                showTabBar = false
            }
            
            Task {
                await chatViewModel.fetchMessagesByChatId(for: chatId)
            }
            // Subscribe to messages for this chat
            chatViewModel.subscribeToMessages(for: chatId)
        }
        .onDisappear {
            // Show tab bar when this view disappears (going back)
            withAnimation(.easeInOut(duration: 0.3)) {
                showTabBar = true
            }
        }
    }
    
    
    // MARK: - Header
    private var chatHeader: some View {
        VStack(spacing: 0) {
            
            // Header Content
            HStack(spacing: 0) {
                
                // Back button
                CircularButton(
                    icon: "chevron.left.circle.fill",
                    size: 50,
                    isSelected: isButtonSelected,
                    action: { dismiss() }
                )
                .frame(width: 80, height: 50)
                
                Spacer()
                
                // Profile Image
                VStack(spacing: 0) {
                    AcatarView(photoName: chat.otherDogAvatar)
                    Text(chat.otherDogName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Action Buttons - Navigation
                HStack(spacing: 24) {
                    
                    // TODO: Fetch Dog real location from Backend
                    // dog location
                    CircularButton(
                        icon: "location.fill",
                        size: 50,
                        isSelected: isButtonSelected,
                        action: {
                            let coordinates = CLLocationCoordinate2D(latitude: 30.5604, longitude: 103.9300)
                            let url = URL(string: "maps://?saddr=&daddr=\(coordinates.latitude),\(coordinates.longitude)")
                            if let url = url, UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url)
                            }
                        }
                    )
                    
                    
                }
                .padding(.trailing, 16)
            }
            .frame(height: 56)
        }
//        // TODO: Tap avatar to dog profile detail
//        .sheet(item: $selectedDog) { dog in
//            MapDogProfileView(selectedDog: dog,
//                              selectedTab: $selectedTab,
//                              selectedChatId: $selectedChatId)
//            .presentationDetents([.medium])
//            .presentationBackgroundInteraction(.enabled)
//        }
    }
    
    // MARK: - Chat Messages
    private var chatMessages: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    ForEach(Array(chat.safeMessages.enumerated()), id: \.element.id) { index, message in
                        let isFromCurrentUser = message.isFromCurrentUser
                        let isFirst = index == 0 || chat.safeMessages[index - 1].isFromCurrentUser != isFromCurrentUser
                        let isLast = index == chat.safeMessages.count - 1 || chat.safeMessages[index + 1].isFromCurrentUser != isFromCurrentUser

                        HStack(alignment: .bottom, spacing: 8) {
                            if !isFromCurrentUser {
                                if isFirst {
                                    // Avatar on first of incoming group
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 24, height: 24)
                                } else {
                                    Spacer().frame(width: 24)
                                }
                            }

                            if isFromCurrentUser {
                                Spacer()
                            }

                            NewFigmaMessageBubble(
                                text: message.text,
                                isFromCurrentUser: isFromCurrentUser,
                                isFirstInGroup: isFirst,
                                isLastInGroup: isLast
                            )

                            if !isFromCurrentUser {
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, isFirst ? 12 : 2)
                    }

                    Spacer(minLength: 100)
                }
            }
            .onChange(of: chat.safeMessages.count) { _ in
                withAnimation {
                    if let lastMessage = chat.safeMessages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }

    }
    
    // MARK: - Message Input Area
    private var messageInputArea: some View {
        VStack(spacing: 0) {
            // Input Container
            HStack(spacing: 16) {
                // Text Input
                HStack(spacing: 16) {
                    TextField("Message...", text: $messageText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.primary)
                        .focused($isTextFieldFocused)
                    
                    HStack(spacing: 16) {
                        // TODO: Enable Mic/Emoji/Image Attanching
                        // Mic Icon
//                        Button(action: {}) {
//                            Image(systemName: "mic")
//                                .font(.system(size: 20, weight: .medium))
//                                .foregroundColor(Color(red: 0.51, green: 0.51, blue: 0.51))
//                                .frame(width: 24, height: 24)
//                        }
//
//                        // Emoji Icon
//                        Button(action: {}) {
//                            Image(systemName: "face.smiling")
//                                .font(.system(size: 20, weight: .medium))
//                                .foregroundColor(Color(red: 0.51, green: 0.51, blue: 0.51))
//                                .frame(width: 24, height: 24)
//                        }
//
//                        // Image Icon
//                        Button(action: {}) {
//                            Image(systemName: "photo")
//                                .font(.system(size: 20, weight: .medium))
//                                .foregroundColor(Color(red: 0.51, green: 0.51, blue: 0.51))
//                                .frame(width: 24, height: 24)
//                        }
                        
                        // Sending Messages Button
                        Button(action: {
                            guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            
                            print("Sending messageText: \(messageText)")
    
                            chatViewModel.sendMessage(messageText, in: chat)
                            messageText = ""
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color.purple)
                                .frame(width: 24, height: 24)
                        }

                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassEffect()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
//            // Home Indicator
//            Rectangle()
//                .fill(Color.black)
//                .frame(width: 134, height: 5)
//                .clipShape(RoundedRectangle(cornerRadius: 100))
//                .padding(.top, 21)
//                .padding(.bottom, 8)
        }
        .frame(height: 82)
    }
    
}

// MARK: - Message Bubble Component
struct NewFigmaMessageBubble: View {
    let text: String
    let isFromCurrentUser: Bool
    let isFirstInGroup: Bool
    let isLastInGroup: Bool
    
    private var cornerRadius: RectangleCornerRadii {
        if isFromCurrentUser {
            // Sender bubbles (right side)
            if isFirstInGroup && isLastInGroup {
                return RectangleCornerRadii(
                    topLeading: 18,
                    bottomLeading: 18,
                    bottomTrailing: 18,
                    topTrailing: 18
                )
            } else if isFirstInGroup {
                return RectangleCornerRadii(
                    topLeading: 18,
                    bottomLeading: 18,
                    bottomTrailing: 4,
                    topTrailing: 18
                )
            } else if isLastInGroup {
                return RectangleCornerRadii(
                    topLeading: 18,
                    bottomLeading: 18,
                    bottomTrailing: 18,
                    topTrailing: 4
                )
            } else {
                return RectangleCornerRadii(
                    topLeading: 18,
                    bottomLeading: 18,
                    bottomTrailing: 4,
                    topTrailing: 4
                )
            }
        } else {
            // Recipient bubbles (left side)
            if isFirstInGroup && isLastInGroup {
                return RectangleCornerRadii(
                    topLeading: 18,
                    bottomLeading: 18,
                    bottomTrailing: 18,
                    topTrailing: 18
                )
            } else if isFirstInGroup {
                return RectangleCornerRadii(
                    topLeading: 18,
                    bottomLeading: 18,
                    bottomTrailing: 18,
                    topTrailing: 4
                )
            } else if isLastInGroup {
                return RectangleCornerRadii(
                    topLeading: 4,
                    bottomLeading: 18,
                    bottomTrailing: 18,
                    topTrailing: 18
                )
            } else {
                return RectangleCornerRadii(
                    topLeading: 4,
                    bottomLeading: 18,
                    bottomTrailing: 18,
                    topTrailing: 4
                )
            }
        }
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassEffect(.clear.interactive())
            .background(
                UnevenRoundedRectangle(cornerRadii: cornerRadius)
                    .fill(isFromCurrentUser ? Color.pink : Color.purple)
            )
            .frame(maxWidth: 247, alignment: isFromCurrentUser ? .trailing : .leading)
    }
}
