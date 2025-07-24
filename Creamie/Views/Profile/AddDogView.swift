import SwiftUI
import CoreLocation
import PhotosUI

struct AddDogView: View {
    @ObservedObject var viewModel: DogProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    
    @State private var name: String = ""
    @State private var selectedBreed: DogBreed = .cockapoo
    @State private var age: Int = 1
    @State private var interestText: String = ""
    @State private var interests: [String] = []
    @State private var aboutMe: String = ""
    @State private var ownerName: String = ""
    @State private var showingDeleteAlert = false
    @State private var interestToDelete: String = ""
    
    // Photo selection
    @State private var selectedItems: [PhotosPickerItem?] = [nil, nil, nil, nil, nil]
    @State private var selectedImages: [UIImage?] = [nil, nil, nil, nil, nil]
    @State private var currentEditingIndex: Int? = nil
    
    // Generate a unique owner ID for each new dog
    private let ownerId = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!
    
    // Maximum number of photos allowed
    private let maxPhotos = 5
    
    // Minimum number of photos acquired
    private let minPhotos = 2
    
    // Computed property to get current location or default
    private var currentLocation: Location {
        if let userLocation = locationManager.userLocation {
            return Location(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        } else {
            // Fallback to Los Angeles area if no location available
            return Location(latitude: 34.0522, longitude: -118.2437)
        }
    }
    
    // Location display properties
    private var locationDisplayText: String {
        if locationManager.userLocation != nil {
            return "Current Location"
        } else {
            return "Los Angeles Area (Default)"
        }
    }
    
    private var locationDescriptionText: String {
        if locationManager.userLocation != nil {
            return "Using your current location"
        } else {
            return "Using default location - enable location access for precise positioning"
        }
    }
    
    private var hasMinimumPhotos: Bool {
        let validImages = selectedImages.compactMap { $0 }
        return validImages.count >= minPhotos
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        age > 0 &&
        hasMinimumPhotos
        // Interests and AbooutMe are now optional
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Photos")) {
                    VStack(spacing: 16) {
                        // Grid of photo upload blocks
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(0..<maxPhotos, id: \.self) { index in
                                PhotoUploadBlock(
                                    image: selectedImages[index],
                                    index: index,
                                    onSelect: { currentEditingIndex = index },
                                    onDelete: { deletePhoto(at: index) }
                                )
                            }
                        }
                        
                        // Photo requirement message
                        if !hasMinimumPhotos {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.orange)
                                Text("Please add at least \(minPhotos) photos to continue")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Basic Information")) {
                    TextField("Dog's Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Picker("Breed", selection: $selectedBreed) {
                        ForEach(DogBreed.sortedBreeds, id: \.self) { breed in
                            Text(breed.rawValue).tag(breed)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Stepper("Age: \(age) year\(age == 1 ? "" : "s")", value: $age, in: 1...50)
                }
                
                Section(header: Text("Interests")) {
                    HStack {
                        TextField("Add an interest", text: $interestText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Add") {
                            addInterest()
                        }
                        .disabled(interestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    // TODO: fix this, not working
                    if !interests.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(interests, id: \.self) { interest in
                                InterestChip(
                                    interest: interest,
                                    onDelete: {
                                        removeInterest(interest)
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if interests.isEmpty {
                        Text("Interests are optional")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section(header: Text("About Me")) {
                    TextField("Tell us about your dog (optional)", text: $aboutMe, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...10)
                    
                    Text("Share what makes your dog special")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Owner Information")) {
                    TextField("Your name", text: $ownerName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("This will be shown to other dog owners")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Location")) {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(locationManager.userLocation != nil ? .blue : .orange)
                        Text(locationDisplayText)
                        Spacer()
                        Text("📍")
                    }
                    .padding(.vertical, 4)
                    
                    Text(locationDescriptionText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add New Dog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        saveDog()
                    }) {
                        Image(systemName: "checkmark")
                    }
                    .disabled(!isFormValid)
                    .foregroundColor(isFormValid ? Color.primary : .gray)
                }
            }
            .photosPicker(
                isPresented: Binding(
                    get: { currentEditingIndex != nil },
                    set: { if !$0 { currentEditingIndex = nil } }
                ),
                selection: Binding(
                    get: { 
                        if let index = currentEditingIndex {
                            return selectedItems[index]
                        }
                        return nil
                    },
                    set: { newValue in
                        if let index = currentEditingIndex {
                            selectedItems[index] = newValue
                            
                            // Process the selected image
                            if let item = newValue {
                                Task {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        // Resize image to reasonable size
                                        let resizedImage = uiImage.resized(toWidth: 1000)
                                        selectedImages[index] = resizedImage
                                    }
                                }
                            }
                        }
                    }
                ),
                matching: .images
            )
        }

    }
    
    private func deletePhoto(at index: Int) {
        // TODO: right now it removes all photos not just one
        selectedItems[index] = nil
        selectedImages[index] = nil
    }
    
    private func addInterest() {
        let trimmedInterest = interestText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInterest.isEmpty && !interests.contains(trimmedInterest) {
            interests.append(trimmedInterest)
            interestText = ""
        }
    }
    
    private func removeInterest(_ interest: String) {
        interests.removeAll { $0 == interest }
    }
    
    private func saveDog() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Filter out nil images
        let validImages = selectedImages.compactMap { $0 }
        
        viewModel.addDog(
            name: trimmedName,
            breed: selectedBreed,
            age: age,
            interests: interests,
            location: currentLocation,
            photos: validImages,
            aboutMe: aboutMe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : aboutMe.trimmingCharacters(in: .whitespacesAndNewlines),
            ownerName: ownerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : ownerName.trimmingCharacters(in: .whitespacesAndNewlines),
            ownerId: ownerId,
            // TODO: toggle button to set dog's online status upon their choose,
            // mention they can change the status in setting as well, or add a button on the "My dog" page to easily toggle
            // Hardcode to online for now
            isOnline: true
        )
        dismiss()
    }
}

struct PhotoUploadBlock: View {
    let image: UIImage?
    let index: Int
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image = image {
                // Show the selected image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                    .onTapGesture {
                        onSelect()
                    }
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white))
                }
                .offset(x: 6, y: -6)
            } else {
                // Show the empty placeholder
                VStack {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                    
                    Text("Photo \(index + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 100, height: 100)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .onTapGesture {
                    onSelect()
                }
            }
        }
    }
}

struct InterestChip: View {
    let interest: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(interest)
                .font(.subheadline)
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .clipShape(Capsule())
    }
}

#Preview {
    AddDogView(viewModel: DogProfileViewModel())
}
