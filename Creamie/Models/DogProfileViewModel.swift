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
    
    // Photo storage
    private var photoCounter = 0
    
    func fetchDogs() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // TODO: Replace with actual API call
            // Simulating network delay
            try await Task.sleep(nanoseconds: 1_000_000_000)
            dogs = Dog.sampleDogs
        } catch {
            self.error = error
        }
    }
    
    func refreshDogs() {
        Task {
            await fetchDogs()
        }
    }
    
    func addDog(name: String, breed: DogBreed, age: Int, interests: [String] = [], location: Location, photos: [UIImage]?) {
        // Generate photo names or use default
        var photoNames: [String] = []
        
        if let dogPhotos = photos, !dogPhotos.isEmpty {
            // Generate unique photo names for each image
            for (index, photo) in dogPhotos.enumerated() {
                let photoName = "dog_\(name.replacingOccurrences(of: " ", with: "_"))_\(photoCounter)_\(index)"
                photoCounter += 1
                
                // Save photo to documents directory
                saveImage(photo, withName: photoName)
                photoNames.append(photoName)
            }
        } else {
            // Use default photo
            photoNames = ["dog_Creamie"]
        }
        
        let newDog = Dog(
            id: UUID(),
            name: name,
            breed: breed,
            age: age,
            interests: interests,
            location: location,
            photos: photoNames
        )
        
        dogs.append(newDog)
        showingAddDog = false
        
        // TODO: In a real app, you would save this to your backend/database
        print("Added new dog: \(newDog.name) with \(photoNames.count) photos")
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
    
    // MARK: - Image Handling
    
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
