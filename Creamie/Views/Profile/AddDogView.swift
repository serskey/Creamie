import SwiftUI
import CoreLocation
import PhotosUI

struct AddDogView: View {
    // MARK: - View Models & Environment
    @ObservedObject var dogProfileViewModel: DogProfileViewModel
    @ObservedObject var dogHealthViewModel: DogHealthViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject var authService: AuthenticationService
    
    // MARK: - Basic Information State
    @State private var name: String = ""
    @State private var selectedBreed: DogBreed = .cockapoo
    @State private var age: Int = 1
    @State private var aboutMe: String = ""
    
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
    
    // MARK: - Photo Selection State
    @State private var selectedItems: [PhotosPickerItem?] = Array(repeating: nil, count: 6)
    @State private var selectedImages: [UIImage?] = Array(repeating: nil, count: 6)
    @State private var currentEditingIndex: Int? = nil
    
    // MARK: - Constants
    private let maxPhotos = 6
    private let minPhotos = 1
    
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .photosPicker(
                isPresented: photosPickerBinding,
                selection: selectedItemBinding,
                matching: .images
            )
        }
    }
}

// MARK: - Form Sections
extension AddDogView {
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
    
    // MARK: - Fixed Interests Section
    private var interestsSection: some View {
        Section(header: Text("Interests")) {
            // Input row for adding interests
            HStack {
                TextField("Add an interest", text: $interestText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        addInterest()
                    }
                
                Button(action: {
                    addInterest()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                        .accessibilityLabel("Add Interest")
                }
                .disabled(interestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            if !interests.isEmpty {
                SimpleFlowLayout(items: interests) { interest in
                    InterestChip(
                        interest: interest,
                        onDelete: { removeInterest(interest) }
                    )
                }
                .padding(.vertical, 4)
            } else {
                Text("Interests are optional")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
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

            Text("Healthcare information helps track your dog's wellbeing. You can always update this later.")
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
}

// MARK: - Photo Components
extension AddDogView {
    private var photoGrid: some View {
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
    
    @ViewBuilder
    private var photoRequirementMessage: some View {
        if !hasMinimumPhotos {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(Color.purple)
                Text("Please add at least \(minPhotos) photo to continue")
                    .font(.caption)
                    .foregroundColor(.pink)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Toolbar
extension AddDogView {
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
            }
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { saveDog() }) {
                Image(systemName: "checkmark")
            }
            .disabled(!isFormValid)
            .foregroundColor(isFormValid ? Color.primary : .gray)
        }
    }
}

// MARK: - Computed Properties
extension AddDogView {
    private var currentLocation: Location {
        if let userLocation = locationManager.userLocation {
            return Location(
                latitude: userLocation.coordinate.latitude,
                longitude: userLocation.coordinate.longitude
            )
        } else {
            // Fallback to Los Angeles area if no location available
            return Location(latitude: 34.0522, longitude: -118.2437)
        }
    }
    
    private var locationDisplayText: String {
        locationManager.userLocation != nil ? "Current Location" : "Los Angeles Area (Default)"
    }
    
    private var locationDescriptionText: String {
        if locationManager.userLocation != nil {
            return "Using your current location"
        } else {
            return "Using default location - enable location access for precise positioning"
        }
    }
    
    private var hasMinimumPhotos: Bool {
        selectedImages.compactMap { $0 }.count >= minPhotos
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        age > 0 &&
        hasMinimumPhotos
    }
}

// MARK: - Photo Picker Bindings
extension AddDogView {
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
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            let resizedImage = uiImage.resized(toWidth: 1000)
                            selectedImages[index] = resizedImage
                        }
                    }
                }
            }
        )
    }
}

// MARK: - Helper Methods
extension AddDogView {
    private func deletePhoto(at index: Int) {
        selectedItems[index] = nil
        selectedImages[index] = nil
    }
    
    private func addInterest() {
        let trimmedInterest = interestText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInterest.isEmpty && !interests.contains(trimmedInterest) else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            interests.append(trimmedInterest)
        }
        interestText = ""
    }
    
    private func removeInterest(_ interest: String) {
        print("Remove interest \(interest)")
        if let index = interests.firstIndex(of: interest) {
            interests.remove(at: index)
        }
    }
    
    private func saveDog() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let validImages = selectedImages.compactMap { $0 }
        let aboutMeString = aboutMe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
            nil : aboutMe.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Save dog profile
        dogProfileViewModel.addDog(
            name: trimmedName,
            breed: selectedBreed,
            age: age,
            interests: interests,
            location: currentLocation,
            photos: validImages,
            aboutMe: aboutMeString,
            ownerName: authService.currentUser!.name,
            ownerId: authService.currentUser!.id,
            isOnline: true
        )
        
        // Save health info if provided
        Task {
            await saveHealthcareData()
        }
        
        dismiss()
    }
    
    // MARK: - Healthcare saving methods
    private func saveHealthcareData() async {
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

// MARK: - Simple Flow Layout
struct SimpleFlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Index == Int {
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

        let enumeratedItems = Array(items.enumerated())

        return ZStack(alignment: .topLeading) {
            ForEach(enumeratedItems, id: \.offset) { index, item in
                content(item)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > geometry.size.width) {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if index == enumeratedItems.count - 1 {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { d in
                        let result = height
                        if index == enumeratedItems.count - 1 {
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

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Supporting Views
struct PhotoUploadBlock: View {
    let image: UIImage?
    let index: Int
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image = image {
                selectedImageView(image: image)
                deleteButton()
            } else {
                placeholderView
            }
        }
    }
    
    private func selectedImageView(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.purple, lineWidth: 2)
            )
            .onTapGesture(perform: onSelect)
    }
    
    private func deleteButton() -> some View {
        Button(action: onDelete) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(Color.pink)
                .background(Circle().fill(Color.white))
        }
        .contentShape(Circle())
        .offset(x: 6, y: -6)
    }
    
    private var placeholderView: some View {
        VStack {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 30))
                .foregroundColor(Color.pink.opacity(0.3))
        }
        .frame(width: 100, height: 100)
        .background(Color.purple.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: onSelect)
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
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.pink.opacity(0.5))
        .foregroundColor(.white)
        .clipShape(Capsule())
    }
}

// Add this extension for UIImage if not already present
extension UIImage {
    func resized(toWidth width: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

#Preview {
    AddDogView(
        dogProfileViewModel: DogProfileViewModel(),
        dogHealthViewModel: DogHealthViewModel()
    )
    .environmentObject(LocationManager())
    .environmentObject(AuthenticationService.mock)
}
