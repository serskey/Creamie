import SwiftUI
import MapKit

struct MyDogDetailView: View {
    let dog: Dog
    @ObservedObject var profileViewModel: DogProfileViewModel
    @StateObject private var healthViewModel: DogHealthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition
    @State private var showFullMap: Bool = false
    @State private var selectedTab = 0
    
    init(dog: Dog, profileViewModel: DogProfileViewModel) {
        self.dog = dog
        self.profileViewModel = profileViewModel
        _healthViewModel = StateObject(wrappedValue: DogHealthViewModel(dogId: dog.id))
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: dog.location,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with photo gallery
            ZStack(alignment: .top) {
                PhotoGalleryView(photoNames: dog.photos)
                    .frame(height: 300)
                
                // Custom back button overlay
//                HStack {
//                    Button(action: { dismiss() }) {
//                        Image(systemName: "xmarkxmark.circle.fill")
//                            .font(.title2)
//                            .foregroundColor(.white)
//                            .shadow(radius: 2)
//                    }
//                    .padding(.leading)
//                    Spacer()
//                }
//                .padding(.top, 60)
            }
            
            // Tab selection
            TabView(selection: $selectedTab) {
                // Basic Info Tab
                ScrollView {
                    basicInfoView
                }
                .tag(0)
                
                // Health & Care Tab
                ScrollView {
                    healthCareView
                }
                .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Custom tab bar
            HStack(spacing: 0) {
                tabButton(title: "Basic Info", systemImage: "pawprint.fill", tag: 0)
                tabButton(title: "Health & Care", systemImage: "heart.fill", tag: 1)
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .shadow(radius: 2)
        }
        .ignoresSafeArea(edges: .top)
        .background(Color(.systemBackground))
        .fullScreenCover(isPresented: $showFullMap) {
            FullScreenMapView(dog: dog)
        }
        .task {
            await healthViewModel.loadHealthData()
        }
    }
    
    private var basicInfoView: some View {
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
            if let interests = dog.interests, !interests.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Interests")
                    .font(.headline)
                
                HStack(spacing: 8) {
                        ForEach(interests, id: \.self) { interest in
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
            
//            // Location Section
//            VStack(alignment: .leading, spacing: 12) {
//                HStack {
//                    Text("Location")
//                        .font(.headline)
//                }
//                
//                Map(position: $cameraPosition) {
//                    Annotation(dog.name, coordinate: dog.location) {
//                        Image(systemName: "pawprint.circle.fill")
//                            .font(.title)
//                            .foregroundColor(.blue)
//                    }
//                }
//                .frame(height: 200)
//                .clipShape(RoundedRectangle(cornerRadius: 12))
//                .onTapGesture {
//                    showFullMap = true
//                }
//            }
            
            // Delete Button
            Button(action: {
                profileViewModel.confirmDeleteDog(dog: dog)
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Dog")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
    
    private var healthCareView: some View {
        VStack(alignment: .leading, spacing: 24) {
            if healthViewModel.isLoading {
                ProgressView("Loading health records...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // Vaccinations Section
                healthSection(title: "Vaccinations", systemImage: "syringe") {
                    if healthViewModel.vaccinations.isEmpty {
                        Text("No vaccination records")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(healthViewModel.vaccinations) { vaccination in
                            VStack(alignment: .leading) {
                                Text(vaccination.name)
                                    .font(.headline)
                                
                                HStack {
                                    Text("Date: \(formatDate(vaccination.date))")
                                    Spacer()
                                    Text("Expires: \(formatDate(vaccination.expirationDate))")
                                        .foregroundColor(isExpiringSoon(vaccination.expirationDate) ? .red : .primary)
                                }
                                .font(.subheadline)
                                
                                Text("Vet: \(vaccination.veterinarian)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    
                    addButton("Add Vaccination Record")
                }
                
                // Vet Appointments Section
                healthSection(title: "Vet Appointments", systemImage: "calendar") {
                    if healthViewModel.vetAppointments.isEmpty {
                        Text("No upcoming appointments")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(healthViewModel.upcomingAppointments()) { appointment in
                            VStack(alignment: .leading) {
                                Text(appointment.purpose)
                                    .font(.headline)
                                
                                Text("Date: \(formatDate(appointment.date))")
                                    .font(.subheadline)
                                
                                Text("\(appointment.veterinarianName) at \(appointment.clinicName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let notes = appointment.notes {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    
                    addButton("Schedule Appointment")
                }
                
                // Weight History Section
                healthSection(title: "Weight History", systemImage: "scalemass") {
                    if healthViewModel.weightHistory.isEmpty {
                        Text("No weight records")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        // Weight chart would go here
                        Text("Weight Chart")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        ForEach(healthViewModel.weightHistory.sorted(by: { $0.date > $1.date }).prefix(3)) { record in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(String(format: "%.1f", record.weight)) kg")
                                        .font(.headline)
                                    
                                    Text(formatDate(record.date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if let notes = record.notes {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    
                    addButton("Add Weight Record")
                }
                
                // Medications Section
                healthSection(title: "Medications", systemImage: "pills") {
                    if healthViewModel.medications.isEmpty {
                        Text("No medications")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(healthViewModel.currentMedications()) { medication in
                            VStack(alignment: .leading) {
                                Text(medication.name)
                                    .font(.headline)
                                
                                Text("\(medication.dosage), \(medication.frequency)")
                                    .font(.subheadline)
                                
                                HStack {
                                    Text("Started: \(formatDate(medication.startDate))")
                                    Spacer()
                                    if let endDate = medication.endDate {
                                        Text("Until: \(formatDate(endDate))")
                                    } else {
                                        Text("Ongoing")
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                                
                                if let notes = medication.notes {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    
                    addButton("Add Medication")
                }
                
                // Grooming Appointments Section
                healthSection(title: "Grooming", systemImage: "scissors") {
                    if healthViewModel.groomingAppointments.isEmpty {
                        Text("No grooming appointments")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(healthViewModel.upcomingGroomingAppointments()) { appointment in
                            VStack(alignment: .leading) {
                                Text(appointment.groomingService)
                                    .font(.headline)
                                
                                Text("Date: \(formatDate(appointment.date))")
                                    .font(.subheadline)
                                
                                Text("Location: \(appointment.location)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let notes = appointment.notes {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    
                    addButton("Schedule Grooming")
                }
            }
        }
        .padding()
    }
    
    private func healthSection<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.title3.bold())
            }
            
            content()
        }
        .padding(.bottom, 16)
    }
    
    private func addButton(_ title: String) -> some View {
        Button(action: {
            // Add action here
        }) {
            HStack {
                Image(systemName: "plus.circle")
                Text(title)
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            .padding(.vertical, 8)
        }
    }
    
    private func tabButton(title: String, systemImage: String, tag: Int) -> some View {
        Button(action: {
            withAnimation {
                selectedTab = tag
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(selectedTab == tag ? .blue : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
    
    // Helper functions
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func isExpiringSoon(_ date: Date) -> Bool {
        return date < Date().addingTimeInterval(30 * 24 * 3600) // 30 days
    }
} 
