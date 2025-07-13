import Foundation
import CoreLocation
import UIKit

// MARK: - Data Models for API
struct DogResponse: Codable {
    let id: UUID
    let name: String
    let breed: String
    let age: Int
    let interests: [String]?
    let location: Location
    let photos: [String]
    let aboutMe: String?
    let ownerName: String?
    let createdAt: Date
    let updatedAt: Date
    
    // Convert to local Dog model
    func toDog() -> Dog {
        return Dog(
            id: id,
            name: name,
            breed: DogBreed(rawValue: breed) ?? .cockapoo,
            age: age,
            interests: interests,
            location: location,
            photos: photos,
            aboutMe: aboutMe,
            ownerName: ownerName
        )
    }
}

struct LocationResponse: Codable {
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct CreateDogRequest: Codable {
    let name: String
    let breed: String
    let age: Int
    let interests: [String]?
    let location: LocationResponse
    let aboutMe: String?
    let ownerName: String?
    
    init(from dog: Dog) {
        self.name = dog.name
        self.breed = dog.breed.rawValue
        self.age = dog.age
        self.interests = dog.interests
        self.location = LocationResponse(
            latitude: dog.location.latitude,
            longitude: dog.location.longitude
        )
        self.aboutMe = dog.aboutMe
        self.ownerName = dog.ownerName
    }
    
    init(name: String, breed: String, age: Int, interests: [String]?, location: LocationResponse, aboutMe: String?, ownerName: String?) {
        self.name = name
        self.breed = breed
        self.age = age
        self.interests = interests
        self.location = location
        self.aboutMe = aboutMe
        self.ownerName = ownerName
    }
}

struct UpdateDogRequest: Codable {
    let name: String?
    let breed: String?
    let age: Int?
    let interests: [String]?
    let location: LocationResponse?
    let aboutMe: String?
    let ownerName: String?
}

struct DogsResponse: Codable {
    let dogs: [DogResponse]
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
    func fetchUserDogs() async throws -> [Dog] {
        let response = try await apiService.request(
            endpoint: "/dogs/user",
            method: .GET,
            responseType: DogsResponse.self
        )
        
        return response.dogs.map { $0.toDog() }
    }
    
    /// Fetch dogs with pagination
    func fetchDogs(page: Int = 1, pageSize: Int = 20) async throws -> DogsResponse {
        let endpoint = "/dogs?page=\(page)&pageSize=\(pageSize)"
        return try await apiService.request(
            endpoint: endpoint,
            method: .GET,
            responseType: DogsResponse.self
        )
    }
    
    /// Get a specific dog by ID
    func getDog(id: UUID) async throws -> Dog {
        let response = try await apiService.request(
            endpoint: "/dogs/\(id.uuidString)",
            method: .GET,
            responseType: DogResponse.self
        )
        
        return response.toDog()
    }
    
    /// Create a new dog profile
    func createDog(name: String, breed: DogBreed, age: Int, interests: [String]?, location: Location, aboutMe: String?, ownerName: String?) async throws -> Dog {
        let request = CreateDogRequest(
            name: name,
            breed: breed.rawValue,
            age: age,
            interests: interests,
            location: LocationResponse(latitude: location.latitude, longitude: location.longitude),
            aboutMe: aboutMe,
            ownerName: ownerName
        )
        
        let response = try await apiService.request(
            endpoint: "/dogs",
            method: .POST,
            body: request,
            responseType: DogResponse.self
        )
        
        return response.toDog()
    }
    
    /// Update an existing dog profile
    func updateDog(id: UUID, name: String?, breed: DogBreed?, age: Int?, interests: [String]?, location: Location?, aboutMe: String?, ownerName: String?) async throws -> Dog {
        var locationResponse: LocationResponse?
        if let location = location {
            locationResponse = LocationResponse(latitude: location.latitude, longitude: location.longitude)
        }
        
        let request = UpdateDogRequest(
            name: name,
            breed: breed?.rawValue,
            age: age,
            interests: interests,
            location: locationResponse,
            aboutMe: aboutMe,
            ownerName: ownerName
        )
        
        let response = try await apiService.request(
            endpoint: "/dogs/\(id.uuidString)",
            method: .PUT,
            body: request,
            responseType: DogResponse.self
        )
        
        return response.toDog()
    }
    
    /// Delete a dog profile
    func deleteDog(id: UUID) async throws {
        let _: EmptyResponse = try await apiService.request(
            endpoint: "/dogs/\(id.uuidString)",
            method: .DELETE,
            responseType: EmptyResponse.self
        )
    }
    
    // MARK: - Photo Management
    
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
    
    // MARK: - Search and Filter
    
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
        
        return response.dogs.map { $0.toDog() }
    }
    
    /// Get dogs by breed
    func getDogsByBreed(_ breed: DogBreed) async throws -> [Dog] {
        let response = try await apiService.request(
            endpoint: "/dogs/breed/\(breed.rawValue)",
            method: .GET,
            responseType: DogsResponse.self
        )
        
        return response.dogs.map { $0.toDog() }
    }
    
    /// Get dogs within a specific radius
    func getNearbyDogs(location: Location, radius: Double = 5.0) async throws -> [Dog] {
        let endpoint = "/dogs/nearby?lat=\(location.latitude)&lng=\(location.longitude)&radius=\(radius)"
        let response = try await apiService.request(
            endpoint: endpoint,
            method: .GET,
            responseType: DogsResponse.self
        )
        
        return response.dogs.map { $0.toDog() }
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
