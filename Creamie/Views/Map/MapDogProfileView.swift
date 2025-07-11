import SwiftUI
import MapKit

struct MapDogProfileView: View {
    let dog: Dog
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @Binding var selectedTab: Int
    @Binding var selectedChatId: UUID?
    
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
                        PhotoGalleryView(photoNames: dog.photos)
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            // Basic Info
                            VStack(alignment: .leading, spacing: 8) {
                                Text(dog.name)
                                    .font(.title2.bold())
                                
                                Text("\(dog.breed.rawValue) · \(dog.age) years old")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Interests Section
                            if let interests = dog.interests, !interests.isEmpty {
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
                            if let aboutMe = dog.aboutMe, !aboutMe.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("About Me")
                                        .font(.headline)
                                    
                                    Text(aboutMe)
                                        .font(.subheadline)
                                        .lineLimit(3)
                                }
                            }
                            
                            
                            // Action Buttons
                            VStack(spacing: 12) {
                                Button(action: {
                                    // Find or create chat with this dog's owner
                                    let chat = chatViewModel.findOrCreateChat(for: dog)
                                    
                                    // Set the selected chat ID
                                    selectedChatId = chat.id
                                    
                                    // Dismiss the sheet
                                    dismiss()
                                    
                                    // Navigate to Messages tab
                                    selectedTab = 2
                                }) {
                                    
                                    HStack {
                                        Image(systemName: "message.fill")
                                        Text("Message Owner")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .foregroundStyle(Color.primary)
                                    .background(Color.purple.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                
//                                Button(action: {
//                                    // Add to favorites or schedule a playdate
//                                }) {
//                                    HStack {
//                                        Image(systemName: "calendar.badge.plus")
//                                        Text("Schedule Playdate")
//                                    }
//                                    .frame(maxWidth: .infinity)
//                                    .padding()
//                                    .background(Color.blue.opacity(0.1))
//                                    .foregroundColor(.blue)
//                                    .clipShape(RoundedRectangle(cornerRadius: 12))
//                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20) // Add bottom padding for better spacing
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure full frame usage
    }
}
