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
    
    func fetchUserDogs(userId: UUID) async {
        let getUserDogsRequest = GetUserDogsRequest(userId: userId)
        
        do {
            let response = try await dogProfileService.fetchUserDogs(getUserDogsRequest: getUserDogsRequest)
            self.dogs = response.dogs
            print("Fetched \(response.totalCount) dogs from user \(userId)")
        } catch {
            // TODO: Add error detail from backend
            print("Failed to fetch user's dogs")
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
        // Generate unique photo names for each image (UI ensures >= 2 photos)
        var photoNames: [String] = []
        
        for (index) in photos.enumerated() {
            let photoName = "dog_\(name.replacingOccurrences(of: " ", with: "_"))_\(photoCounter)_\(index)"
            photoCounter += 1
        
//             // TODO: Save to backend db
//                saveImage(photo, withName: photoName)
            photoNames.append(photoName)
        }
        
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
                print("Successfully saved dog to backend: \(String(describing: response?.dogId))")
                
                // Only add to local array if backend save succeeded
                let newDog = Dog(
                    id: UUID(),
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
                self.addDogSuccess = "\(name) has been successfully added to your dogs!"
                
            } catch {
                print("Failed to save dog to backend: \(String(describing: response?.error))")
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
            print("Deleted dog: \(dog.name)")
        }
        dogToDelete = nil
    }
    
    func confirmDeleteDog(dog: Dog) {
        dogToDelete = dog
        showingDeleteConfirmation = true
    }
    
    private func saveImage(_ image: UIImage, withName name: String) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent("\(name).jpg")
        
        do {
            try data.write(to: fileURL)
            print("Saved image to: \(fileURL.path)")
        } catch {
            print("Error saving image: \(error)")
        }
    }
    
    private func deleteImage(named name: String) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent("\(name).jpg")
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("Deleted image at: \(fileURL.path)")
        } catch {
            print("Error deleting image: \(error)")
        }
    }
}
