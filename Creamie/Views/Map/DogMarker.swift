import SwiftUI

struct DogMarker: View {
    let dog: Dog
    let isSelected: Bool
    
    var body: some View {
        Image(systemName: "pawprint.circle.fill")
            .foregroundStyle(dog.breed.markerColor)
            .font(.title2)
            .scaleEffect(isSelected ? 1.3 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
    }
} 