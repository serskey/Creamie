import SwiftUI

struct DogProfilesView: View {
    // MARK: - View Models & Services
    @StateObject private var dogProfileViewModel = DogProfileViewModel()
    @StateObject private var dogHealthViewModel = DogHealthViewModel()
    @EnvironmentObject var authService: AuthenticationService
    private let locationService = DogLocationService.shared
    
    // MARK: - State Properties
    @State private var selectedDog: Dog?
    @State private var currentDogIndex: Int = 0
    @State private var isPhotoZoomed: Bool = false
    @State private var showFullMap: Bool = false
    @State private var showDeletionAlert = false
    @State private var alertDeletionErrorMessage = ""
    
    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundView
            mainContent
        }
        .task {
            await dogProfileViewModel.fetchUserDogs(userId: authService.currentUser!.id)
        }
        .onChange(of: dogProfileViewModel.dogs) { _, newDogs in
            resetIndexIfNeeded(newDogs: newDogs)
        }
        .sheet(isPresented: $dogProfileViewModel.showingAddDog) {
            AddDogView(dogProfileViewModel: dogProfileViewModel,
                       dogHealthViewModel: dogHealthViewModel)
        }
        .sheet(isPresented: $dogProfileViewModel.showingEditDog) {
            if let dogToEdit = selectedDog {
                EditDogView(dogProfileViewModel: dogProfileViewModel,
                            dogHealthViewModel: dogHealthViewModel,
                            dogToEdit: dogToEdit)
            }
        }
        .alert("Delete Dog?", isPresented: $dogProfileViewModel.showingDeleteConfirmation) {
            deletionAlertButtons
        } message: {
            deletionAlertMessage
        }
        .alert("Error", isPresented: .constant(dogProfileViewModel.addDogError != nil)) {
            Button("OK") { dogProfileViewModel.addDogError = nil }
        } message: {
            Text(dogProfileViewModel.addDogError ?? "")
        }
        .alert("Success! 🎉", isPresented: .constant(dogProfileViewModel.addDogSuccess != nil)) {
            Button("OK") { dogProfileViewModel.addDogSuccess = nil }
        } message: {
            Text(dogProfileViewModel.addDogSuccess ?? "")
        }
        .alert("Deletion Failed", isPresented: $showDeletionAlert) {
            retryDeletionAlertButtons
        } message: {
            Text(alertDeletionErrorMessage)
        }
    }
}

// MARK: - Main Content Views
extension DogProfilesView {
    private var backgroundView: some View {
        Group {
            if !dogProfileViewModel.dogs.isEmpty && currentDogIndex < dogProfileViewModel.dogs.count {
                let breed = dogProfileViewModel.dogs[currentDogIndex].breed
                if UIImage(named: breed.iconName) != nil {
                    Image(breed.iconName)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                        .opacity(0.15)
                        .animation(.easeInOut(duration: 0.5), value: currentDogIndex)
                }
            }
        }
    }
    
    private var mainContent: some View {
        Group {
            if dogProfileViewModel.isLoading {
                loadingView
            } else if dogProfileViewModel.error != nil {
                errorView
            } else if dogProfileViewModel.dogs.isEmpty {
                emptyStateView
            } else {
                dogsCarouselView
            }
        }
    }
    
    private var loadingView: some View {
        ZStack {
            Image("cockapoo")
                .resizable()
                .scaledToFit()
                .opacity(0.2)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView("Loading your dogs...")
            }
            .padding(40)
            .glassEffect(.clear.tint(Color.clear).interactive(false))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error loading dogs")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Button("Try Again") {
                Task {
                    await dogProfileViewModel.fetchUserDogs(userId: authService.currentUser!.id)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.2))
            .foregroundColor(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(40)
        .background(Color.clear)
        .glassEffect(.clear.tint(Color.clear).interactive())
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 30) {
            Image(systemName: "dog.circle")
                .font(.system(size: 80))
                .foregroundColor(Color.purple)
            
            VStack(spacing: 12) {
                Text("No Dogs Yet!")
                    .font(.title.bold())
                    .foregroundColor(.primary)
                
                Text("Add your first furry friend to get started with this dog world")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button(action: {
                dogProfileViewModel.showingAddDog = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Your First Dog")
                }
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .clipShape(RoundedRectangle(cornerRadius: 25))
            }
            .buttonStyle(.glassProminent)
            .tint(.purple.opacity(0.8))
        }
        .padding(40)
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }
}

