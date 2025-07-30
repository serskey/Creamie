import SwiftUI
import CoreLocation
import PhotosUI

// TODO: Retry on failure and fallback photo upload on failure
struct EditDogView: View {
    @ObservedObject var viewModel: DogProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject var authService: AuthenticationService
    
    // The dog being edited
    let dogToEdit: Dog
    
    @State private var name: String
    @State private var selectedBreed: DogBreed
    @State private var age: Int
    @State private var interestText: String = ""
    @State private var interests: [String]
    @State private var aboutMe: String
    @State private var ownerName: String
    @State private var showingDeleteAlert = false
    @State private var interestToDelete: String = ""
    
    // Photo selection
    @State private var selectedItems: [PhotosPickerItem?] = [nil, nil, nil, nil, nil, nil]
    @State private var selectedImages: [UIImage?] = [nil, nil, nil, nil, nil, nil]
    @State private var existingPhotos: [String] = []
    @State private var currentEditingIndex: Int? = nil
    @State private var photosToDelete: [String] = []
    
    // Maximum number of photos allowed
    private let maxPhotos = 6
    
    // Minimum number of photos required
    private let minPhotos = 1
    
    // Initialize with existing dog data
    init(viewModel: DogProfileViewModel, dogToEdit: Dog) {
        self.viewModel = viewModel
        self.dogToEdit = dogToEdit
        
        // Initialize state with existing dog data
        self._name = State(initialValue: dogToEdit.name)
        self._selectedBreed = State(initialValue: dogToEdit.breed)
        self._age = State(initialValue: dogToEdit.age)
        self._interests = State(initialValue: dogToEdit.interests ?? [])
        self._aboutMe = State(initialValue: dogToEdit.aboutMe ?? "")
        self._ownerName = State(initialValue: dogToEdit.ownerName ?? "")
        self._existingPhotos = State(initialValue: dogToEdit.photos)
    }
    
//    // Computed property to get current location or use dog's existing location
//    private var currentLocation: Location {
//        if let userLocation = locationManager.userLocation {
//            return Location(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
//        } else {
//            // Use dog's existing location if no current location available
//            return Location(latitude: dogToEdit.latitude, longitude: dogToEdit.longitude)
//        }
//    }
    
    // Location display properties
    private var locationDisplayText: String {
        if locationManager.userLocation != nil {
            return "Current Location"
        } else {
            return "Using Existing Location"
        }
    }
    
    private var locationDescriptionText: String {
        if locationManager.userLocation != nil {
            return "Using your current location"
        } else {
            return "Using dog's existing location - enable location access to update"
        }
    }
    
    private var hasMinimumPhotos: Bool {
        let newImagesCount = selectedImages.compactMap { $0 }.count
        let totalPhotos = existingPhotos.count + newImagesCount
        return totalPhotos >= minPhotos
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        age > 0 &&
        hasMinimumPhotos
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Photos")) {
                    VStack(spacing: 16) {
                        // Grid of 6 photo blocks (existing + new upload slots)
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(0..<maxPhotos, id: \.self) { index in
                                PhotoSlotBlock(
                                    index: index,
                                    existingPhoto: index < existingPhotos.count ? existingPhotos[index] : nil,
                                    newImage: selectedImages[index],
                                    onSelectPhoto: { currentEditingIndex = index },
                                    onDeleteExisting: { deleteExistingPhoto(at: index) },
                                    onDeleteNew: { deleteNewPhoto(at: index) }
                                )
                            }
                        }
                        
                        // Photo requirement message
                        if !hasMinimumPhotos {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.orange)
                                Text("Please keep at least \(minPhotos) photo")
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
                            Text(breed.rawValue)
                                .foregroundColor(Color.primary)
                                .tag(breed)
                        }
                    }
                    .pickerStyle(.automatic)
                    
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
                
                Section(header: Text("Location")) {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(locationManager.userLocation != nil ? .purple : .orange)
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
            .navigationTitle("Edit \(dogToEdit.name)")
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
                        updateDog()
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
                                        
                                        // Mark existing photo for deletion if we're replacing it
                                        if index < existingPhotos.count {
                                            let photoToDelete = existingPhotos[index]
                                            photosToDelete.append(photoToDelete)
                                            print("Marked existing photo \(photoToDelete) for deletion")
                                        }
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
    
    private func deleteExistingPhoto(at index: Int) {
        print("Deleting existing index: \(index)")
        if index < existingPhotos.count {
            existingPhotos.remove(at: index)
        }
    }
    
    private func deleteNewPhoto(at index: Int) {
        print("Deleting new index: \(index)")
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
    
    private func updateDog() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Filter out nil images
        let newPhotos = selectedImages.compactMap { $0 }
        let aboutMeString = aboutMe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : aboutMe.trimmingCharacters(in: .whitespacesAndNewlines)
        let remainingExistingPhotos = existingPhotos.filter { !photosToDelete.contains($0) }
        
        print("existingPhotos are: \(existingPhotos)")
        print("newPhotos are: \(newPhotos)")
        print("photosToDelete are: \(Array(photosToDelete))")
        
        viewModel.updateDog(
            dogId: dogToEdit.id,
            name: trimmedName,
            breed: selectedBreed,
            age: age,
            interests: interests,
            existingPhotos: existingPhotos,
            newPhotos: newPhotos,
            aboutMe: aboutMeString,
            photosToDelete: photosToDelete
        )
        dismiss()
    }
    
}

struct PhotoSlotBlock: View {
    let index: Int
    let existingPhoto: String?
    let newImage: UIImage?
    let onSelectPhoto: () -> Void
    let onDeleteExisting: () -> Void
    let onDeleteNew: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let newImage = newImage {
                // Show new uploaded image (highest priority)
                Image(uiImage: newImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.purple, lineWidth: 3)
                    )
                    .onTapGesture {
                        onSelectPhoto()
                    }
                
                // Delete button for new image
                Button(action: onDeleteNew) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color.pink)
                        .background(Circle().fill(Color.white))
                }
                .offset(x: 6, y: -6)
                
            } else if let existingPhoto = existingPhoto {
                // Show existing photo from server
                DogPhotoView(photoName: existingPhoto)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.purple, lineWidth: 2)
                    )
                    .onTapGesture {
                        onSelectPhoto()
                    }
                
                // Delete button for existing photo
                Button(action: onDeleteExisting) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color.pink)
                        .background(Circle().fill(Color.white))
                }
                .contentShape(Circle())
                .offset(x: 6, y: -6)
                
            } else {
                // Show empty placeholder for new photo upload
                VStack {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 30))
                        .foregroundColor(Color.pink.opacity(0.3))
                }
                .frame(width: 100, height: 100)
                .background(Color.purple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture {
                    onSelectPhoto()
                }
            }
        }
    }
}

struct ExistingPhotoBlock: View {
    let photoName: String
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Show the existing photo using DogPhotoView
            DogPhotoView(photoName: photoName)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue, lineWidth: 2)
                )
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.red)
                    .background(Circle().fill(Color.white))
            }
            .offset(x: 6, y: -6)
        }
    }
}

#Preview {
    EditDogView(
        viewModel: DogProfileViewModel(),
        dogToEdit: Dog(
            id: UUID(),
            name: "Buddy",
            breed: .goldenRetriever,
            age: 3,
            interests: ["Playing fetch", "Swimming"],
            aboutMe: "A friendly and energetic dog",
            photos: ["sample_photo1", "sample_photo2"],
            latitude: 34.0522,
            longitude: -118.2437,
            ownerId: UUID(),
            ownerName: "John Doe",
            isOnline: true,
            updatedAt: Date()
        )
    )
}
