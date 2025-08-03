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

struct SearchDogsRequest: Codable {
    let query: String
}

struct SearchDogsResponse: Codable {
    let dogs: [Dog]
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
    
    func updateDog(updateDogRequest: UpdateDogProfileRequest) async throws -> UpdateDogProfileResponse {
        
        let response = try await apiService.request(
            endpoint: "/dogs/update",
            method: .PUT,
            body: updateDogRequest,
            responseType: UpdateDogProfileResponse.self
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
    
    func searchDogs(query: String?, breed: String?, location: Location?, radius: Double?) async throws -> [Dog] {
        guard let unwrappedQuery = query, !unwrappedQuery.isEmpty else {
            let endpoint = "/dogs/semantic-search"
            let response = try await apiService.request(
                endpoint: endpoint,
                method: .GET,
                responseType: DogsResponse.self
            )
            return response.dogs
        }

        let endpoint = "/dogs/semantic-search"
        let body = SearchDogsRequest(
            query: unwrappedQuery
        )
        let response = try await apiService.request(
            endpoint: endpoint,
            method: .POST,
            body: body,
            responseType: SearchDogsResponse.self
        )
        print("Founds dogs: \(response) ")
        return response.dogs
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

}

// MARK: - Helper Extensions
extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
