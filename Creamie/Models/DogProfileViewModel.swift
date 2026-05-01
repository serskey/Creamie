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
    
    // Per-photo upload progress (photoIndex -> progress 0.0...1.0)
    @Published var uploadProgress: [Int: Double] = [:]
    
    // Fetch deduplication flags
    private(set) var hasFetchedDogs = false
    private var isFetching = false
    
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
    
    func fetchUserDogs(userId: UUID, forceFetch: Bool = false) async {
        // Skip if already fetching to prevent concurrent duplicate requests
        guard !isFetching else { return }
        
        // Skip if dogs have already been fetched and no mutation has occurred
        guard !hasFetchedDogs || forceFetch else { return }
        
        isFetching = true
        defer { isFetching = false }
        
        let getUserDogsRequest = GetUserDogsRequest(userId: userId)
        
        do {
            let response = try await dogProfileService.fetchUserDogs(getUserDogsRequest: getUserDogsRequest)
            self.dogs = response.dogs
            self.hasFetchedDogs = true
            
            #if DEBUG
            print("🐾 Fetched \(response.totalCount) dogs from user \(userId)")
            #endif
        } catch {
            // Pending Add error detail from backend
            #if DEBUG
            print("❌ Failed to fetch user's dogs: \(error)")
            #endif
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
                        hasFetchedDogs = false
                        
                        self.addDogSuccess = "\(name) has been successfully added with \(photoNames.count) photo(s)!"
                    } else {
                        print("❌ Photo upload failed (\(photoNames.count)/\(photos.count) uploaded), rolling back dog creation")
                        // Pending Add backend API to delete the created dog and delete uploaded photos
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
            hasFetchedDogs = false
            print("🗑️ Deleted dog: \(dog.name)")
        }
        dogToDelete = nil
    }
    
    func confirmDeleteDog(dog: Dog) {
        dogToDelete = dog
        showingDeleteConfirmation = true
    }
    
    // MARK: - Image Resize Helper
    
    /// Resizes an image so that its longest edge does not exceed `maxEdge` pixels.
    /// Preserves the original aspect ratio. Returns the original image if no resize is needed.
    private func resizeImageIfNeeded(_ image: UIImage, maxEdge: CGFloat = 2048) -> UIImage {
        let width = image.size.width * image.scale
        let height = image.size.height * image.scale
        let longestEdge = max(width, height)
        
        guard longestEdge > maxEdge else { return image }
        
        let scaleFactor = maxEdge / longestEdge
        let newWidth = width * scaleFactor
        let newHeight = height * scaleFactor
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Prepares an image for upload by resizing (if needed) and compressing to JPEG 0.7 quality.
    private func prepareImageForUpload(_ image: UIImage) -> UIImage? {
        let resized = resizeImageIfNeeded(image)
        // Compress to JPEG 0.7 quality and re-create UIImage from that data
        // so the service receives an image that produces 0.7-quality JPEG data
        guard let jpegData = resized.jpegData(compressionQuality: 0.7) else { return nil }
        return UIImage(data: jpegData)
    }
    
    // MARK: - Upload with Retry
    
    /// Uploads a single photo with retry logic (up to 2 retries with exponential backoff).
    private func uploadPhotoWithRetry(dogId: UUID, image: UIImage, index: Int) async throws -> String {
        let maxRetries = 2
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            do {
                let response = try await DogProfileService.shared.uploadDogPhoto(dogId: dogId, image: image)
                return response.imageUrl
            } catch {
                lastError = error
                if attempt < maxRetries {
                    let delay = BackoffCalculator.backoffDelay(attempt: attempt)
                    #if DEBUG
                    print("⚠️ Upload attempt \(attempt + 1) failed for photo \(index + 1), retrying in \(delay)s...")
                    #endif
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? APIError.networkError(
            NSError(domain: "UploadError", code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Upload failed after \(maxRetries + 1) attempts"])
        )
    }
    
    // MARK: - Optimized Photo Upload
    
    private func uploadPhotos(_ photos: [UIImage], for dogId: UUID) async -> [String] {
        // Reset progress tracking
        uploadProgress = [:]
        for index in photos.indices {
            uploadProgress[index] = 0.0
        }
        
        // Prepare all images (resize + compress) before uploading
        var preparedImages: [(index: Int, image: UIImage)] = []
        for (index, photo) in photos.enumerated() {
            guard let prepared = prepareImageForUpload(photo) else {
                print("❌ Failed to prepare photo \(index + 1) for upload")
                return []
            }
            preparedImages.append((index: index, image: prepared))
        }
        
        // Upload up to 2 photos concurrently using TaskGroup with a concurrency limit
        var photoNames: [String?] = Array(repeating: nil, count: photos.count)
        var uploadFailed = false
        
        // Process in chunks of 2 for concurrency limiting
        let chunkSize = 2
        for chunkStart in stride(from: 0, to: preparedImages.count, by: chunkSize) {
            let chunkEnd = min(chunkStart + chunkSize, preparedImages.count)
            let chunk = Array(preparedImages[chunkStart..<chunkEnd])
            
            let results: [(Int, String?)] = await withTaskGroup(of: (Int, String?).self) { group in
                for item in chunk {
                    group.addTask { [weak self] in
                        guard let self = self else { return (item.index, nil) }
                        do {
                            let url = try await self.uploadPhotoWithRetry(
                                dogId: dogId,
                                image: item.image,
                                index: item.index
                            )
                            return (item.index, url)
                        } catch {
                            print("❌ Failed to upload photo \(item.index + 1) after retries: \(error)")
                            return (item.index, nil)
                        }
                    }
                }
                
                var collected: [(Int, String?)] = []
                for await result in group {
                    collected.append(result)
                    // Update progress on main actor
                    await MainActor.run {
                        self.uploadProgress[result.0] = result.1 != nil ? 1.0 : 0.0
                    }
                }
                return collected
            }
            
            for (index, url) in results {
                photoNames[index] = url
                if url == nil {
                    uploadFailed = true
                }
            }
            
            // If any upload in this chunk failed, stop processing further chunks
            if uploadFailed {
                return []
            }
        }
        
        // Verify all uploads succeeded
        let successfulNames = photoNames.compactMap { $0 }
        if successfulNames.count != photos.count {
            return []
        }
        
        print("📤 All \(successfulNames.count) photos uploaded")
        return successfulNames
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
                    hasFetchedDogs = false
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
