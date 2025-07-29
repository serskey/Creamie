import Foundation
import SwiftUI
import CoreLocation
import UIKit

struct Dog: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var breed: DogBreed
    var age: Int
    var interests: [String]?
    var aboutMe: String?
    var photos: [String]
    var latitude: Double
    var longitude: Double
    var ownerId: UUID
    var ownerName: String?
    var isOnline: Bool
    var updatedAt: Date?
    var createdAt: Date?
    
    // Convenience property for backward compatibility
    var photo: String {
        return photos.first ?? "dog_Sample"
    }
    
    static func == (lhs: Dog, rhs: Dog) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    init(
            id: UUID,
            name: String,
            breed: DogBreed,
            age: Int,
            interests: [String]? = nil,
            aboutMe: String? = nil,
            photos: [String],
            latitude: Double,
            longitude: Double,
            ownerId: UUID,
            ownerName: String? = nil,
            isOnline: Bool,
            updatedAt: Date,
            createdAt: Date? = nil,
        ) {
            self.id = id
            self.name = name
            self.breed = breed
            self.age = age
            self.interests = interests
            self.latitude = latitude
            self.longitude = longitude
            self.photos = photos
            self.aboutMe = aboutMe
            self.ownerId = ownerId
            self.ownerName = ownerName
            self.isOnline = isOnline
            self.updatedAt = updatedAt
            self.createdAt = createdAt
        }
}

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
    @Published var deleteDogError: String?
    @Published var deleteDogSuccess: String?
    
    private let dogProfileService = DogProfileService.shared
    
    private var photoCounter = 0
    
    private let minPhotos = 1
    
    func fetchUserDogs(userId: UUID) async {
        let getUserDogsRequest = GetUserDogsRequest(userId: userId)
        
        do {
            let response = try await dogProfileService.fetchUserDogs(getUserDogsRequest: getUserDogsRequest)
            self.dogs = response.dogs
            
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
        var photoNames: [String] = []
        
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
                
                // Step1: save dog profile to db
                response = try await DogProfileService.shared.createDog(addDogRequest: addDogRequest)
                
                if let response = response, response.status.lowercased() == "success", let dogId = response.dogId {
                    print("🐾 Successfully saved dog profile to backend: \(dogId)")
                    
                    // Step2: Upload dog photos to storage
                    photoNames = await uploadPhotos(photos, for: dogId)
                    
                    if photoNames.count >= minPhotos {
                        
                        // Step3: append dog to local
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
                        
                        self.addDogSuccess = "\(name) has been successfully added with \(photoNames.count) photo(s)!"
                    } else {
                        print("❌ Photo upload failed (\(photoNames.count)/\(photos.count) uploaded), rolling back dog creation")
                        // TODO: Add backend API to delete the created dog and delete uploaded photos
                        // await DogProfileService.shared.deleteDogProfile(dogId: dogId)
                        
                        self.addDogError = "Failed to upload enough photos for \(name). At least 2 photos are required. Please try again."
                    }
                } else {
                    let errorMessage = response?.error ?? "Unknown error occurred"
                    self.addDogError = "Unable to save \(name): \(errorMessage)"
                }
                
            } catch {
                print("❌ Failed to save dog to backend: \(String(describing: response?.error))")
                self.addDogError = "Unable to save \(name). Please check your internet connection and try again."
            }
        }
    }

//    func deleteDog(at indexSet: IndexSet) {
//        for index in indexSet {
//            let dog = dogs[index]
//            
//            // Step1: delete dog from backend
//            var response: DeleteDogResponse?
//            
//            do {
//                let response = try await DogProfileService.shared.deleteDog(id: dog.id)
//            } catch {
//                print("❌ Failed to save dog to backend: \(String(describing: response?.error))")
//                self.deleteDogError = "Unable to delete \(dog.name). Please check your internet connection and try again."
//            }
//            
//            // Step2: Clean up dog photos from local
//            for photoName in dog.photos {
//                if photoName.starts(with: "dog_Creamie") {
//                    continue
//                }
//        
//                deleteImage(named: photoName)
//                
//            }
//        }
//        
//        // Step3: Remove dog profile from local
//        dogs.remove(atOffsets: indexSet)
//    }
    
    func deleteDog(dog: Dog) async throws {
        print("🔄 Deleting dog: \(dog.name)")
        if let index = dogs.firstIndex(where: { $0.id == dog.id }) {
            // Step1: delete dog from backend
            var response: DeleteDogResponse?
            
            do {
                response = try await DogProfileService.shared.deleteDog(id: dog.id, photos: dog.photos)
                
            } catch {
                print("❌ Failed to delete dog from backend: \(String(describing: response?.error))")
                self.deleteDogError = "Unable to delete \(dog.name). Please check your internet connection and try again."
                throw APIError.serverError(500)
            }
            
            // Step2: Remove dog profile from local
            dogs.remove(at: index)
            print("🗑️ Deleted dog: \(dog.name)")
        }
        dogToDelete = nil
    }
    
    func confirmDeleteDog(dog: Dog) {
        dogToDelete = dog
        showingDeleteConfirmation = true
    }
    
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
