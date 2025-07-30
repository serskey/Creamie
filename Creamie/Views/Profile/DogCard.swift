//
//  DogCard.swift
//  Creamie
//
//  Created by Siqi Xu on 2025/7/30.
//

import SwiftUI

struct DogCard: View {
    let dogId: UUID
    @ObservedObject var viewModel: DogProfileViewModel
    @State private var isOnline: Bool
    
    private var dog: Dog? {
        viewModel.dogs.first(where: { $0.id == dogId })
    }
    
    init(dogId: UUID, viewModel: DogProfileViewModel, isOnline: Bool) {
        self.dogId = dogId
        self.viewModel = viewModel
        self._isOnline = State(initialValue: isOnline)
    }
    
    var body: some View {
        
        guard let dog = dog else {
            return AnyView(
                Text("Dog not found")
                    .foregroundColor(Color.pink)
                    .padding()
            )
        }
        
        return AnyView(
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
                        HStack {
                            Text(dog.name)
                                .font(.largeTitle.bold())
                                .foregroundColor(.primary)
                            
                            HStack {
                                Button(action: {
                                    isOnline.toggle()
                                    Task {
                                        await updateOnlineStatus(isOnline: isOnline, dogId: dog.id)
                                    }
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
                        
                        Text("\(dog.age) years old")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 24)
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
                                        .foregroundColor(.primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 24)
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
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        )
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
    
    private func updateOnlineStatus(isOnline: Bool, dogId: UUID) async {
        await viewModel.updateDogOnlineStatus(isOnline: isOnline,
                                           dogId: dogId)
    }
}

struct HealthInfoItem {
    let icon: String
    let title: String
    let value: String
}
