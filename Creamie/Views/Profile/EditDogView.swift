import SwiftUI
import CoreLocation
import PhotosUI

struct EditDogView: View {
    // MARK: - View Models & Environment
    @ObservedObject var dogProfileViewModel: DogProfileViewModel
    @ObservedObject var dogHealthViewModel: DogHealthViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject var authService: AuthenticationService
    
    // MARK: - Dog Data
    let dogToEdit: Dog
    
    // MARK: - Basic Information State
    @State private var name: String
    @State private var selectedBreed: DogBreed
    @State private var age: Int
    @State private var aboutMe: String
    @State private var ownerName: String
    
    // MARK: - Interests State
    @State private var interestText: String = ""
    @State private var interests: [String]
    
    // MARK: - Healthcare State
    @State private var weightKg: String = ""
    @State private var vaccinationName: String = ""
    @State private var veterinarianName: String = ""
    @State private var groomingService: String = ""
    @State private var groomingLocation: String = ""
    @State private var medicationName: String = ""
    @State private var medicationDosage: String = ""
    @State private var medicationFrequency: String = ""
    @State private var vetVisitPurpose: String = ""
    @State private var vetClinicName: String = ""
    @State private var generalHealthNotes: String = ""
    // MARK: - Photo Management State
    @State private var selectedItems: [PhotosPickerItem?] = Array(repeating: nil, count: 6)
    @State private var selectedImages: [UIImage?] = Array(repeating: nil, count: 6)
    @State private var existingPhotos: [String] = []
    @State private var currentEditingIndex: Int? = nil
    @State private var photosToDelete: [String] = []
    
    // MARK: - Constants
    private let maxPhotos = 6
    private let minPhotos = 1
    
    // MARK: - Initializer
    init(dogProfileViewModel: DogProfileViewModel, dogHealthViewModel: DogHealthViewModel, dogToEdit: Dog) {
        self.dogProfileViewModel = dogProfileViewModel
        self.dogHealthViewModel = dogHealthViewModel
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
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                photosSection
                basicInformationSection
                interestsSection
                aboutMeSection
                healthcareSection
                locationSection
            }
            .navigationTitle("Edit \(dogToEdit.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .photosPicker(
                isPresented: photosPickerBinding,
                selection: selectedItemBinding,
                matching: .images
            )
            .task {
                await dogHealthViewModel.loadHealthData(for: dogToEdit.id)
                loadExistingHealthData()
            }
        }
    }
}

// MARK: - Form Sections
extension EditDogView {
    private var photosSection: some View {
        Section(header: Text("Photos")) {
            VStack(spacing: 16) {
                photoGrid
                photoRequirementMessage
            }
            .padding(.vertical, 8)
        }
    }
    
    private var basicInformationSection: some View {
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
    }
    
    private var interestsSection: some View {
        Section(header: Text("Interests")) {
            interestInputRow
            interestsDisplay
            interestsHelpText
        }
    }
    
