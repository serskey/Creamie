import SwiftUI

struct DogMarker: View {
    let dog: Dog
    
    var body: some View {
        ZStack {
            // Water drop shape background
            WaterDropShape()
                .fill(Color.purple)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .frame(width: 40, height: 50)
                .shadow(radius: 4, x: 0, y: 2)
            
            // Dog breed image or fallback icon
            ZStack {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 40, height: 40)
                
                Group {
                    if let imageName = breedImageName(for: dog.breed),
                       UIImage(named: imageName) != nil {
                        Image(imageName)
                            .resizable()
                    } else {
                        Image(systemName: "pawprint.circle.fill")
                            .resizable()
                    }
                }
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .clipShape(Circle())
                .opacity(0.9)
            }
            .offset(x: 1.5, y: -6.3)
            
        }
    }
    
    // Map breed enum cases to actual folder names
    private func breedImageName(for breed: DogBreed) -> String? {
        switch breed {
        case .afghanHound:
            return "afghanHound"
        case .airdaleTerrier:
            return "airdaleTerrier"
        case .akita:
            return "akita"
        case .alaskanMalamute:
            return "alaskanMalamute"
        case .americanBulldog:
            return "americanBulldog"
        case .beagle:
            return "beagle"
        case .frenchBulldog:
            return "frenchBulldog"
        case .mastiff:
            return "mastiff"
        case .shihTzu:
            return "shihTzu"
        case .husky:
            return "husky"
        case .cockapoo:
            return "cockapoo"
        case .labrador:
            return "labrador"
        default:
            return nil // Use fallback paw print
        }
    }
    
//    // Adjust image size based on breed to compensate for different padding in original images
//    private func imageSizeForBreed(_ breed: DogBreed) -> CGFloat {
//        switch breed {
//        // Breeds that appear too small (have lots of padding) - make bigger
//        case .beagle, .shihTzu, .cockapoo:
//            return 32
//        case .airdaleTerrier, .americanBulldog:
//            return 30
//        // Breeds that appear too big (less padding) - make smaller  
//        case .mastiff, .alaskanMalamute:
//            return 26
//        case .husky, .akita:
//            return 27
//        // Standard size for well-proportioned images
//        default:
//            return 28
//        }
//    }
}

// Custom water drop shape
struct WaterDropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Start from the bottom point (tip of the drop)
        path.move(to: CGPoint(x: width / 2, y: height))
        
        // Create the water drop shape using curves
        // Right side curve
        path.addQuadCurve(
            to: CGPoint(x: width, y: height * 0.6),
            control: CGPoint(x: width * 0.85, y: height * 0.8)
        )
        
        // Top right arc
        path.addArc(
            center: CGPoint(x: width / 2, y: height * 0.35),
            radius: width / 2,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        
        // Left side curve
        path.addQuadCurve(
            to: CGPoint(x: width / 2, y: height),
            control: CGPoint(x: width * 0.15, y: height * 0.8)
        )
        
        return path
    }
} 
