import SwiftUI
import CoreLocation
import PhotosUI

struct AddDogView: View {
    @ObservedObject var viewModel: DogProfileViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var selectedBreed: DogBreed = .labrador
    @State private var age: Int = 1
    @State private var interestText: String = ""
    @State private var interests: [String] = []
    @State private var showingDeleteAlert = false
    @State private var interestToDelete: String = ""
    
    // Photo selection
    @State private var selectedItems: [PhotosPickerItem?] = [nil, nil, nil, nil, nil]
    @State private var selectedImages: [UIImage?] = [nil, nil, nil, nil, nil]
    @State private var currentEditingIndex: Int? = nil
    
    // Maximum number of photos allowed
    private let maxPhotos = 5
    
    // TODO: Default location (Los Angeles area) - in a real app, you might use user's location
    @State private var location = Location(latitude: 34.0522, longitude: -118.2437)
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        age > 0
        // Interests are now optional
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Photos")) {
                    VStack(spacing: 16) {
                        Text("Add up to 5 photos")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
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
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Basic Information")) {
                    TextField("Dog's Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Picker("Breed", selection: $selectedBreed) {
                        ForEach(DogBreed.allCases, id: \.self) { breed in
                            Text(breed.rawValue).tag(breed)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Stepper("Age: \(age) year\(age == 1 ? "" : "s")", value: $age, in: 1...20)
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
                
                Section(header: Text("Location")) {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(.blue)
                        Text("Los Angeles Area")
                        Spacer()
                        Text("📍")
                    }
                    .padding(.vertical, 4)
                    
                    Text("Location will be set to your current area")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add New Dog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveDog()
                    }
                    .disabled(!isFormValid)
                    .foregroundColor(isFormValid ? .blue : .gray)
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
            location: location,
            photos: validImages.isEmpty ? nil : validImages
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
