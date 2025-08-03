import SwiftUI
import MapKit

struct MapDogProfileView: View {
    let selectedDog: Dog
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @Binding var selectedTab: Int
    @Binding var selectedChatId: UUID?
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var dogProfileViewModel: DogProfileViewModel
    
    @State private var showDogSelection = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 6)
                .padding(.top, 12)
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header with photo
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
                        
                        // Action Buttons - Message as one of your dogs
                        if authService.currentUser!.id != selectedDog.ownerId {
                            VStack(spacing: 12) {
                                Button(action: messageAction) {
                                    actionButton(icon: "message.fill", text: "Message \(selectedDog.name)")
                                }
                                
                                Button(action: navigateAction) {
                                    actionButton(icon: "location.fill", text: "Find Me")
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
        .sheet(isPresented: $showDogSelection) {
            DogSelectionView(
                userDogs: dogProfileViewModel.dogs,
                targetDog: selectedDog,
                selectedTab: $selectedTab,
                selectedChatId: $selectedChatId
            )
            .environmentObject(chatViewModel)
            .presentationDetents([.medium])
        }
    }
    
    private func actionButton(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color.pink)
            Text(text)
                .foregroundColor(Color.pink)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .foregroundStyle(Color.primary)
        .background(Color.purple.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func messageAction() {
        Task {
            await dogProfileViewModel.fetchUserDogs(userId: authService.currentUser!.id)
            
            if dogProfileViewModel.dogs.isEmpty {
                // User has no dogs - they need to add one first
                showDogSelection = true
            } else if dogProfileViewModel.dogs.count == 1 {
                let chat = await chatViewModel.findOrCreateChatBetweenDogs(
                    fromDog: dogProfileViewModel.dogs[0],
                    toDog: selectedDog
                )
                selectedTab = 2
                dismiss()
                selectedChatId = chat.id
            } else {
                showDogSelection = true
            }
        }
    }
    
    private func navigateAction() {
        let coordinates = CLLocationCoordinate2D(latitude: selectedDog.latitude, longitude: selectedDog.longitude)
        let url = URL(string: "maps://?saddr=&daddr=\(coordinates.latitude),\(coordinates.longitude)")
        if let url = url, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
//    private func fetchUserDogs() async {
//        do {
//            let response = try await supabase
//                .from("dogs")
//                .select("*")
//                .eq("owner_id", value: authService.currentUser!.id)
//                .execute()
//            
//            let decoder = JSONDecoder()
//            let decoded = try decoder.decode([Dog].self, from: response.data)
//            userDogs = decoded
//        } catch {
//            print("❌ Failed to fetch user dogs: \(error)")
//        }
//    }
}

struct DogSelectionView: View {
    let userDogs: [Dog]
    let targetDog: Dog
    @Binding var selectedTab: Int
    @Binding var selectedChatId: UUID?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var chatViewModel: ChatViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            if userDogs.isEmpty {
                // User has no dogs
                VStack(spacing: 16) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.purple.opacity(0.6))
                    
                    Text("Add Your Dog First")
                        .font(.headline)
                    
                    Text("You need to add at least one dog to your profile before you can start a conversation.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        selectedTab = 3 // Assuming profile tab is index 3
                        dismiss()
                    }) {
                        Text("Go to Profile")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                }
            } else {
                // User has dogs - show selection
                Text("Message as which dog?")
                    .font(.headline)
                    .padding(.top)
                
                ForEach(userDogs) { dog in
                    Button(action: {
                        Task {
                            let chat = await chatViewModel.findOrCreateChatBetweenDogs(
                                fromDog: dog,
                                toDog: targetDog
                            )
                            selectedTab = 2
                            dismiss()
                            selectedChatId = chat.id
                        }
                    }) {
                        HStack {
                            // TODO: Add dog avatar here
                            VStack(alignment: .leading) {
                                Text(dog.name)
                                    .font(.headline)
                                Text(dog.breed.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .foregroundColor(.primary)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}
