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
    
    @EnvironmentObject var authService: AuthenticationService
    
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
            
            Task {
                // Subscribe to messages for this chat
                await chatViewModel.subscribeToMessages(for: chatId)
            }
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
                                AcatarView(photoName: chat.otherDogAvatar)
                                    .frame(width: 40, height: 40)
                                    .scaleEffect(0.7)
                                    .zIndex(1)
                                
                                ModernMessageBubble(message: message,
                                                    isFirstInGroup: isFirst,
                                                    isLastInGroup: isLast)
                                
                                Spacer()
                                
                                
                            } else {
                                Spacer()
                                
                                ModernMessageBubble(message: message,
                                                    isFirstInGroup: isFirst,
                                                    isLastInGroup: isLast)
                                
                                AcatarView(photoName: selectedDog?.photos.first ?? "https://bibnhxcfmdpwqcfftgtj.supabase.co/storage/v1/object/public/dog-photos/2867871c-2449-445a-bebb-2cdb7525ab99_bd256857-4f3e-4152-8348-0fd4330dea24.jpg")
                                    .frame(width: 40, height: 40)
                                    .scaleEffect(0.7)
                                    .zIndex(1)
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
