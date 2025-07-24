import SwiftUI

// TODO: Liquid Glass Style
struct TabBar: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var chatViewModel: ChatViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            // Map Tab
            TabBarItem(
                icon: "map.circle.fill",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )
            .frame(maxWidth: .infinity)
            
            // My pets Tab
            TabBarItem(
                icon: "pawprint.fill",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )
            .frame(maxWidth: .infinity)
            
            // Chat Tab with Badge
            TabBarItem(
                icon: "message.fill",
                isSelected: selectedTab == 2,
                badgeCount: chatViewModel.chats.reduce(0) { count, chat in
                    // Count unread messages (for demo, we'll just use 1 if there are any messages)
                    return count + (chat.safeMessages.isEmpty ? 0 : 1)
                },
                action: { selectedTab = 2 }
            )
            .frame(maxWidth: .infinity)
            
            TabBarItem(
                icon: "gearshape.fill",
                isSelected: selectedTab == 3,
                action: { selectedTab = 3 }
            )
            .frame(maxWidth: .infinity)
            
        }
        .padding(.horizontal, 16) // 1. INTERNAL: White space left/right inside the tab bar
        .padding(.vertical, 16)   // 2. INTERNAL: White space top/bottom inside the tab bar
        .background(Color.clear)
        .glassEffect(.clear.tint(Color.clear).interactive())
        .padding(.horizontal, 44) // 3. EXTERNAL: Margins from screen edges (left/right)
        .padding(.top, 700)       // 4. EXTERNAL: Pushes tab bar down from top of screen
        .padding(.bottom, 8)      // 5. EXTERNAL: Small gap from bottom of screen
    }
}

private struct TabBarItem: View {
    let icon: String
    let isSelected: Bool
    let badgeCount: Int
    let action: () -> Void
    
    init(
        icon: String,
        isSelected: Bool,
        badgeCount: Int = 0,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.isSelected = isSelected
        self.badgeCount = badgeCount
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(isSelected ? Color.pink : Color.purple)
                        .frame(width: 30, height: 30)
                    
                    // Badge (for chat) - positioned relative to the icon
                    if badgeCount > 0 {
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.pink : Color.purple)
                                .frame(width: 16, height: 16)

                            Text("\(badgeCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 12, y: -12) // Position badge on top-right of icon
                    }
                }
            }
        }
        .buttonStyle(.borderless)
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Spacer()
        TabBar(selectedTab: .constant(0))
    }
    .background(Color(.systemBackground))
}
