import Foundation
import SwiftUI
import CoreLocation
import UIKit

@MainActor
class DogProfileViewModel: ObservableObject {
    @Published var dogs: [Dog] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showingAddDog = false
    @Published var showingDeleteConfirmation = false
    @Published var dogToDelete: Dog?
    @Published var addDogError: String?
    @Published var addDogSuccess: String?
    
    private let dogProfileService = DogProfileService.shared
    
    // Photo storage
    private var photoCounter = 0
    
    private let minPhotos = 1
    
    func fetchUserDogs(userId: UUID) async {
        let getUserDogsRequest = GetUserDogsRequest(userId: userId)
        
        do {
            let response = try await dogProfileService.fetchUserDogs(getUserDogsRequest: getUserDogsRequest)
            self.dogs = response.dogs
            
            // Debug: Print photo URLs to verify backend data
            for dog in response.dogs {
                print("📸 Dog \(dog.name) photos:")
                for (index, photo) in dog.photos.enumerated() {
                    print("  Photo \(index + 1): \(photo)")
                }
            }
            
            print("🐾 Fetched \(response.totalCount) dogs from user \(userId)")
        } catch {
            // TODO: Add error detail from backend
            print("❌ Failed to fetch user's dogs: \(error)")
            self.dogs = []
        }
    }
    
    func addDog(
        name: String,
        breed: DogBreed,
        age: Int,
        interests: [String] = [],
        location: Location,
        photos: [UIImage],
        aboutMe: String?,
        ownerName: String?,
        ownerId: UUID,
        isOnline: Bool
    ) {
        // Will upload photos after dog creation succeeds
        var photoNames: [String] = []
        
        // Save dog to backend database first
        Task {
            var response: AddDogResponse?
            do {
                let addDogRequest = AddDogRequest(
                    name: name,
                    breed: breed.rawValue,
                    age: age,
                    interests: interests,
                    latitude: location.latitude,
                    longitude: location.longitude,
                    photos: photoNames,
                    aboutMe: aboutMe,
                    ownerName: ownerName,
                    ownerId: ownerId,
                    isOnline: isOnline
                )
                
                response = try await DogProfileService.shared.createDog(addDogRequest: addDogRequest)
                
                // Check if backend response indicates success
                if let response = response, response.status.lowercased() == "success", let dogId = response.dogId {
                    print("🐾 Successfully saved dog to backend: \(dogId)")
                    
                    // Upload ALL photos - this must succeed for minimum photos requirement
                    photoNames = await uploadPhotos(photos, for: dogId)
                    
                    // Check if we have the minimum required photos (1 minimum from UI validation)
                    if photoNames.count >= minPhotos {
                        // SUCCESS: Both dog creation and photo upload succeeded
                        let newDog = Dog(
                            id: dogId,
                            name: name,
                            breed: breed,
                            age: age,
                            interests: interests,
                            aboutMe: aboutMe,
                            photos: photoNames,
                            latitude: location.latitude,
                            longitude: location.longitude,
                            ownerId: ownerId,
                            ownerName: ownerName,
                            isOnline: isOnline,
                            updatedAt: Date.now,
                            createdAt: Date.now
                        )
                        
                        dogs.append(newDog)
                        showingAddDog = false
                        
                        // Show success message
                        let photoCount = photoNames.count
                        self.addDogSuccess = "\(name) has been successfully added with \(photoCount) photo(s)!"
                    } else {
                        // FAILURE: Photo upload failed - rollback dog creation
                        print("❌ Photo upload failed (\(photoNames.count)/\(photos.count) uploaded), rolling back dog creation")
                        // TODO: Add backend API to delete the created dog and delete uploaded photos
                        // await DogProfileService.shared.deleteDog(dogId: dogId)
                        
                        self.addDogError = "Failed to upload enough photos for \(name). At least 2 photos are required. Please try again."
                    }
                } else {
                    // Backend returned failure status
                    let errorMessage = response?.error ?? "Unknown error occurred"
                    self.addDogError = "Unable to save \(name): \(errorMessage)"
                }
                
            } catch {
                print("❌ Failed to save dog to backend: \(String(describing: response?.error))")
                // Set specific error for add dog failures
                self.addDogError = "Unable to save \(name). Please check your internet connection and try again."
            }
        }
    }

