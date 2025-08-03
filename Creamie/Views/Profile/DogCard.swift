//
//  DogCard.swift
//  Creamie
//
//  Created by Siqi Xu on 2025/7/30.
//

import SwiftUI

struct DogCard: View {
    // MARK: - Properties
    let dogId: UUID
    @ObservedObject var dogProfileViewModel: DogProfileViewModel
    @ObservedObject var dogHealthViewModel: DogHealthViewModel
    @State private var isOnline: Bool
    
    private var dog: Dog? {
        dogProfileViewModel.dogs.first(where: { $0.id == dogId })
    }
    
    // MARK: - Initializer
    init(dogId: UUID,
         dogProfileViewModel: DogProfileViewModel,
         dogHealthViewModel: DogHealthViewModel,
         isOnline: Bool) {
        self.dogId = dogId
        self.dogProfileViewModel = dogProfileViewModel
        self.dogHealthViewModel = dogHealthViewModel
        self._isOnline = State(initialValue: isOnline)
    }
    
    // MARK: - Body
    var body: some View {
        Group {
            if let dog = dog {
                dogContent(for: dog)
            } else {
                dogNotFoundView
            }
        }
    }
}

// MARK: - Main Content Views
extension DogCard {
    private func dogContent(for dog: Dog) -> some View {
        VStack(spacing: 16) {
            dogPhotosSection(dog: dog)
            dogInfoSection(dog: dog)
        }
        .padding(.vertical, 16)
    }
    
    private var dogNotFoundView: some View {
        Text("Dog not found")
            .foregroundColor(Color.pink)
            .padding()
    }
}

// MARK: - Photo Section
extension DogCard {
    private func dogPhotosSection(dog: Dog) -> some View {
        Group {
            if dog.photos.count > 1 {
                multiplePhotosView(photos: dog.photos)
            } else if let firstPhoto = dog.photos.first {
                singlePhotoView(photoName: firstPhoto)
            } else {
                noPhotosView
            }
        }
    }
    
    private func multiplePhotosView(photos: [String]) -> some View {
        SimplePhotoCarousel(photos: photos)
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    private func singlePhotoView(photoName: String) -> some View {
        DogPhotoView(photoName: photoName)
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    private var noPhotosView: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.gray.opacity(0.3))
            .frame(height: 280)
            .overlay(noPhotosPlaceholder)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    private var noPhotosPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.7))
            Text("No photos yet")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
        }
    }
}

// MARK: - Info Section
extension DogCard {
    private func dogInfoSection(dog: Dog) -> some View {
        VStack(spacing: 16) {
            basicInfoCard(dog: dog)
            interestsCard(dog: dog)
            aboutMeCard(dog: dog)
            healthcareCard(dog: dog)
        }
        .padding(.horizontal, 16)
    }
    
    private func basicInfoCard(dog: Dog) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(dog.name)
                    .font(.largeTitle.bold())
                    .foregroundColor(.primary)
                
                onlineStatusToggle(dog: dog)
            }
            
            Text("\(dog.age) years old")
                .font(.title2.bold())
                .foregroundColor(.primary)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    private func onlineStatusToggle(dog: Dog) -> some View {
        HStack {
            Button(action: {
                toggleOnlineStatus(for: dog)
            }) {
                Image(systemName: isOnline ? "eye.fill" : "eye.slash.fill")
                    .foregroundColor(isOnline ? .pink : .purple)
                    .frame(width: 24)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(isOnline ? "Online" : "Offline")
                .font(.caption)
                .foregroundColor(isOnline ? .pink : .purple)
        }
    }
    
    @ViewBuilder
    private func interestsCard(dog: Dog) -> some View {
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
                            .foregroundColor(.primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 24)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
    
    @ViewBuilder
    private func aboutMeCard(dog: Dog) -> some View {
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
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
    
    private func healthcareCard(dog: Dog) -> some View {
        DogHealthcareView(dogId: dog.id, dogHealthViewModel: dogHealthViewModel)
            .onAppear {
                Task {
                    await dogHealthViewModel.loadHealthData(for: dog.id)
                }
            }
    }
}

// MARK: - Helper Methods
extension DogCard {
    private func toggleOnlineStatus(for dog: Dog) {
        isOnline.toggle()
        Task {
            await dogProfileViewModel.updateDogOnlineStatus(isOnline: isOnline, dogId: dog.id)
        }
    }
}

// MARK: - Supporting Types
struct HealthInfoItem {
    let icon: String
    let title: String
    let value: String
}
