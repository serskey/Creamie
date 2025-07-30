import Foundation
import CoreLocation
import UIKit

struct DogsResponse: Codable {
    let dogs: [Dog]
    let totalCount: Int
    let page: Int
    let pageSize: Int
}

struct AddDogRequest: Codable {
    let name: String
    let breed: String
    let age: Int
    let interests: [String]?
    let latitude: Double
    let longitude: Double
    let photos: [String]
    let aboutMe: String?
    let ownerName: String?
    let ownerId: UUID
    let isOnline: Bool
}

struct AddDogResponse: Codable {
    let status: String
    let dogId: UUID?
    let error: String?
}

struct DeleteDogRequest: Codable {
    let dogId: UUID
    let photos: [String]
}

struct DeleteDogResponse: Codable {
    let status: String
    let dogId: UUID
    let error: String?
}


struct GetUserDogsRequest: Codable {
    let userId: UUID
}

struct GetUserDogsResponse: Codable {
    let dogs: [Dog]
    let totalCount: Int
}

struct NearbyDogsRequest: Codable {
    let northEastLat: Double
    let northEastLon: Double
    let southWestLat: Double
    let southWestLon: Double
}

struct NearbyDogsResponse: Codable {
    let dogs: [Dog]
    let totalCount: Int
}

struct UploadDogPhotoRequest: Codable {
    let dogId: UUID
    let imageData: Data
}

struct UploadDogPhotoResponse: Codable {
    let dogId: UUID
    let imageUrl: String
    let photos: [String]
}

struct UpdateDogOnlineStatusRequest: Codable {
    let isOnline: Bool
    let dogId: UUID?
    let ownerId: UUID?
}

struct UpdateDogOnlineStatusResponse: Codable {
    let status: String
    let updatedCount: Int
    let message: String
}

struct UpdateDogProfileRequest: Codable {
    let dogId: UUID
    let name: String
    let breed: String
    let age: Int
    let interests: [String]
    let photos: [String]
    let aboutMe: String?
}

struct UpdateDogProfileResponse: Codable {
    let status: String
    let error: String?
    let dogId: UUID
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
    
    func getDog(id: UUID) async throws -> Dog {
        let response = try await apiService.request(
            endpoint: "/dogs/dog/\(id.uuidString)",
            method: .GET,
            responseType: Dog.self
        )
        
        return response
    }
    
    func createDog(addDogRequest: AddDogRequest) async throws -> AddDogResponse {
        
        let response = try await apiService.request(
            endpoint: "/dogs/add",
            method: .POST,
            body: addDogRequest,
            responseType: AddDogResponse.self
        )
        
        return response
    }
    
    func deleteDog(id: UUID, photos: [String]) async throws -> DeleteDogResponse {
        let request = DeleteDogRequest(
            dogId: id,
            photos: photos
        )
        
        let response = try await apiService.request(
            endpoint: "/dogs",
            method: .DELETE,
            body: request,
            responseType: DeleteDogResponse.self
        )
        
        return response
    }
    
    func uploadDogPhoto(dogId: UUID, image: UIImage) async throws -> UploadDogPhotoResponse {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.networkError(NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"]))
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(apiService.baseURL)/dogs/upload_photo")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add dog_id
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"dog_id\"\r\n\r\n")
        body.appendString("\(dogId.uuidString)\r\n")

        // Add photo file
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n")
        body.appendString("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.appendString("\r\n")

        // Close boundary
        body.appendString("--\(boundary)--\r\n")

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.networkError(NSError(domain: "UploadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed with status code \((response as? HTTPURLResponse)?.statusCode ?? 0)"]))
        }

        let uploadDogPhotoResponse = try JSONDecoder().decode(UploadDogPhotoResponse.self, from: data)
        return uploadDogPhotoResponse
    }
    
    func deleteDogPhoto(dogId: UUID, photoName: String) async throws {
        let _: EmptyResponse = try await apiService.request(
            endpoint: "/dogs/\(dogId.uuidString)/photos/\(photoName)",
            method: .DELETE,
            responseType: EmptyResponse.self
        )
    }
    
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
    
    func getDogsByBreed(_ breed: DogBreed) async throws -> [Dog] {
        let response = try await apiService.request(
            endpoint: "/dogs/breed/\(breed.rawValue)",
            method: .GET,
            responseType: DogsResponse.self
        )
        
        return response.dogs.map { $0 }
    }
    
    func getNearbyDogs(location: Location, radius: Double = 5.0) async throws -> [Dog] {
        let endpoint = "/dogs/nearby?lat=\(location.latitude)&lng=\(location.longitude)&radius=\(radius)"
        let response = try await apiService.request(
            endpoint: endpoint,
            method: .GET,
            responseType: DogsResponse.self
        )
        
        return response.dogs.map { $0 }
    }
    
    func updateDogOnlineStatus(request: UpdateDogOnlineStatusRequest) async throws -> UpdateDogOnlineStatusResponse {
        
        let response = try await apiService.request(
            endpoint: "/dogs/update-online-status",
            method: .POST,
            body: request,
            responseType: UpdateDogOnlineStatusResponse.self
        )
        
        return response

    }
    
    func updateDog(updateDogRequest: UpdateDogProfileRequest) async throws -> UpdateDogProfileResponse {
//        let request = UpdateDogProfileRequest(
//            dogId: updateDogRequest.dogId,
//            name: updateDogRequest.name,
//            breed: updateDogRequest.breed,
//            age: updateDogRequest.age,
//            interests: updateDogRequest.interests,
//            photos: updateDogRequest.photos,
//            aboutMe: updateDogRequest.aboutMe
//        )
        
        let response = try await apiService.request(
            endpoint: "/dogs/update",
            method: .PUT,
            body: updateDogRequest,
            responseType: UpdateDogProfileResponse.self
        )
        
        return response

    }
}

// MARK: - Helper Extensions
extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
} 
