import SwiftUI

struct ChatInputArea: View {
    @Binding var messageText: String
    var isTextFieldFocused: FocusState<Bool>.Binding
    let onSendMessage: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Input Container
            HStack(spacing: 16) {
                // Text Input
                HStack(spacing: 16) {
                    TextField("Message...", text: $messageText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.black)
                        .focused(isTextFieldFocused)
                        .onSubmit {
                            onSendMessage()
                        }
                    
                    HStack(spacing: 16) {
                        // Mic Icon
                        Button(action: {
                            // Handle voice recording
                        }) {
                            Image(systemName: "mic")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(red: 0.51, green: 0.51, blue: 0.51))
                                .frame(width: 24, height: 24)
                        }
                        
                        // Emoji Icon
                        Button(action: {
                            // Handle emoji picker
                        }) {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(red: 0.51, green: 0.51, blue: 0.51))
                                .frame(width: 24, height: 24)
                        }
                        
                        // Image/Send Icon
                        Button(action: {
                            if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onSendMessage()
                            } else {
                                // Handle image picker
                            }
                        }) {
                            Image(systemName: messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "photo" : "paperplane.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(red: 0.51, green: 0.51, blue: 0.51) : .blue)
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

#Preview {
    @Previewable @State var messageText = ""
    @FocusState var isFocused: Bool
    
    return ChatInputArea(
        messageText: $messageText,
        isTextFieldFocused: $isFocused,
        onSendMessage: {}
    )
}
