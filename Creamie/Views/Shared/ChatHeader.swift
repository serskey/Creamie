import SwiftUI

struct ChatHeader: View {
    let userName: String
    let userStatus: String
    let onBackTapped: () -> Void
    let onPhoneTapped: () -> Void
    let onVideoTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Status Bar Spacer
            Rectangle()
                .fill(Color.white)
                .frame(height: 44)
            
            // Header Content
            HStack(spacing: 0) {
                // Back Button
                Button(action: onBackTapped) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 24, height: 24)
                }
                .padding(.leading, 16)
                
                Spacer(minLength: 12)
                
                // Profile Image
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Spacer(minLength: 8)
                
                // User Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(userName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(userStatus)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.black.opacity(0.5))
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 24) {
                    // Phone Button
                    Button(action: onPhoneTapped) {
                        Image(systemName: "phone")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 24, height: 24)
                    }
                    
                    // Video Button
                    Button(action: onVideoTapped) {
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
}

#Preview {
    ChatHeader(
        userName: "Helena Hills",
        userStatus: "Active 11m ago",
        onBackTapped: {},
        onPhoneTapped: {},
        onVideoTapped: {}
    )
} 