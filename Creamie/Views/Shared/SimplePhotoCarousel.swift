import SwiftUI

struct SimplePhotoCarousel: View {
    let photos: [String]
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                TabView(selection: $currentIndex) {
                    ForEach(Array(photos.enumerated()), id: \.element) { index, photo in
                        DogPhotoView(photoName: photo)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                
                // Navigation arrows
                if photos.count > 1 {
                    HStack {
                        // Previous button
                        Button(action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                if currentIndex > 0 {
                                    currentIndex -= 1
                                }
                            }
                        }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .background(Circle().fill(.black.opacity(0.3)))
                                .opacity(currentIndex > 0 ? 1.0 : 0.3)
                        }
                        .disabled(currentIndex == 0)
                        
                        Spacer()
                        
                        // Next button
                        Button(action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                if currentIndex < photos.count - 1 {
                                    currentIndex += 1
                                }
                            }
                        }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .background(Circle().fill(.black.opacity(0.3)))
                                .opacity(currentIndex < photos.count - 1 ? 1.0 : 0.3)
                        }
                        .disabled(currentIndex == photos.count - 1)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .clipped()
        }
    }
}

// MARK: - Preview
struct SimplePhotoCarousel_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Simple Carousel")
                .font(.headline)
            
            SimplePhotoCarousel(photos: ["dog_Creamie", "dog_Max"])
                .frame(height: 280)
            
            Text("Parallax Carousel")
                .font(.headline)
        }
        .padding()
    }
} 
