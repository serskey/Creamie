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
    @State private var interests: [String] = []

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

    // ✅ FIX: Use fixed slots so indices never shift
    @State private var existingPhotoSlots: [String?] = Array(repeating: nil, count: 6)

    @State private var currentEditingIndex: Int? = nil
    @State private var photosToDelete: [String] = []

    // Track if user is replacing an existing photo in the slot
    @State private var replacingExistingPhotoInSlot: String? = nil
    
    // Prevent rapid-fire deletions
    @State private var isDeletingPhoto: Bool = false

    // MARK: - Constants
    private let maxPhotos = 6
    private let minPhotos = 1

    // MARK: - Initializer
    init(dogProfileViewModel: DogProfileViewModel, dogHealthViewModel: DogHealthViewModel, dogToEdit: Dog) {
        self.dogProfileViewModel = dogProfileViewModel
        self.dogHealthViewModel = dogHealthViewModel
        self.dogToEdit = dogToEdit

        self._name = State(initialValue: dogToEdit.name)
        self._selectedBreed = State(initialValue: dogToEdit.breed)
        self._age = State(initialValue: dogToEdit.age)
        self._interests = State(initialValue: dogToEdit.interests ?? [])
        self._aboutMe = State(initialValue: dogToEdit.aboutMe ?? "")
        self._ownerName = State(initialValue: dogToEdit.ownerName ?? "")

        // ✅ Put existing photos into fixed slots [0...5]
        var slots = Array<String?>(repeating: nil, count: 6)
        for (i, p) in dogToEdit.photos.prefix(6).enumerated() {
            slots[i] = p
        }
        self._existingPhotoSlots = State(initialValue: slots)
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
            .toolbar { toolbarContent }
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
                let capturedIndex = index  // ✅ Explicit capture to prevent closure issues
                PhotoSlotBlock(
                    index: capturedIndex,
                    existingPhoto: existingPhotoSlots[capturedIndex],
                    newImage: selectedImages[capturedIndex],
                    onSelectPhoto: {
                        // If you tap a slot that currently contains an existing photo,
                        // we treat it as a replacement selection.
                        currentEditingIndex = capturedIndex
                        replacingExistingPhotoInSlot = existingPhotoSlots[capturedIndex]
                    },
                    onDeleteExisting: {
                        deleteExistingPhoto(at: capturedIndex)
                    },
                    onDeleteNew: {
                        deleteNewPhoto(at: capturedIndex)
                    }
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

            Button(action: { addInterest() }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                    .accessibilityLabel("Add Interest")
            }
            .disabled(interestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @ViewBuilder
    private var interestsDisplay: some View {
        if !interests.isEmpty {
            SimpleFlowLayoutEdit(items: interests) { interest in
                InterestChip(
                    interest: interest,
                    onDelete: { removeInterest(interest) }
                )
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

    private var existingPhotosCompact: [String] {
        existingPhotoSlots.compactMap { $0 }
    }

    private var hasMinimumPhotos: Bool {
        let newImagesCount = selectedImages.compactMap { $0 }.count
        let totalPhotos = existingPhotosCompact.count + newImagesCount
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
            set: { if !$0 { currentEditingIndex = nil; replacingExistingPhotoInSlot = nil } }
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
                    Task { await processSelectedImage(item: item, at: index) }
                }
            }
        )
    }
}

// MARK: - Helper Methods
extension EditDogView {
    private func deleteExistingPhoto(at index: Int) {
        // Prevent rapid-fire deletions
        guard !isDeletingPhoto else {
            print("⚠️ Already deleting a photo, ignoring duplicate tap")
            return
        }
        
        // ✅ Bounds checking
        guard index >= 0, index < maxPhotos else {
            print("⚠️ Invalid index \(index) for deleteExistingPhoto - out of bounds")
            return
        }
        
        // ✅ Validate slot contains a photo
        guard let photo = existingPhotoSlots[index] else {
            print("⚠️ No existing photo in slot \(index) to delete")
            return
        }

        isDeletingPhoto = true
        
        print("🗑️ DELETE BUTTON TAPPED - Deleting EXISTING photo from slot \(index): \(photo)")
        print("📸 Existing photos BEFORE deletion: \(existingPhotoSlots)")
        
        // Clear the slot
        existingPhotoSlots[index] = nil
        photosToDelete.append(photo)
        
        print("📸 Existing photos AFTER deletion: \(existingPhotoSlots)")
        print("🧾 Photos marked for deletion: \(photosToDelete)")
        
        // ✅ Critical: reset these so picker doesn't open
        replacingExistingPhotoInSlot = nil
        currentEditingIndex = nil
        
        // Reset deletion flag after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isDeletingPhoto = false
        }
    }

    private func deleteNewPhoto(at index: Int) {
        // Prevent rapid-fire deletions
        guard !isDeletingPhoto else {
            print("⚠️ Already deleting a photo, ignoring duplicate tap")
            return
        }
        
        // ✅ Bounds checking
        guard index >= 0, index < maxPhotos else {
            print("⚠️ Invalid index \(index) for deleteNewPhoto - out of bounds")
            return
        }
        
        // ✅ Validate slot contains a new image
        guard selectedImages[index] != nil else {
            print("⚠️ No new photo in slot \(index) to delete")
            return
        }
        
        isDeletingPhoto = true
        
        print("🗑️ Deleting NEW photo from slot \(index)")
        print("🖼️ Selected images BEFORE deletion: \(selectedImages.enumerated().filter { $0.element != nil }.map { $0.offset })")
        
        selectedItems[index] = nil
        selectedImages[index] = nil
        
        print("🖼️ Selected images AFTER deletion: \(selectedImages.enumerated().filter { $0.element != nil }.map { $0.offset })")
        
        // Reset deletion flag after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isDeletingPhoto = false
        }
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

    // ✅ FIX: replacement is based on the SLOT the user tapped (no shifting)
    private func processSelectedImage(item: PhotosPickerItem, at index: Int) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }

        let resizedImage = uiImage.resized(toWidth: 1000)

        await MainActor.run {
            selectedImages[index] = resizedImage

            // If this slot previously had an existing photo, mark it for deletion and clear the slot.
            if let oldPhoto = replacingExistingPhotoInSlot {
                print("♻️ Replacing existing photo in slot \(index): \(oldPhoto)")
                photosToDelete.append(oldPhoto)
                existingPhotoSlots[index] = nil
                replacingExistingPhotoInSlot = nil
            }

            print("📸 Existing after replace:", existingPhotosCompact)
            print("🧾 photosToDelete:", photosToDelete)
        }
    }

    private func updateDog() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let newPhotos = selectedImages.compactMap { $0 }
        let aboutMeString = aboutMe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : aboutMe.trimmingCharacters(in: .whitespacesAndNewlines)

        dogProfileViewModel.updateDog(
            dogId: dogToEdit.id,
            name: trimmedName,
            breed: selectedBreed,
            age: age,
            interests: interests,
            existingPhotos: existingPhotosCompact,      // ✅ compacted slots
            newPhotos: newPhotos,
            aboutMe: aboutMeString,
            photosToDelete: photosToDelete
        )

        Task { await updateHealthData() }
        dismiss()
    }

    private func loadExistingHealthData() {
        if let latestWeight = dogHealthViewModel.weightHistory.last {
            weightKg = String(latestWeight.weightKg)
        }

        if let latestVaccination = dogHealthViewModel.vaccinations.last {
            vaccinationName = latestVaccination.vaccineName
            veterinarianName = latestVaccination.veterinarianName ?? ""
        }

        if let latestGrooming = dogHealthViewModel.groomingAppointments.last {
            groomingService = latestGrooming.groomingService ?? ""
            groomingLocation = latestGrooming.location ?? ""
        }

        if let currentMedication = dogHealthViewModel.currentMedications().first {
            medicationName = currentMedication.medicationName
            medicationDosage = currentMedication.dosage
            medicationFrequency = currentMedication.frequency
        }

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

        if !vaccinationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            vaccination = VaccinationRecord(
                vaccineName: vaccinationName,
                vaccinationDate: Date(),
                expirationDate: Date().addingTimeInterval(365 * 24 * 60 * 60),
                veterinarianName: veterinarianName.isEmpty ? nil : veterinarianName,
                clinicName: nil,
                notes: generalHealthNotes.isEmpty ? nil : generalHealthNotes
            )
        }

        if !groomingService.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            grooming = GroomingAppointment(
                appointmentDate: Date(),
                groomingService: groomingService,
                location: groomingLocation.isEmpty ? nil : groomingLocation,
                notes: generalHealthNotes.isEmpty ? nil : generalHealthNotes,
                isCompleted: true
            )
        }

        if !medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            medication = Medication(
                medicationName: medicationName,
                dosage: medicationDosage.isEmpty ? "As prescribed" : medicationDosage,
                frequency: medicationFrequency.isEmpty ? "As needed" : medicationFrequency,
                startDate: Date(),
                endDate: nil,
                notes: generalHealthNotes.isEmpty ? nil : generalHealthNotes
            )
        }

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

