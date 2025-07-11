import SwiftUI
import MapKit
import UIKit

struct DogProfileView: View {
    @StateObject private var viewModel = DogProfileViewModel()
    @State private var selectedDog: Dog?
    @State private var isPhotoZoomed: Bool = false
    @State private var showFullMap: Bool = false
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading your dogs...")
                } else if viewModel.error != nil {
                    VStack {
                        Text("Error loading dogs")
                            .foregroundColor(.red)
                        Button("Try Again") {
                            Task {
                                await viewModel.fetchDogs()
                            }
                        }
                    }
                } else if viewModel.dogs.isEmpty {
                    EmptyDogListView(viewModel: viewModel)
                } else {
                    List {
                        ForEach(viewModel.dogs) { dog in
                            DogCard(dog: dog)
                                .onTapGesture {
                                    selectedDog = dog
                                }
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: viewModel.deleteDog)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("My Dogs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        viewModel.showingAddDog = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .task {
            await viewModel.fetchDogs()
        }
        .sheet(item: $selectedDog) { dog in
            MyDogDetailView(dog: dog, profileViewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingAddDog) {
            AddDogView(viewModel: viewModel)
        }
        .alert("Delete Dog?", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let dogToDelete = viewModel.dogToDelete {
                    viewModel.deleteDog(dog: dogToDelete)
                    if selectedDog?.id == dogToDelete.id {
                        selectedDog = nil
                    }
                }
            }
        } message: {
            if let dog = viewModel.dogToDelete {
                Text("Are you sure you want to delete \(dog.name)? This action cannot be undone.")
            }
        }
    }
}

struct EmptyDogListView: View {
    @ObservedObject var viewModel: DogProfileViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "dog.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Dogs Yet!")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("Add your first furry friend to get started")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                viewModel.showingAddDog = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Your First Dog")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Button("Refresh") {
                Task {
                    await viewModel.fetchDogs()
                }
            }
            .font(.subheadline)
            .foregroundColor(.blue)
        }
        .padding()
    }
}

// every single dog card on "My Dogs" tab
struct DogCard: View {
    let dog: Dog
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                // Display the first photo
                if !dog.photos.isEmpty {
                    DogPhotoView(photoName: dog.photos[0])
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // Fallback if no photos
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(dog.name)
                    .font(.title2.bold())
                
                Text("\(dog.breed.rawValue) · \(dog.age) years old")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2)
    }
}




