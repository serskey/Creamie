/**
    Not used for now
 */

import SwiftUI
import UIKit

struct DogPreviewCard: View {
    let dog: Dog
//    let onGetDirections: () -> Void
//    let onClose: () -> Void
    @StateObject private var viewModel = DogProfileViewModel()
    @State private var cardOffset: CGFloat = 1000
    @State private var isPhotoZoomed: Bool = false
    @State private var showProfile: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // selected dog first photo
            HStack {
                if !dog.photos.isEmpty {
                    DogPhotoView(photoName: dog.photos[0])
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 4)
                        .onTapGesture {
                            isPhotoZoomed = true
                        }
                } else {
//                    // Fallback if no photos
//                    Rectangle()
//                        .fill(Color.gray.opacity(0.3))
//                        .frame(width: 120, height: 120)
//                        .clipShape(RoundedRectangle(cornerRadius: 12))
//                        .shadow(radius: 4)
//                        .overlay(
//                            Image(systemName: "photo")
//                                .font(.title)
//                                .foregroundColor(.gray)
//                        )
                    
                    DogPhotoView(photoName: "dog_sample")
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 4)
                        .onTapGesture {
                            isPhotoZoomed = true
                        }
                }
                
                // dog basic info
                VStack(alignment: .leading, spacing: 8) {
                    Text(dog.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(dog.breed.rawValue), \(dog.age) years")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: { showProfile = true }) {
                        Label("View Profile", systemImage: "pawprint.circle")
                            .font(.footnote.bold())
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
                
                // dog location
                HStack(spacing: 12) {
                    Button(action: {
                        let coordinates = dog.location
                        let url = URL(string: "maps://?saddr=&daddr=\(coordinates.latitude),\(coordinates.longitude)")
                        if let url = url, UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                    }
                    
//                    Button(action: onClose) {
//                        Image(systemName: "xmark.circle.fill")
//                            .font(.title2)
//                            .foregroundColor(.gray)
//                    }
                }
            }
            
            // dog interests
            Text("Interests")
                .font(.headline)
                .padding(.top, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let interests = dog.interests, !interests.isEmpty{
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
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
        .offset(y: cardOffset)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                cardOffset = 0
            }
        }
        .fullScreenCover(isPresented: $isPhotoZoomed) {
            if !dog.photos.isEmpty {
                ZoomablePhotoView(imageName: dog.photos[0])
            }
        }
//        .sheet(isPresented: $showProfile) {
//            MapDogProfileView(dog: dog, selectedTab: 0)
//        }
    }
} 