// MARK: - Dogs Carousel
extension DogProfilesView {
    private var dogsCarouselView: some View {
        ZStack {
            VStack(spacing: 0) {
                dogPickerView
                    .padding(.top, 8)
                Spacer()
            }
            
            TabView(selection: $currentDogIndex) {
                ForEach(Array(dogProfileViewModel.dogs.enumerated()), id: \.element.id) { index, dog in
                    dogTabContent(for: dog)
                        .tag(index)
                }
            }
            .padding(.top, 50)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
    
    private func dogTabContent(for dog: Dog) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    DogCard(
                        dogId: dog.id,
                        dogProfileViewModel: dogProfileViewModel,
                        dogHealthViewModel: dogHealthViewModel,
                        isOnline: dog.isOnline
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 15)
                    
                    actionsMenu
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                }
            }
        }
        .onTapGesture {
            selectedDog = dog
        }
    }
    
    private var dogPickerView: some View {
        Picker("Select Dog", selection: $currentDogIndex) {
            ForEach(Array(dogProfileViewModel.dogs.enumerated()), id: \.element.id) { index, dog in
                HStack {
                    Text(dog.name)
                        .font(.headline)
                }
                .tag(index)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .background(.clear)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
    
    private var actionsMenu: some View {
        Menu {
            Button {
                dogProfileViewModel.showingAddDog = true
            } label: {
                Label("Add Dog", systemImage: "plus.square")
            }
            
            if !dogProfileViewModel.dogs.isEmpty {
                Button {
                    if currentDogIndex < dogProfileViewModel.dogs.count {
                        selectedDog = dogProfileViewModel.dogs[currentDogIndex]
                        dogProfileViewModel.showingEditDog = true
                    }
                } label: {
                    Label("Edit Dog", systemImage: "square.and.pencil")
                }
                
                Button {
                    if !dogProfileViewModel.dogs.isEmpty && currentDogIndex < dogProfileViewModel.dogs.count {
                        dogProfileViewModel.confirmDeleteDog(dog: dogProfileViewModel.dogs[currentDogIndex])
                    }
                } label: {
                    Label("Delete Dog", systemImage: "trash")
                }
                .disabled(dogProfileViewModel.dogs.isEmpty)
            }
        } label: {
            Image(systemName: "list.bullet.below.rectangle")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primary)
                .padding(14)
                .clipShape(Circle())
        }
    }
}

// MARK: - Alert Components
extension DogProfilesView {
    @ViewBuilder
    private var deletionAlertButtons: some View {
        Button("Cancel", role: .cancel) {}
        Button("Delete", role: .destructive) {
            handleDogDeletion()
        }
    }
    
    private var deletionAlertMessage: some View {
        Group {
            if let dog = dogProfileViewModel.dogToDelete {
                Text("Are you sure you want to delete \(dog.name)? This action cannot be undone.")
            }
        }
    }
    
    @ViewBuilder
    private var retryDeletionAlertButtons: some View {
        Button("OK") { }
        Button("Retry") {
            handleDogDeletion()
        }
    }
}

// MARK: - Helper Methods
extension DogProfilesView {
    private func resetIndexIfNeeded(newDogs: [Dog]) {
        if !newDogs.isEmpty && currentDogIndex >= newDogs.count {
            currentDogIndex = 0
        }
    }
    
    private func handleDogDeletion() {
        guard let dogToDelete = dogProfileViewModel.dogToDelete else { return }
        
        Task {
            do {
                try await dogProfileViewModel.deleteDog(dog: dogToDelete)
                if selectedDog?.id == dogToDelete.id {
                    selectedDog = nil
                }
            } catch {
                alertDeletionErrorMessage = "Unable to delete the dog. Please check your internet connection and try again."
                showDeletionAlert = true
            }
        }
    }
}
