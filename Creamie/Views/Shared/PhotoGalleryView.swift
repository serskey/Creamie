import SwiftUI

struct PhotoGalleryView: View {
    let photoNames: [String]
    @State private var selectedPhotoIndex = 0
    @State private var showingFullScreenPhoto = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Photo display
            TabView(selection: $selectedPhotoIndex) {
                ForEach(0..<photoNames.count, id: \.self) { index in
                    DogPhotoView(photoName: photoNames[index])
                        .tag(index)
                        .onTapGesture {
                            showingFullScreenPhoto = true
                        }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Photo indicators
            if photoNames.count > 1 {
                HStack(spacing: 8) {
                    ForEach(0..<photoNames.count, id: \.self) { index in
                        Circle()
                            .fill(selectedPhotoIndex == index ? Color.white : Color.white.opacity(0.5))
                            .frame(width: 8, height: 8)
                            .shadow(radius: 1)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenPhoto) {
            FullScreenPhotoView(
                photoNames: photoNames,
                initialIndex: selectedPhotoIndex,
                onDismiss: { showingFullScreenPhoto = false }
            )
        }
    }
}

struct DogPhotoView: View {
    let photoName: String
    
    var body: some View {
        GeometryReader { geometry in
            
            // Check if photoName is a Supabase backend URL
            if photoName.hasPrefix("https://") && photoName.contains("supabase.co") {
                // Load from backend URL using AsyncImage
                AsyncImage(url: URL(string: photoName)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    case .failure(_):
                        // Error loading from backend
                        ZStack {
                            Color.red.opacity(0.1)
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                                .font(.largeTitle)
                        }
                    case .empty:
                        // Loading placeholder
                        ZStack {
                            Color.gray.opacity(0.1)
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .onAppear {
                    print("📸 Loading backend photo: \(photoName)")
                }
            } else if let uiImage = UIImage(named: photoName) {
                // Load from asset catalog (for sample dogs like "dog_Max")
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                .onAppear {
                    print("📸 Loading asset photo: \(photoName)")
                }
            } else {
                // Fallback placeholder
                ZStack {
                    Color.clear
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.6))
                }
                .onAppear {
                    print("📸 Fallback placeholder for: \(photoName)")
                }
            }
        }
    }
}

struct AcatarView: View {
    let photoName: String
    
    var body: some View {
        AsyncImage(url: URL(string: photoName)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(Circle())
                .frame(width: 50, height: 50)
        } placeholder: {
            ProgressView()
        }
    }
}

struct FullScreenPhotoView: View {
    let photoNames: [String]
    @State private var currentIndex: Int
    let onDismiss: () -> Void
    
    init(photoNames: [String], initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.photoNames = photoNames
        self._currentIndex = State(initialValue: initialIndex)
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            TabView(selection: $currentIndex) {
                ForEach(0..<photoNames.count, id: \.self) { index in
                    ZoomablePhotoView(imageName: photoNames[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            
//            // Close button
//            VStack {
//                HStack {
//                    Spacer()
//                    Button(action: onDismiss) {
//                        Image(systemName: "xmark.circle.fill")
//                            .font(.title)
//                            .foregroundColor(.white)
//                            .padding()
//                            .shadow(radius: 2)
//                    }
//                }
//                Spacer()
//            }
        }
    }
}

// Using the shared ZoomablePhotoView implementation from ZoomablePhotoView.swift

struct PhotoGalleryView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoGalleryView(photoNames: ["dog_Creamie", "dog_Max"])
            .frame(height: 300)
    }
} 
