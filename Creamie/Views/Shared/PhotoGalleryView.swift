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
    @State private var cachedImage: UIImage?
    @State private var loadState: LoadState = .idle
    
    private enum LoadState {
        case idle, loading, loaded, failed
    }
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image = cachedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else if loadState == .failed {
                    ZStack {
                        Color.red.opacity(0.1)
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                            .font(.largeTitle)
                    }
                } else if loadState == .loading {
                    ZStack {
                        Color.gray.opacity(0.1)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    }
                } else {
                    Color.clear
                }
            }
            .task(id: photoName) {
                await loadImage(targetSize: geometry.size)
            }
        }
        .onDisappear {
            Task { await ImagePipeline.shared.cancelDownload(for: photoName) }
        }
    }
    
    private func loadImage(targetSize: CGSize) async {
        // Check if it's a local asset
        if !photoName.hasPrefix("https://") {
            if let uiImage = UIImage(named: photoName) {
                cachedImage = uiImage
                loadState = .loaded
            } else {
                loadState = .failed
            }
            return
        }
        
        // Download and downsample via ImagePipeline
        loadState = .loading
        
        do {
            let image = try await ImagePipeline.shared.image(for: photoName, targetSize: targetSize)
            cachedImage = image
            loadState = .loaded
        } catch {
            loadState = .failed
        }
    }
}

struct AcatarView: View {
    let photoName: String
    @State private var cachedImage: UIImage?
    @State private var loadFailed = false
    
    /// AcatarView displays at 50×50 points; request 50pt thumbnail
    /// (ImagePipeline multiplies by scale internally for 150×150 pixels at 3x).
    private let thumbnailSize = CGSize(width: 50, height: 50)
    
    var body: some View {
        Group {
            if let image = cachedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(Circle())
                    .frame(width: 50, height: 50)
            } else if loadFailed {
                Image(systemName: "pawprint.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(Circle())
                    .frame(width: 50, height: 50)
                    .foregroundColor(.gray)
            } else {
                ProgressView()
                    .frame(width: 50, height: 50)
            }
        }
        .task(id: photoName) {
            cachedImage = nil
            loadFailed = false
            
            guard !photoName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                loadFailed = true
                return
            }
            
            guard photoName.hasPrefix("https://") else {
                // Local asset or invalid — no pipeline needed
                if let uiImage = UIImage(named: photoName) {
                    cachedImage = uiImage
                } else {
                    loadFailed = true
                }
                return
            }
            
            do {
                let image = try await ImagePipeline.shared.image(for: photoName, targetSize: thumbnailSize)
                cachedImage = image
            } catch {
                loadFailed = true
            }
        }
        .onDisappear {
            Task { await ImagePipeline.shared.cancelDownload(for: photoName) }
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
