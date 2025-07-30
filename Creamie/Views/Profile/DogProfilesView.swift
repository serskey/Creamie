import SwiftUI

struct DogProfilesView: View {
    @StateObject private var viewModel = DogProfileViewModel()
    @State private var selectedDog: Dog?
    @State private var isPhotoZoomed: Bool = false
    @State private var showFullMap: Bool = false
    @State private var currentDogIndex: Int = 0
    @EnvironmentObject var authService: AuthenticationService
    @State private var showDeletionAlert = false
    @State private var alertDeletionErrorMessage = ""
    
    private let locationService = DogLocationService.shared
    
    // TODO: dogs are listed in random sequence
    var body: some View {
        ZStack {
            // background cartoon icon based on breeds
            if !viewModel.dogs.isEmpty && currentDogIndex < viewModel.dogs.count {
                backgroundView(for: viewModel.dogs[currentDogIndex].breed)
                    .animation(.easeInOut(duration: 0.5), value: currentDogIndex)
            }
            
            // main content
            if viewModel.isLoading {
                loadingView
            } else if viewModel.error != nil {
                errorView
            } else if viewModel.dogs.isEmpty {
                emptyStateView
            } else {
                dogsCarouselView
            }
        }
        .task {
            await viewModel.fetchUserDogs(userId: authService.currentUser!.id)
        }
        .onChange(of: viewModel.dogs) { _, newDogs in
            // Reset to first dog when dogs data changes
            if !newDogs.isEmpty && currentDogIndex >= newDogs.count {
                currentDogIndex = 0
            }
        }
        .sheet(isPresented: $viewModel.showingAddDog) {
            AddDogView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingEditDog) {
            if let dogToEdit = selectedDog {
                EditDogView(viewModel: viewModel, dogToEdit: dogToEdit)
            }
        }
        .alert("Delete Dog?", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
//            .buttonStyle(.glassProminent)
//            .tint(.pink.opacity(0.8))
            // TODO: Button color change not working
             
            Button("Delete", role: .destructive) {
                if let dogToDelete = viewModel.dogToDelete {
                    Task {
                        do {
                            try await viewModel.deleteDog(dog: dogToDelete)
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
            
        } message: {
            if let dog = viewModel.dogToDelete {
                Text("Are you sure you want to delete \(dog.name)? This action cannot be undone.")
            }
        }
        .alert("Error", isPresented: .constant(viewModel.addDogError != nil)) {
            Button("OK") {
                viewModel.addDogError = nil
            }
        } message: {
            Text(viewModel.addDogError ?? "")
        }
        .alert("Success! 🎉", isPresented: .constant(viewModel.addDogSuccess != nil)) {
            // TODO: After success, stay on the new dog page, right now it's on first dog page
            Button("OK") {
                viewModel.addDogSuccess = nil
            }
        } message: {
            Text(viewModel.addDogSuccess ?? "")
        }
        .alert("Deletion Failed", isPresented: $showDeletionAlert) {
            Button("OK") { }
            Button("Retry") {
                if let dogToDelete = viewModel.dogToDelete {
                    Task {
                        do {
                            try await viewModel.deleteDog(dog: dogToDelete)
                            if selectedDog?.id == dogToDelete.id {
                                selectedDog = nil
                            }
                        } catch {
                            alertDeletionErrorMessage = "Unable to delete the dog. Please try again later."
                            showDeletionAlert = true
                        }
                    }
                }
            }
        } message: {
            Text(alertDeletionErrorMessage)
        }
    }
    
    private func backgroundView(for breed: DogBreed) -> some View {
        ZStack {
            if let _ = UIImage(named: breed.iconName) {
                Image(breed.iconName)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
                    .opacity(0.15)
            } else {
                Color.clear
                    .ignoresSafeArea()
            }
        }
    }
    
    private var loadingView: some View {
        ZStack{
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
                    await viewModel.fetchUserDogs(userId: authService.currentUser!.id)
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
                viewModel.showingAddDog = true
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
    
    private var dogsCarouselView: some View {
        ZStack {
            // component 1: dog picker
            VStack(spacing: 0) {
                dogPickerView
                    .padding(.top, 8)
                Spacer()
            }
            
            // component 2: main profile
            TabView(selection: $currentDogIndex) {
                ForEach(Array(viewModel.dogs.enumerated()), id: \.element.id) { index, dog in
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                // dog basic info
                                DogCard(
                                    dogId: dog.id,
                                    viewModel: viewModel,
                                    isOnline: dog.isOnline
                                )
                                .padding(.horizontal, 16)
                                .padding(.bottom, 15)
                                
                                
                                // action menu
                                actionsMenu
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 100)
                            }
                        }
                    }
                    .onTapGesture {
                        selectedDog = dog
                    }
                    .tag(index)
                }
            }
            .padding(.top, 50)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
        }
        
    }
    
    private var dogPickerView: some View {
        Picker("Select Dog", selection: $currentDogIndex) {
            ForEach(Array(viewModel.dogs.enumerated()), id: \.element.id) { index, dog in
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
            
            // add dog
            Button {
                viewModel.showingAddDog = true
            } label: {
                Label("Add Dog", systemImage: "plus.square")
            }
            
            if !viewModel.dogs.isEmpty {
                // edit current dog
                Button {
                    if currentDogIndex < viewModel.dogs.count {
                        selectedDog = viewModel.dogs[currentDogIndex]
                        viewModel.showingEditDog = true
                    }
                } label: {
                    Label("Edit Dog", systemImage: "square.and.pencil")
                }
                
                // delete current dog
                Button {
                    if !viewModel.dogs.isEmpty && currentDogIndex < viewModel.dogs.count {
                        viewModel.confirmDeleteDog(dog: viewModel.dogs[currentDogIndex])
                    }
                } label: {
                    Label("Delete Dog", systemImage: "trash")
                }
                .disabled(viewModel.dogs.isEmpty)
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
