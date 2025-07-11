import SwiftUI

struct ModernMessageBubble: View {
    let message: Message
    let isFirstInGroup: Bool
    let isLastInGroup: Bool
    
    private var cornerRadius: RectangleCornerRadii {
        if message.isFromCurrentUser {
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
        Text(message.text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(message.isFromCurrentUser ? .white : .black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                UnevenRoundedRectangle(cornerRadii: cornerRadius)
                    .fill(message.isFromCurrentUser ? Color.black : Color(red: 0.91, green: 0.91, blue: 0.92))
            )
            .frame(maxWidth: 247, alignment: message.isFromCurrentUser ? .trailing : .leading)
    }
}

// Helper extension for hex colors if not already defined
extension Color {
    init(hex: String) {
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

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    VStack(spacing: 8) {
        ModernMessageBubble(
            message: Message(
                text: "This is a sample message from the current user",
                isFromCurrentUser: true,
                timestamp: Date()
            ),
            isFirstInGroup: true,
            isLastInGroup: true
        )
        
        ModernMessageBubble(
            message: Message(
                text: "This is a reply from another user",
                isFromCurrentUser: false,
                timestamp: Date()
            ),
            isFirstInGroup: true,
            isLastInGroup: false
        )
        
        ModernMessageBubble(
            message: Message(
                text: "With multiple messages in a group",
                isFromCurrentUser: false,
                timestamp: Date()
            ),
            isFirstInGroup: false,
            isLastInGroup: true
        )
    }
    .padding()
} 