import SwiftUI

struct ZoomablePhotoView: View {
    let imageName: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            GeometryReader { geometry in
                let magnificationGesture = MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastScale
                        lastScale = value
                        scale = min(max(scale * delta, 1.0), 4.0)
                    }
                    .onEnded { _ in
                        lastScale = 1.0
                    }
                
                let dragGesture = DragGesture()
                    .onChanged { value in
                        let newOffset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                        offset = newOffset
                    }
                    .onEnded { _ in
                        lastOffset = offset
                        
                        // Reset position if scale is 1
                        if scale <= 1.0 {
                            withAnimation {
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                    }
                
                let doubleTapGesture = TapGesture(count: 2)
                    .onEnded {
                        withAnimation {
                            if scale > 1.0 {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.0
                            }
                        }
                    }
                
                ZStack {
                    // Check if imageName is a Supabase backend URL
                    if imageName.hasPrefix("https://") && imageName.contains("supabase.co") {
                        // Load from backend URL using AsyncImage
                        AsyncImage(url: URL(string: imageName)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .scaleEffect(scale)
                                    .offset(offset)
                                    .gesture(dragGesture)
                                    .gesture(magnificationGesture)
                                    .gesture(doubleTapGesture)
                                    .background(Color(.systemBackground))
                            case .failure(_):
                                // Error loading from backend
                                ZStack {
                                    Color.red.opacity(0.3)
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                        .font(.largeTitle)
                                }
                            case .empty:
                                // Loading placeholder
                                ZStack {
                                    Color.gray.opacity(0.3)
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.5)
                                }
                            @unknown default:
                                EmptyView()
                            }
                        }
                        
                    } else if let uiImage = UIImage(named: imageName) {
                        // Load from asset catalog (for sample dogs)
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(dragGesture)
                            .gesture(magnificationGesture)
                            .gesture(doubleTapGesture)
                            .background(Color(.systemBackground))
                    } else {
                        // Fallback if image can't be loaded
                        ZStack {
                            Color.gray.opacity(0.3)
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
            }
            
            // Close button
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .padding()
                    Spacer()
                }
                Spacer()
            }
        }
        .statusBarHidden()
    }
} 
