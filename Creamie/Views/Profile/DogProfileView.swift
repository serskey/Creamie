import SwiftUI
import MapKit

struct FullScreenMapView: View {
    let dog: Dog
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition
    
    init(dog: Dog) {
        self.dog = dog
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: dog.location,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )))
    }
    
    var body: some View {
        NavigationView {
            Map(position: $cameraPosition) {
                Annotation(dog.name, coordinate: dog.location) {
                    Image(systemName: "pawprint.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("\(dog.name)'s Location")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        let coordinates = dog.location
                        let url = URL(string: "maps://?saddr=&daddr=\(coordinates.latitude),\(coordinates.longitude)")
                        if let url = url, UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

struct DogProfileView: View {
    @StateObject private var viewModel = DogProfileViewModel()
    @State private var selectedDog: Dog?
    @State private var isPhotoZoomed: Bool = false
    @State private var showFullMap: Bool = false
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading your dogs...")
                } else if let error = viewModel.error {
                    VStack {
                        Text("Error loading dogs")
                            .foregroundColor(.red)
                        Button("Try Again") {
                            Task {
                                await viewModel.fetchDogs()
                            }
                        }
                    }
                } else if viewModel.dogs.isEmpty {
                    VStack {
                        Text("No dogs found")
                            .foregroundColor(.secondary)
                        Button("Refresh") {
                            Task {
                                await viewModel.fetchDogs()
                            }
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.dogs) { dog in
                                DogCard(dog: dog)
                                    .onTapGesture {
                                        selectedDog = dog
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My Dogs")
        }
        .task {
            await viewModel.fetchDogs()
        }
        .sheet(item: $selectedDog) { dog in
            DogDetailView(dog: dog)
        }
    }
}

struct DogCard: View {
    let dog: Dog
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(dog.photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(dog.name)
                    .font(.title2.bold())
                
                Text("\(dog.breed.rawValue) · \(dog.age) years old")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2)
    }
}

struct DogDetailView: View {
    let dog: Dog
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition
    @State private var isPhotoZoomed: Bool = false
    @State private var showFullMap: Bool = false
    
    init(dog: Dog) {
        self.dog = dog
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: dog.location,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with photo
                ZStack(alignment: .top) {
                    Image(dog.photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 300)
                        .clipped()
                        .onTapGesture {
                            isPhotoZoomed = true
                        }
                    
                    // Custom back button overlay
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        .padding(.leading)
                        Spacer()
                    }
                    .padding(.top, 60)
                }
                
                VStack(alignment: .leading, spacing: 24) {
                    // Basic Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(dog.name)
                            .font(.title.bold())
                        
                        Text("\(dog.breed.rawValue) · \(dog.age) years old")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    // Interests Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Interests")
                            .font(.headline)
                        
                        FlowLayout(spacing: 8) {
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
                    
                    // Location Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Location")
                                .font(.headline)
                        }
                        
                        Map(position: $cameraPosition) {
                            Annotation(dog.name, coordinate: dog.location) {
                                Image(systemName: "pawprint.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.blue)
                            }
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            showFullMap = true
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea()
        .fullScreenCover(isPresented: $isPhotoZoomed) {
            ZoomablePhotoView(imageName: dog.photo)
        }
        .fullScreenCover(isPresented: $showFullMap) {
            FullScreenMapView(dog: dog)
        }
    }
}

// Helper view for wrapping interests tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: position.x + bounds.minX, y: position.y + bounds.minY),
                proposal: .unspecified
            )
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let viewSize = subview.sizeThatFits(.unspecified)
                
                if currentX + viewSize.width > maxWidth {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += viewSize.width + spacing
                lineHeight = max(lineHeight, viewSize.height)
            }
            
            size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
