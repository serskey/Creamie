/**
  This is exact Figma chat window replica 
    Created on 07/10/2025
 
 A pixel-perfect implementation that matches your Figma design with:
 ✅ Exact spacing and layout from your design https://www.figma.com/design/o0oDQzkIVlHGCQP1pQaDeL/Creamie-App?node-id=1-1644&m=dev
 ✅ Custom header with back button, profile image, and action buttons
 ✅ Message bubbles with exact corner radius patterns (18px with flow-specific variations)
 ✅ Proper color scheme: Black sender bubbles (#000000), light gray recipient bubbles (#E9E9EB)
 ✅ Input area with placeholder "Message..." and mic/emoji/image icons
 ✅ Home indicator at the bottom
 */

import SwiftUI

struct FigmaChatView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    let chat: Chat
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            chatHeader
            
            // Chat Messages
            chatMessages
            
            // Input Area
            messageInputArea
        }
        .background(Color.white)
        .navigationBarHidden(true)
    }
    
    // MARK: - Header
    private var chatHeader: some View {
        VStack(spacing: 0) {
            // Status Bar Spacer
            Rectangle()
                .fill(Color.white)
                .frame(height: 44)
            
            // Header Content
            HStack(spacing: 0) {
                // Back Button
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 24, height: 24)
                }
                .padding(.leading, 16)
                
                Spacer(minLength: 12)
                
                // Profile Image
                AsyncImage(url: nil) { _ in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                } placeholder: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                }
                
                Spacer(minLength: 8)
                
                // User Info
                VStack(alignment: .leading, spacing: 2) {
                    Text("Helena Hills")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text("Active 11m ago")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.black.opacity(0.5))
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 24) {
                    // Phone Button
                    Button(action: {}) {
                        Image(systemName: "phone")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 24, height: 24)
                    }
                    
                    // Video Button
                    Button(action: {}) {
                        Image(systemName: "video")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(.trailing, 16)
            }
            .frame(height: 56)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color.gray.opacity(0.3)),
                alignment: .bottom
            )
        }
    }
    
    // MARK: - Chat Messages
    private var chatMessages: some View {
        ScrollViewReader { (proxy: ScrollViewProxy) in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    // Sample message content matching Figma design
                    
                    // Initial message
                    VStack(spacing: 16) {
                        Spacer(minLength: 20)
                        
                        // Single sender message
                        HStack {
                            Spacer()
                            FigmaMessageBubble(
                                text: "This is the main chat template",
                                isFromCurrentUser: true,
                                isFirstInGroup: true,
                                isLastInGroup: true
                            )
                        }
                        .padding(.horizontal, 16)
                        
                        // Timestamp
                        Text("Nov 30, 2023, 9:41 AM")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color(red: 0.51, green: 0.51, blue: 0.51))
                            .padding(.top, 8)
                        
                        // Recipient message group
                        HStack(alignment: .bottom, spacing: 8) {
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
                            
                            VStack(spacing: 2) {
                                FigmaMessageBubble(
                                    text: "Oh?",
                                    isFromCurrentUser: false,
                                    isFirstInGroup: true,
                                    isLastInGroup: false
                                )
                                
                                FigmaMessageBubble(
                                    text: "Cool",
                                    isFromCurrentUser: false,
                                    isFirstInGroup: false,
                                    isLastInGroup: false
                                )
                                
                                FigmaMessageBubble(
                                    text: "How does it work?",
                                    isFromCurrentUser: false,
                                    isFirstInGroup: false,
                                    isLastInGroup: true
                                )
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        
                        // Sender message group
                        VStack(spacing: 2) {
                            HStack {
                                Spacer()
                                FigmaMessageBubble(
                                    text: "You just edit any text to type in the conversation you want to show, and delete any bubbles you don't want to use",
                                    isFromCurrentUser: true,
                                    isFirstInGroup: true,
                                    isLastInGroup: false
                                )
                            }
                            
                            HStack {
                                Spacer()
                                FigmaMessageBubble(
                                    text: "Boom!",
                                    isFromCurrentUser: true,
                                    isFirstInGroup: false,
                                    isLastInGroup: true
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        
                        // Final recipient group
                        HStack(alignment: .bottom, spacing: 8) {
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
                            
                            VStack(spacing: 2) {
                                FigmaMessageBubble(
                                    text: "Hmmm",
                                    isFromCurrentUser: false,
                                    isFirstInGroup: true,
                                    isLastInGroup: false
                                )
                                
                                FigmaMessageBubble(
                                    text: "I think I get it",
                                    isFromCurrentUser: false,
                                    isFirstInGroup: false,
                                    isLastInGroup: false
                                )
                                
                                FigmaMessageBubble(
                                    text: "Will head to the Help Center if I have more questions tho",
                                    isFromCurrentUser: false,
                                    isFirstInGroup: false,
                                    isLastInGroup: true
                                )
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .background(Color(.systemBackground))
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
                        .foregroundColor(.black)
                        .focused($isTextFieldFocused)
                    
                    HStack(spacing: 16) {
                        // Mic Icon
                        Button(action: {}) {
                            Image(systemName: "mic")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(red: 0.51, green: 0.51, blue: 0.51))
                                .frame(width: 24, height: 24)
                        }
                        
                        // Emoji Icon
                        Button(action: {}) {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(red: 0.51, green: 0.51, blue: 0.51))
                                .frame(width: 24, height: 24)
                        }
                        
                        // Image Icon
                        Button(action: {}) {
                            Image(systemName: "photo")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(red: 0.51, green: 0.51, blue: 0.51))
                                .frame(width: 24, height: 24)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 0.88, green: 0.88, blue: 0.88), lineWidth: 1)
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Home Indicator
            Rectangle()
                .fill(Color.black)
                .frame(width: 134, height: 5)
                .clipShape(RoundedRectangle(cornerRadius: 100))
                .padding(.top, 21)
                .padding(.bottom, 8)
        }
        .frame(height: 82)
        .background(Color.white)
    }
}

// MARK: - Message Bubble Component
struct FigmaMessageBubble: View {
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
            .foregroundColor(isFromCurrentUser ? .white : .black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                UnevenRoundedRectangle(cornerRadii: cornerRadius)
                    .fill(isFromCurrentUser ? Color.black : Color(red: 0.91, green: 0.91, blue: 0.92))
            )
            .frame(maxWidth: 247, alignment: isFromCurrentUser ? .trailing : .leading)
    }
}

// MARK: - Helper Extensions
extension Color {
    static func hex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    FigmaChatView(
        chatViewModel: ChatViewModel(),
        chat: Chat(
            otherUserName: "Helena Hills",
            otherUserDogName: "Max",
            otherUserDogPhoto: "dog_Max",
            messages: [],
            lastMessageDate: Date()
        )
    )
}
