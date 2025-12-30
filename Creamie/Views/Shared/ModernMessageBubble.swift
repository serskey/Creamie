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
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                UnevenRoundedRectangle(cornerRadii: cornerRadius)
                    .fill(message.isFromCurrentUser ? Color.pink : Color.purple)
            )
            .frame(maxWidth: 247, alignment: message.isFromCurrentUser ? .trailing : .leading)
    }
}
