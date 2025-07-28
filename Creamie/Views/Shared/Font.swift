import SwiftUI

struct FurryTextCanvas: View {
    let text: String
    let fontSize: CGFloat
    let furColor: Color
    let textColor: Color
    let furIntensity: Int
    let furRadius: ClosedRange<Double>
    
    init(text: String,
         fontSize: CGFloat = 24,
         furColor: Color = .white,
         textColor: Color = .white,
         furIntensity: Int = 200,
         furRadius: ClosedRange<Double> = 3...10) {
        self.text = text
        self.fontSize = fontSize
        self.furColor = furColor
        self.textColor = textColor
        self.furIntensity = furIntensity
        self.furRadius = furRadius
    }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let font = Font.system(size: fontSize, weight: .bold)
            
            // Create text styles for both fur and main text
            let furTextStyle = Text(text)
                .font(font)
                .foregroundColor(furColor)
            
            let mainTextStyle = Text(text)
                .font(font)
                .foregroundColor(textColor)

            // Resolve text shapes
            let furResolved = context.resolve(furTextStyle)
            let mainResolved = context.resolve(mainTextStyle)
            let textSize = furResolved.measure(in: size)
            
            // Calculate text position
            let textCenter = CGPoint(
                x: center.x,
                y: center.y
            )

            // Draw fuzzy fur strokes
            for _ in 0..<furIntensity {
                let angle = Double.random(in: 0..<2 * .pi)
                let radius = Double.random(in: furRadius)
                let offsetX = CGFloat(cos(angle) * radius)
                let offsetY = CGFloat(sin(angle) * radius)
                
                // Vary opacity based on distance from center for more realistic fur
                let normalizedRadius = (radius - furRadius.lowerBound) / (furRadius.upperBound - furRadius.lowerBound)
                let opacity = 0.3 * (1.0 - normalizedRadius * 0.7) // Stronger near center
                
                var furContext = context
                furContext.opacity = opacity
                furContext.draw(furResolved,
                              at: CGPoint(x: textCenter.x + offsetX,
                                        y: textCenter.y + offsetY))
            }

            // Draw main text on top
            context.draw(mainResolved, at: textCenter)
        }
        .frame(minWidth: 200, minHeight: 100) // Ensure enough space for fur effect
    }
}

// MARK: - Preview and Usage Examples
struct FurryTextCanvas_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            // Default furry text
            FurryTextCanvas(
                text: "FLUFFY",
                furColor: .pink.opacity(0.6)
            )
            .frame(height: 80)
            .background(Color.black)
            
            // Customized version
            FurryTextCanvas(
                text: "SOFT KITTY",
                fontSize: 32,
                furColor: .pink.opacity(0.6),
                textColor: .white,
                furIntensity: 300,
                furRadius: 2...15
            )
            .frame(height: 100)
            .background(Color.purple.gradient)
            
            // Colored fur effect
            FurryTextCanvas(
                text: "WINTER",
                fontSize: 28,
                furColor: .blue.opacity(0.4),
                textColor: .cyan,
                furIntensity: 150,
                furRadius: 4...8
            )
            .frame(height: 80)
            .background(Color.black)
        }
        .padding()
    }
}

// MARK: - Convenience Extensions
extension FurryTextCanvas {
    // Preset configurations for common use cases
    static func fluffy(_ text: String, size: CGFloat = 24) -> FurryTextCanvas {
        FurryTextCanvas(
            text: text,
            fontSize: size,
            furColor: .white.opacity(0.8),
            textColor: .white,
            furIntensity: 250,
            furRadius: 3...12
        )
    }
    
    static func soft(_ text: String, size: CGFloat = 24, color: Color = .pink) -> FurryTextCanvas {
        FurryTextCanvas(
            text: text,
            fontSize: size,
            furColor: color.opacity(0.5),
            textColor: color,
            furIntensity: 180,
            furRadius: 2...8
        )
    }
    
    static func wild(_ text: String, size: CGFloat = 24) -> FurryTextCanvas {
        FurryTextCanvas(
            text: text,
            fontSize: size,
            furColor: .orange.opacity(0.6),
            textColor: .yellow,
            furIntensity: 350,
            furRadius: 5...20
        )
    }
}
