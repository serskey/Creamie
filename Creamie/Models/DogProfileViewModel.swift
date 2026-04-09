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
    var isLocationTrackingEnabled: Bool?
    var lastLocationUpdate: Date?
    
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
            isLocationTrackingEnabled: Bool? = nil,
            lastLocationUpdate: Date? = nil
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
            self.isLocationTrackingEnabled = isLocationTrackingEnabled
            self.lastLocationUpdate = lastLocationUpdate
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
    @Published var showingEditDog = false
    
    // Location tracking
    @Published var locationTracker: DogLocationTracker
    
    private let dogProfileService = DogProfileService.shared
    
    private var photoCounter = 0
    
    private let minPhotos = 1
    
    // MARK: - Initialization
    
    init(locationTracker: DogLocationTracker) {
        self.locationTracker = locationTracker
    }
    
    // MARK: - Location Tracking Methods
    
    /// Toggle location tracking for a specific dog.
    /// Returns false if permission is needed (caller should show appropriate UI).
    @discardableResult
    func toggleLocationTracking(for dogId: UUID, enabled: Bool) async -> Bool {
        // Keep dog names in sync for notification messages
        if let dog = dogs.first(where: { $0.id == dogId }) {
            locationTracker.dogNames[dogId] = dog.name
        }
        
        if enabled {
            // Check permissions before starting tracking
            let result = locationTracker.checkPermissionForTracking()
            
            switch result {
            case .authorized:
                // Already have "Always" — start tracking immediately
                locationTracker.startTracking(for: dogId)
                await updateDogOnlineStatus(isOnline: true, dogId: dogId)
                if let index = dogs.firstIndex(where: { $0.id == dogId }) {
                    dogs[index].isLocationTrackingEnabled = true
                    dogs[index].lastLocationUpdate = Date()
                }
                return true
                
            case .needsAlwaysExplanation:
                // Need to show explanation alert, then request permission
                locationTracker.needsAlwaysPermissionExplanation = true
                locationTracker.pendingTrackingDogId = dogId
                return false
                
            case .denied(let message):
                // Permission denied — show denial message
                locationTracker.permissionDenied = true
                locationTracker.permissionDeniedMessage = message
                return false
            }
        } else {
            locationTracker.stopTracking(for: dogId)
            await updateDogOnlineStatus(isOnline: false, dogId: dogId)
            if let index = dogs.firstIndex(where: { $0.id == dogId }) {
                dogs[index].isLocationTrackingEnabled = false
            }
            return true
        }
    }
    
    /// Called after user acknowledges the "Always" permission explanation alert.
    /// Requests the actual system permission.
    func confirmAlwaysPermissionRequest() {
        guard let dogId = locationTracker.pendingTrackingDogId else { return }
        locationTracker.requestAlwaysAuthorization(for: dogId)
    }
    
    /// Get tracking status for a specific dog
    func getLocationTrackingStatus(for dogId: UUID) -> TrackingStatus? {
        return locationTracker.getTrackingStatus(for: dogId)
    }
    
    /// Check if location tracking is enabled for a specific dog
    func isLocationTrackingEnabled(for dogId: UUID) -> Bool {
        return locationTracker.isTracking(dogId: dogId)
    }
    
    /// Load tracking preferences on app start and resume tracking
    func loadTrackingPreferences() {
        let preferencesStore = TrackingPreferencesStore()
        let allPreferences = preferencesStore.loadAllPreferences()
        
        // Sync dog names for notification messages
        for dog in dogs {
            locationTracker.dogNames[dog.id] = dog.name
        }
        
        for preference in allPreferences {
            if preference.isEnabled {
                // Check if this dog exists in our dogs array
                if dogs.contains(where: { $0.id == preference.dogId }) {
                    print("🔄 Resuming tracking for dog: \(preference.dogId)")
                    locationTracker.startTracking(for: preference.dogId)
                    
                    // Update local dog model
                    if let index = dogs.firstIndex(where: { $0.id == preference.dogId }) {
                        dogs[index].isLocationTrackingEnabled = true
                        dogs[index].lastLocationUpdate = preference.lastUpdateTime
                    }
                }
            }
        }
    }
    
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

    func updateDog(
        dogId: UUID,
        name: String,
        breed: DogBreed,
        age: Int,
        interests: [String] = [],
        existingPhotos: [String],
        newPhotos: [UIImage],
        aboutMe: String?,
        photosToDelete: [String]
    ) {
        Task {
            var finalPhotos = existingPhotos
            var response: UpdateDogProfileResponse?
            
            do {
                // Step 1: Upload new photos if any
                if !newPhotos.isEmpty {
                    let newPhotoNames = await uploadPhotos(newPhotos, for: dogId)
                    if newPhotoNames.count == newPhotos.count {
                        finalPhotos.append(contentsOf: newPhotoNames)
                        print("📸 Successfully uploaded \(newPhotoNames.count) new photos")
                    } else {
                        print("❌ Failed to upload all new photos")
                        self.addDogError = "Failed to upload some photos. Please try again."
                        return
                    }
                }
                
                // Step 2: Update dog profile in backend
                let updateDogRequest = UpdateDogProfileRequest(
                    dogId: dogId,
                    name: name,
                    breed: breed.rawValue,
                    age: age,
                    interests: interests,
                    photos: finalPhotos,
                    aboutMe: aboutMe
                )
                
                response = try await DogProfileService.shared.updateDog(updateDogRequest: updateDogRequest)
                
                if let response = response, response.status.lowercased() == "success" {
                    print("🐾 Successfully updated dog profile in backend")
                    
                    // Step 3: Update local dog data
                    if let index = dogs.firstIndex(where: { $0.id == dogId }) {
                        dogs[index] = Dog(
                            id: dogId,
                            name: name,
                            breed: breed,
                            age: age,
                            interests: interests,
                            aboutMe: aboutMe,
                            photos: finalPhotos,
                            latitude: dogs[index].latitude,
                            longitude: dogs[index].longitude,
                            ownerId: dogs[index].ownerId,
                            ownerName: dogs[index].ownerName,
                            isOnline: dogs[index].isOnline,
                            updatedAt: Date.now,
                            createdAt: dogs[index].createdAt
                        )
                    }
                    
                    showingEditDog = false
                    self.addDogSuccess = "\(name) has been successfully updated!"
                    
                } else {
                    let errorMessage = response?.error ?? "Unknown error occurred"
                    self.addDogError = "Unable to update \(name): \(errorMessage)"
                }
                
            } catch {
                print("❌ Failed to update dog in backend: \(String(describing: response?.error))")
                self.addDogError = "Unable to update \(name). Please check your internet connection and try again."
            }
        }
    }
}