// MARK: - Simple Flow Layout
private struct SimpleFlowLayoutEdit<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let content: (Data.Element) -> Content

    @State private var totalHeight = CGFloat.zero

    var body: some View {
        VStack {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(Array(items), id: \.self) { item in
                content(item)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > geometry.size.width) {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if item == items.last {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { d in
                        let result = height
                        if item == items.last {
                            height = 0
                        }
                        return result
                    })
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: ViewHeightKey.self, value: geo.frame(in: .local).size.height)
            }
        )
        .onPreferenceChange(ViewHeightKey.self) { value in
            self.totalHeight = value
        }
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
                deleteButton(
                    action: {
                        print("🗑️ User tapped delete NEW photo on slot \(index)")
                        onDeleteNew()
                    },
                    color: .pink,
                    label: "delete-new-\(index)"
                )
            } else if let existingPhoto = existingPhoto {
                existingPhotoView(photoName: existingPhoto)
                deleteButton(
                    action: {
                        print("🗑️ User tapped delete EXISTING photo on slot \(index)")
                        onDeleteExisting()
                    },
                    color: .pink,
                    label: "delete-existing-\(index)"
                )
            } else {
                placeholderView
            }
        }
        .id("photo-slot-\(index)")
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

    private func deleteButton(action: @escaping () -> Void, color: Color, label: String) -> some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(color)
                .background(Circle().fill(Color.white))
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Circle())
        .accessibilityIdentifier(label)
        .id(label)
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
    .environmentObject(LocationManager())
    .environmentObject(AuthenticationService.mock)
}
