import SwiftUI

struct ZoomablePhotoView: View {
    let imageName: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale = min(max(scale * delta, 1), 4)
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation {
                        scale = scale > 1 ? 1 : 2
                        if scale == 1 {
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
                }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}

struct DogPreviewCard: View {
    let dog: Dog
    let onGetDirections: () -> Void
    let onClose: () -> Void
    @State private var cardOffset: CGFloat = 1000
    @State private var isPhotoZoomed: Bool = false
    @State private var showProfile: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(dog.photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)
                    .onTapGesture {
                        isPhotoZoomed = true
                    }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(dog.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(dog.breed.rawValue), \(dog.age) years")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: { showProfile = true }) {
                        Label("View Profile", systemImage: "pawprint.circle")
                            .font(.footnote.bold())
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        let coordinates = dog.location
                        let url = URL(string: "maps://?saddr=&daddr=\(coordinates.latitude),\(coordinates.longitude)")
                        if let url = url, UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Text("Interests")
                .font(.headline)
                .padding(.top, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(dog.interests, id: \.self) { interest in
                        Text(interest)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
        .offset(y: cardOffset)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                cardOffset = 0
            }
        }
        .fullScreenCover(isPresented: $isPhotoZoomed) {
            ZoomablePhotoView(imageName: dog.photo)
        }
        .sheet(isPresented: $showProfile) {
            DogDetailView(dog: dog)
        }
    }
} 
