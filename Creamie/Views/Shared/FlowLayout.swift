import SwiftUI

struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content
    
    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            FlowLayoutHelper(
                width: geometry.size.width,
                spacing: spacing,
                content: content
            )
        }
    }
}

struct FlowLayoutHelper<Content: View>: View {
    let width: CGFloat
    let spacing: CGFloat
    let content: () -> Content
    
    @State private var elementsSize: [CGSize] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(elementsPosition.indices, id: \.self) { index in
                HStack(spacing: spacing) {
                    ForEach(elementsPosition[index], id: \.self) { elementIndex in
                        content()
                            .measureSize { size in
                                if elementsSize.count <= elementIndex {
                                    elementsSize.append(size)
                                } else {
                                    elementsSize[elementIndex] = size
                                }
                            }
                            .fixedSize()
                    }
                }
            }
        }
    }
    
    var elementsPosition: [[Int]] {
        var result: [[Int]] = [[]]
        var currentRow = 0
        var currentRowWidth: CGFloat = 0
        
        for index in 0..<elementsSize.count {
            let elementWidth = elementsSize[index].width
            
            if currentRowWidth + elementWidth + (result[currentRow].isEmpty ? 0 : spacing) > width {
                currentRow += 1
                currentRowWidth = elementWidth
                result.append([index])
            } else {
                currentRowWidth += elementWidth + (result[currentRow].isEmpty ? 0 : spacing)
                result[currentRow].append(index)
            }
        }
        
        return result
    }
}

// Helper view modifier to measure view size
extension View {
    func measureSize(perform action: @escaping (CGSize) -> Void) -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: SizePreferenceKey.self,
                    value: geometry.size
                )
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: action)
    }
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
} 