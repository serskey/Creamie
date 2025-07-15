import Foundation
import CoreLocation
import UIKit

struct UpdateDogRequest: Codable {
    let name: String?
    let breed: String?
    let age: Int?
    let interests: [String]?
    let location: Location?
    let aboutMe: String?
    let ownerName: String?
}

struct DogsResponse: Codable {
    let dogs: [Dog]
    let totalCount: Int
    let page: Int
    let pageSize: Int
}

// MARK: - Dog Profile Service
class DogProfileService {
    static let shared = DogProfileService()
    
    private let apiService = APIService.shared
    
    private init() {}
    
    // MARK: - CRUD Operations
    
    /// Fetch all dogs for the current user
    func fetchUserDogs(getUserDogsRequest: GetUserDogsRequest) async throws -> GetUserDogsResponse {
        let endpoint = "/user/\(getUserDogsRequest.userId)/dogs"
        let response = try await apiService.request(
            endpoint: endpoint,
            method: .GET,
            responseType: GetUserDogsResponse.self
        )
        
        return response
    }
    
    /// Get a specific dog by ID
    func getDog(id: UUID) async throws -> Dog {
        let response = try await apiService.request(
            endpoint: "/dogs/dog/\(id.uuidString)",
            method: .GET,
            responseType: Dog.self
        )
        
        return response
    }
    
    /// Create a new dog profile
    func createDog(addDogRequest: AddDogRequest) async throws -> AddDogResponse {
        
        let response = try await apiService.request(
            endpoint: "/dogs/add",
            method: .POST,
            body: addDogRequest,
            responseType: AddDogResponse.self
        )
        
        return response
    }
    
    /// Update an existing dog profile
    func updateDog(
        id: UUID,
        name: String?,
        breed: DogBreed?,
        age: Int?,
        interests: [String]?,
        location: Location?,
        aboutMe: String?,
        ownerName: String?
    ) async throws -> Dog {
        
        let request = UpdateDogRequest(
            name: name,
            breed: breed?.rawValue,
            age: age,
            interests: interests,
            location: location,
            aboutMe: aboutMe,
            ownerName: ownerName
        )
        
        let response = try await apiService.request(
            endpoint: "/dogs/dog/\(id.uuidString)",
            method: .PUT,
            body: request,
            responseType: Dog.self
        )
        
        return response
    }
    
    /// Delete a dog profile
    func deleteDog(id: UUID) async throws {
        let _: EmptyResponse = try await apiService.request(
            endpoint: "/dogs/dog/\(id.uuidString)",
            method: .DELETE,
            responseType: EmptyResponse.self
        )
    }
    
    /// Upload a photo for a dog
    func uploadDogPhoto(dogId: UUID, image: UIImage) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw APIError.networkError(NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"]))
        }
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        let url = URL(string: APIConfig.baseURL + "/dogs/\(dogId.uuidString)/photos")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"dog_photo.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        
        request.httpBody = body
        
        // This is a simplified implementation - you'd need to implement proper multipart upload
        // For now, return a placeholder filename
        return "uploaded_photo_\(UUID().uuidString).jpg"
    }
    
    /// Delete a photo for a dog
    func deleteDogPhoto(dogId: UUID, photoName: String) async throws {
        let _: EmptyResponse = try await apiService.request(
            endpoint: "/dogs/\(dogId.uuidString)/photos/\(photoName)",
            method: .DELETE,
            responseType: EmptyResponse.self
        )
    }
    
    /// Search dogs by various criteria
    func searchDogs(name: String?, breed: String?, location: Location?, radius: Double?) async throws -> [Dog] {
        var queryItems: [String] = []
        
        if let name = name {
            queryItems.append("name=\(name)")
        }
        if let breed = breed {
            queryItems.append("breed=\(breed)")
        }
        if let location = location {
            queryItems.append("lat=\(location.latitude)")
            queryItems.append("lng=\(location.longitude)")
        }
        if let radius = radius {
            queryItems.append("radius=\(radius)")
        }
        
        let queryString = queryItems.isEmpty ? "" : "?" + queryItems.joined(separator: "&")
        let endpoint = "/dogs/search\(queryString)"
        
        let response = try await apiService.request(
            endpoint: endpoint,
            method: .GET,
            responseType: DogsResponse.self
        )
        
        return response.dogs.map { $0 }
    }
    
    /// Get dogs by breed
    func getDogsByBreed(_ breed: DogBreed) async throws -> [Dog] {
        let response = try await apiService.request(
            endpoint: "/dogs/breed/\(breed.rawValue)",
            method: .GET,
            responseType: DogsResponse.self
        )
        
        return response.dogs.map { $0 }
    }
    
    /// Get dogs within a specific radius
    func getNearbyDogs(location: Location, radius: Double = 5.0) async throws -> [Dog] {
        let endpoint = "/dogs/nearby?lat=\(location.latitude)&lng=\(location.longitude)&radius=\(radius)"
        let response = try await apiService.request(
            endpoint: endpoint,
            method: .GET,
            responseType: DogsResponse.self
        )
        
        return response.dogs.map { $0 }
    }
}

// MARK: - Helper Extensions
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
} 
