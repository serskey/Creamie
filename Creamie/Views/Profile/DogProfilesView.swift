import SwiftUI
import MapKit
import UIKit

struct DogProfilesView: View {
    @StateObject private var viewModel = DogProfileViewModel()
    @State private var selectedDog: Dog?
    @State private var isPhotoZoomed: Bool = false
    @State private var showFullMap: Bool = false
    @State private var currentDogIndex: Int = 0
    
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
            // TODO: change to real login user id
            await viewModel.fetchUserDogs(userId: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!)
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
        .alert("Delete Dog?", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
//            .buttonStyle(.glassProminent)
//            .tint(.pink.opacity(0.8))
            // TODO: Button color change not working
             
            Button("Delete", role: .destructive) {
                if let dogToDelete = viewModel.dogToDelete {
                    viewModel.deleteDog(dog: dogToDelete)
                    if selectedDog?.id == dogToDelete.id {
                        selectedDog = nil
                    }
                }
            }
//            .buttonStyle(.glassProminent)
//            .tint(.purple.opacity(0.8))
            // TODO: Button color change not working
            
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
                    await viewModel.fetchUserDogs(userId: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!)
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
                                ExpandedLiquidGlassDogCard(dog: dog)
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
    
    private struct ExpandedLiquidGlassDogCard: View {
        let dog: Dog
        
        var body: some View {
            
            VStack(spacing: 16) {
                // dog photos
                if dog.photos.count > 1 {
                    // Simple Native Carousel
                    SimplePhotoCarousel(photos: dog.photos)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else if let firstPhoto = dog.photos.first {
                    // Show the single photo normally
                    DogPhotoView(photoName: firstPhoto)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    // fallback
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 280)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.7))
                                Text("No photos yet")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.7))
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                

                // dog basic info
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        Text(dog.name)
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)
                        
                        Text("\(dog.breed.rawValue) · \(dog.age) years old")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 24)
//                    .background(Color.clear)
//                    .glassEffect(.clear.tint(Color.clear).interactive())
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    
                    // dog interests
                    if let interests = dog.interests, !interests.isEmpty {
                        VStack(spacing: 12) {
                            Text("Interests")
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(interests, id: \.self) { interest in
                                    Text(interest)
                                        .font(.body.bold())
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
//                                        .background(Color.clear)
                                        .foregroundColor(.primary)
//                                        .glassEffect(.clear.tint(Color.clear).interactive())
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 24)
//                        .background(Color.clear)
//                        .glassEffect(.clear.tint(Color.clear).interactive())
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    
                    // About Me
                    if let aboutMe = dog.aboutMe, !aboutMe.isEmpty {
                        VStack(spacing: 12) {
                            Text("About Me")
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                            
                            Text(aboutMe)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 24)
//                        .background(Color.clear)
//                        .glassEffect(.clear.tint(Color.clear).interactive())
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    
                    // Health Conditions
                    if let healthInfo = getHealthInfo(for: dog) {
                        VStack(spacing: 12) {
                            Text("Health & Care")
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 8) {
                                ForEach(healthInfo, id: \.title) { info in
                                    HStack {
                                        Image(systemName: info.icon)
                                            .foregroundColor(.green)
                                            .frame(width: 20)
                                        Text(info.title)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(info.value)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 24)
//                        .background(Color.clear)
//                        .glassEffect(.clear.tint(Color.clear).interactive())
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        
        // Fetch Health Info
        private func getHealthInfo(for dog: Dog) -> [HealthInfoItem]? {
            return [
                HealthInfoItem(icon: "heart.fill", title: "Weight", value: "\(Int.random(in: 15...35)) kg"),
                HealthInfoItem(icon: "calendar", title: "Last Checkup", value: "2 weeks ago"),
                HealthInfoItem(icon: "syringe", title: "Vaccinations", value: "Up to date"),
                HealthInfoItem(icon: "scissors", title: "Last Grooming", value: "1 month ago")
            ]
        }
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
    
    private struct HealthInfoItem {
        let icon: String
        let title: String
        let value: String
    }
    
}

