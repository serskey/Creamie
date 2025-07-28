import SwiftUI
import MapKit

struct MapDogProfileView: View {
    let selectedDog: Dog
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @Binding var selectedTab: Int
    @Binding var selectedChatId: UUID?
    @EnvironmentObject var authService: AuthenticationService
    
    var body: some View {
        VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 6)
                    .padding(.top, 12)
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Header with photo - clean and embedded
                        PhotoGalleryView(photoNames: selectedDog.photos)
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            // Basic Info
                            VStack(alignment: .leading, spacing: 8) {
                                Text(selectedDog.name)
                                    .font(.title2.bold())
                                
                                Text("\(selectedDog.breed.rawValue) · \(selectedDog.age) years old")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Interests Section
                            if let interests = selectedDog.interests, !interests.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Interests")
                                        .font(.headline)
                                    
                                    HStack(spacing: 8) {
                                        ForEach(interests, id: \.self) { interest in
                                            Text(interest)
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.purple.opacity(0.2))
                                                .foregroundColor(Color.primary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            
                            // About Me Section
                            if let aboutMe = selectedDog.aboutMe, !aboutMe.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("About Me")
                                        .font(.headline)
                                    
                                    Text(aboutMe)
                                        .font(.subheadline)
                                        .lineLimit(3)
                                }
                            }
                            
                            // Action Buttons - Message Owner
                            if authService.currentUser!.id != selectedDog.ownerId {
                                VStack(spacing: 12) {
                                    Button(action: {
                                        Task {
                                            let chat = await chatViewModel.findOrCreateChat(for: selectedDog)
                                            selectedTab = 2
                                            dismiss()
                                            selectedChatId = chat.id
                                        }
                                    }) {
                                        
                                        HStack {
                                            Image(systemName: "message.fill")
                                                .foregroundColor(Color.pink)
                                            Text("Message Owner")
                                                .foregroundColor(Color.pink)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .foregroundStyle(Color.primary)
                                        .background(Color.purple.opacity(0.2))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    
                                    // Action Buttons - Navigate to dog location
                                    Button(action: {
                                        let coordinates = CLLocationCoordinate2D(latitude: selectedDog.latitude, longitude: selectedDog.longitude)
                                        let url = URL(string: "maps://?saddr=&daddr=\(coordinates.latitude),\(coordinates.longitude)")
                                        if let url = url, UIApplication.shared.canOpenURL(url) {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        
                                        HStack {
                                            Image(systemName: "location.fill")
                                                .foregroundColor(Color.pink)
                                            Text("Find Me")
                                                .foregroundColor(Color.pink)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .foregroundStyle(Color.primary)
                                        .background(Color.purple.opacity(0.2))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                            
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