    private var aboutMeSection: some View {
        Section(header: Text("About Me")) {
            TextField("Tell us about your dog (optional)", text: $aboutMe, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...10)
            
            Text("Share what makes your dog special")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var locationSection: some View {
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
    
    private var healthcareSection: some View {
        Section(header: Text("Healthcare (Optional)")) {
            VStack(alignment: .leading, spacing: 16) {
                // Weight Section
                Group {
                    Text("Weight")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Weight (kg)", text: $weightKg)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Divider()
                
                // Vaccination Section
                Group {
                    Text("Vaccination")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Vaccine Name", text: $vaccinationName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Veterinarian Name", text: $veterinarianName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Divider()
                
                // Grooming Section
                Group {
                    Text("Grooming")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Grooming Service", text: $groomingService)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Location", text: $groomingLocation)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Divider()
                
                // Medication Section
                Group {
                    Text("Medication")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Medication Name", text: $medicationName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    HStack(spacing: 8) {
                        TextField("Dosage", text: $medicationDosage)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        TextField("Frequency", text: $medicationFrequency)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                Divider()
                
                // Vet Visit Section
                Group {
                    Text("Vet Visit")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Visit Purpose", text: $vetVisitPurpose)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Clinic Name", text: $vetClinicName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Divider()
                
                // General Notes Section
                Group {
                    Text("General Health Notes")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Additional health notes", text: $generalHealthNotes, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
            }
            .padding(.vertical, 8)

            Text("Healthcare information helps track your dog's wellbeing. Only fill out sections that need updating.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Photo Components
extension EditDogView {
    private var photoGrid: some View {
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
    }
    
    @ViewBuilder
    private var photoRequirementMessage: some View {
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
}

// MARK: - Interest Components
extension EditDogView {
    private var interestInputRow: some View {
        HStack {
            TextField("Add an interest", text: $interestText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Add") {
                addInterest()
            }
            .disabled(interestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    @ViewBuilder
    private var interestsDisplay: some View {
        if !interests.isEmpty {
            FlowLayout(spacing: 8) {
                ForEach(interests, id: \.self) { interest in
                    InterestChip(
                        interest: interest,
                        onDelete: { removeInterest(interest) }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private var interestsHelpText: some View {
        if interests.isEmpty {
            Text("Interests are optional")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

// MARK: - Toolbar
extension EditDogView {
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
            }
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { updateDog() }) {
                Image(systemName: "checkmark")
            }
            .disabled(!isFormValid)
            .foregroundColor(isFormValid ? Color.primary : .gray)
        }
    }
}

// MARK: - Computed Properties
extension EditDogView {
    private var locationDisplayText: String {
        locationManager.userLocation != nil ? "Current Location" : "Using Existing Location"
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
}

// MARK: - Photo Picker Bindings
extension EditDogView {
    private var photosPickerBinding: Binding<Bool> {
        Binding(
            get: { currentEditingIndex != nil },
            set: { if !$0 { currentEditingIndex = nil } }
        )
    }
    
    private var selectedItemBinding: Binding<PhotosPickerItem?> {
        Binding(
            get: {
                guard let index = currentEditingIndex else { return nil }
                return selectedItems[index]
            },
            set: { newValue in
                guard let index = currentEditingIndex else { return }
                selectedItems[index] = newValue
                
                if let item = newValue {
                    Task {
                        await processSelectedImage(item: item, at: index)
                    }
                }
            }
        )
    }
}

// MARK: - Helper Methods
extension EditDogView {
    private func deleteExistingPhoto(at index: Int) {
        guard index < existingPhotos.count else { return }
        existingPhotos.remove(at: index)
    }
    
    private func deleteNewPhoto(at index: Int) {
        selectedItems[index] = nil
        selectedImages[index] = nil
    }
    
    private func addInterest() {
        let trimmedInterest = interestText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInterest.isEmpty && !interests.contains(trimmedInterest) else { return }
        
        interests.append(trimmedInterest)
        interestText = ""
    }
    
    private func removeInterest(_ interest: String) {
        interests.removeAll { $0 == interest }
    }
    
    private func processSelectedImage(item: PhotosPickerItem, at index: Int) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        
        let resizedImage = uiImage.resized(toWidth: 1000)
        selectedImages[index] = resizedImage
        
        // Mark existing photo for deletion if we're replacing it
        if index < existingPhotos.count {
            let photoToDelete = existingPhotos[index]
            photosToDelete.append(photoToDelete)
        }
    }
    
    private func updateDog() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let newPhotos = selectedImages.compactMap { $0 }
        let aboutMeString = aboutMe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
            nil : aboutMe.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Update dog profile
        dogProfileViewModel.updateDog(
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
        
        // Update health data
        Task {
            await updateHealthData()
        }
        
        dismiss()
    }
    
    private func loadExistingHealthData() {
        // Load current weight from latest record
        if let latestWeight = dogHealthViewModel.weightHistory.last {
            weightKg = String(latestWeight.weightKg)
        }
        
        // Load latest vaccination info
        if let latestVaccination = dogHealthViewModel.vaccinations.last {
            vaccinationName = latestVaccination.vaccineName
            veterinarianName = latestVaccination.veterinarianName ?? ""
        }
        
        // Load latest grooming info
        if let latestGrooming = dogHealthViewModel.groomingAppointments.last {
            groomingService = latestGrooming.groomingService ?? ""
            groomingLocation = latestGrooming.location ?? ""
        }
        
        // Load current medication info
        if let currentMedication = dogHealthViewModel.currentMedications().first {
            medicationName = currentMedication.medicationName
            medicationDosage = currentMedication.dosage
            medicationFrequency = currentMedication.frequency
        }
        
        // Load latest vet appointment info
        if let latestVetVisit = dogHealthViewModel.vetAppointments.last {
            vetVisitPurpose = latestVetVisit.purpose
            vetClinicName = latestVetVisit.clinicName ?? ""
        }
    }
    
    private func updateHealthData() async {
        var vaccination: VaccinationRecord? = nil
        var grooming: GroomingAppointment? = nil
        var medication: Medication? = nil
        var vetAppointment: VetAppointment? = nil
        
        // Create vaccination record if provided
        if !vaccinationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            vaccination = VaccinationRecord(
                vaccineName: vaccinationName,
                vaccinationDate: Date(),
                expirationDate: Date().addingTimeInterval(365 * 24 * 60 * 60), // 1 year default
                veterinarianName: veterinarianName.isEmpty ? nil : veterinarianName,
                clinicName: nil,
                notes: generalHealthNotes.isEmpty ? nil : generalHealthNotes
            )
        }
        
        // Create grooming record if provided
        if !groomingService.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            grooming = GroomingAppointment(
                appointmentDate: Date(),
                groomingService: groomingService,
                location: groomingLocation.isEmpty ? nil : groomingLocation,
                notes: generalHealthNotes.isEmpty ? nil : generalHealthNotes,
                isCompleted: true
            )
        }
        
        // Create medication record if provided
        if !medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            medication = Medication(
                medicationName: medicationName,
                dosage: medicationDosage.isEmpty ? "As prescribed" : medicationDosage,
                frequency: medicationFrequency.isEmpty ? "As needed" : medicationFrequency,
                startDate: Date(),
                endDate: nil, // Open-ended unless specified
                notes: generalHealthNotes.isEmpty ? nil : generalHealthNotes
            )
        }
        
        // Create vet appointment record if provided
        if !vetVisitPurpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            vetAppointment = VetAppointment(
                purpose: vetVisitPurpose,
                appointmentDate: Date(),
                veterinarianName: veterinarianName.isEmpty ? nil : veterinarianName,
                clinicName: vetClinicName.isEmpty ? nil : vetClinicName,
                notes: generalHealthNotes.isEmpty ? nil : generalHealthNotes,
                isCompleted: true
            )
        }
        
        // Save all health data in one API call
        await dogHealthViewModel.addHealthDataFromForm(
            weight: Double(weightKg),
            weightNotes: generalHealthNotes.isEmpty ? nil : generalHealthNotes,
            vaccination: vaccination,
            grooming: grooming,
            medication: medication,
            vetAppointment: vetAppointment
        )
    }
}

// MARK: - Supporting Views
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
                newImageView(image: newImage)
                deleteButton(action: onDeleteNew, color: .pink)
            } else if let existingPhoto = existingPhoto {
                existingPhotoView(photoName: existingPhoto)
                deleteButton(action: onDeleteExisting, color: .pink)
            } else {
                placeholderView
            }
        }
    }
    
    private func newImageView(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.purple, lineWidth: 3)
            )
            .onTapGesture(perform: onSelectPhoto)
    }
    
    private func existingPhotoView(photoName: String) -> some View {
        DogPhotoView(photoName: photoName)
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.purple, lineWidth: 2)
            )
            .onTapGesture(perform: onSelectPhoto)
    }
    
    private var placeholderView: some View {
        VStack {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 30))
                .foregroundColor(Color.pink.opacity(0.3))
        }
        .frame(width: 100, height: 100)
        .background(Color.purple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: onSelectPhoto)
    }
    
    private func deleteButton(action: @escaping () -> Void, color: Color) -> some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(color)
                .background(Circle().fill(Color.white))
        }
        .contentShape(Circle())
        .offset(x: 6, y: -6)
    }
}

// MARK: - Preview
#Preview {
    EditDogView(
        dogProfileViewModel: DogProfileViewModel(),
        dogHealthViewModel: DogHealthViewModel(),
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
