import SwiftUI

struct CircularButton: View {
    let icon: String
    let size: CGFloat
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        icon: String,
        size: CGFloat = 44,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                
                Image(systemName: icon)
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundColor(isSelected ? Color.pink : Color.purple)
            }
            .padding(8)
            .background{Color.clear}
            .glassEffect(.clear.tint(Color.clear).interactive())
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