    func deleteDog(at indexSet: IndexSet) {
        // Delete all photos for each dog being deleted
        for index in indexSet {
            let dog = dogs[index]
            for photoName in dog.photos {
                if !photoName.starts(with: "dog_Creamie") {
                    deleteImage(named: photoName)
                }
            }
        }
        
        dogs.remove(atOffsets: indexSet)
        // TODO: In a real app, you would also delete from your backend/database
    }
    
    func deleteDog(dog: Dog) {
        if let index = dogs.firstIndex(where: { $0.id == dog.id }) {
            // Delete all photos for the dog
            for photoName in dog.photos {
                if !photoName.starts(with: "dog_Creamie") {
                    deleteImage(named: photoName)
                }
            }
            
            dogs.remove(at: index)
            // TODO: In a real app, you would also delete from your backend/database
            print("🗑️ Deleted dog: \(dog.name)")
        }
        dogToDelete = nil
    }
    
    func confirmDeleteDog(dog: Dog) {
        dogToDelete = dog
        showingDeleteConfirmation = true
    }
    
    // MARK: - Photo Upload Functions
    
    /// Upload multiple photos for a dog to the backend
    /// - Parameters:
    ///   - photos: Array of UIImages to upload
    ///   - dogId: UUID of the dog to associate photos with
    /// Uploads all photos for a dog. Uses all-or-nothing approach.
    /// - Returns: Array of successfully uploaded photo filenames (empty if any upload fails)
    private func uploadPhotos(_ photos: [UIImage], for dogId: UUID) async -> [String] {
        var photoNames: [String] = []
        
        // Try to upload all photos to backend supabase storage
        for (index, photo) in photos.enumerated() {
            do {
                let response = try await DogProfileService.shared.uploadDogPhoto(dogId: dogId, image: photo)
                photoNames.append(response.imageUrl)
                
            } catch {
                print("❌ Failed to upload photo \(index + 1): \(error)")
                // ALL-OR-NOTHING: If any photo fails, return empty array
                // This ensures consistent user experience - dog only appears with all intended photos
                return []
            }
        }
        
        print("📤 All \(photoNames.count) photos uploaded")
        return photoNames
    }
    
    private func deleteImage(named name: String) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent("\(name).jpg")
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("🗑️ Deleted image at: \(fileURL.path)")
        } catch {
            print("❌ Error deleting image: \(error)")
        }
    }
    
    func updateDogOnlineStatus(isOnline: Bool, dogId: UUID? = nil, userId: UUID? = nil) async {
        let updateDogOnlineStatusRequest = UpdateDogOnlineStatusRequest(
            isOnline: isOnline,
            dogId: dogId,
            ownerId: userId
        )
        
        do {
            let response = try await dogProfileService.updateDogOnlineStatus(request: updateDogOnlineStatusRequest)
            
            
            if response.status != "success" {
                print("❌ Failed to update online status on backend")
            }
            
            if let specificDogId = dogId {
                if let index = dogs.firstIndex(where: { $0.id == specificDogId }) {
                    dogs[index].isOnline = isOnline
                    dogs[index].updatedAt = Date.now
                }
            } else {
                for i in 0..<dogs.count {
                    if dogs[i].ownerId == userId {
                        dogs[i].isOnline = isOnline
                        dogs[i].updatedAt = Date.now
                    }
                }
            }
            
            let target = dogId != nil ? "dog \(dogId!.rawValue)" : "\(response.updatedCount) dogs of user \(userId!.rawValue)"
            print("✅ Updated online status to \(isOnline) for \(target)")
            
        } catch {
            print("❌ Failed to update online status: \(error)")
        }
    }
        
//    /// Save an image to the Documents directory with a specific filename
//    /// - Parameters:
//    ///   - image: The UIImage to save
//    ///   - name: The filename to use (without extension)
//    /// - Returns: The filename that was saved (for consistency)
//    private func saveImage(_ image: UIImage, name: String) -> String {
//        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        
//        // Remove any file extension and add .jpg
//        let cleanName = name.replacingOccurrences(of: ".jpg", with: "").replacingOccurrences(of: ".jpeg", with: "")
//        let filename = "\(cleanName).jpg"
//        let fileURL = documentsDirectory.appendingPathComponent(filename)
//        
//        if let imageData = image.jpegData(compressionQuality: 0.8) {
//            do {
//                try imageData.write(to: fileURL)
//                print("Saved image locally: \(filename)")
//                return cleanName // Return name without extension for consistency
//            } catch {
//                print("Error saving image \(filename): \(error)")
//                return cleanName // Return the name even if saving failed
//            }
//        }
//        
//        return cleanName
//    }
}
