import Foundation
import CoreLocation
import Combine

// MARK: - Data Models for API
struct DogLocationUpdate: Codable {
    let id: UUID
    let location: Location
    let timestamp: Date
    let isOnline: Bool
    
    var coordinate: CLLocationCoordinate2D {
        location.coordinate
    }
}

struct DogLocationRequest: Codable {
    let dogId: UUID
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}

// Note: NearbyDogsRequest and NearbyDogsResponse are now defined in BackendModel.swift

// MARK: - Real-time Location Service
class DogLocationService: ObservableObject {
    static let shared = DogLocationService()
    
    @Published var nearbyDogs: [Dog] = []
    @Published var isConnected = false
    @Published var connectionError: Error?
    
    private let apiService = APIService.shared
    private var webSocketTask: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    /// Fetch nearby dogs from the server
    func fetchNearbyDogs(request: NearbyDogsRequest) async throws -> NearbyDogsResponse {
        print("Fetching nearby dogs from backend...")
        let response = try await apiService.request(
            endpoint: "/dogs/nearby",
            method: .POST,
            body: request,
            responseType: NearbyDogsResponse.self
        )
        
        await MainActor.run {
            self.nearbyDogs = response.dogs
        }
        
        print("Fetched \(response.totalCount) nearby dogs from backend")
        return response
    }
    
    /// Update a dog's location on the server
    func updateDogLocation(dogId: UUID, location: CLLocationCoordinate2D) async throws {
        let request = DogLocationRequest(
            dogId: dogId,
            latitude: location.latitude,
            longitude: location.longitude,
            timestamp: Date()
        )
        
        let _: EmptyResponse = try await apiService.request(
            endpoint: "/dogs/\(dogId.uuidString)/location",
            method: .PUT,
            body: request,
            responseType: EmptyResponse.self
        )
    }
    
    /// Get specific dog's current location
    func getDogLocation(dogId: UUID) async throws -> DogLocationUpdate {
        return try await apiService.request(
            endpoint: "/dogs/\(dogId.uuidString)/location",
            method: .GET,
            responseType: DogLocationUpdate.self
        )
    }
    
    // MARK: - Real-time WebSocket Connection
    /// Start real-time location updates for a specific area
    func startRealTimeUpdates(userLocation: CLLocationCoordinate2D, radius: Double = 5.0) {
        // Close existing connection if any
        stopRealTimeUpdates()
        
        // Create WebSocket connection
        let endpoint = "/dogs/realtime?lat=\(userLocation.latitude)&lng=\(userLocation.longitude)&radius=\(radius)"
        webSocketTask = apiService.createWebSocketConnection(endpoint: endpoint)
        
        guard let webSocketTask = webSocketTask else {
            DispatchQueue.main.async {
                self.connectionError = APIError.invalidURL
            }
            return
        }
        
        // Start connection
        webSocketTask.resume()
        
        // Listen for messages
        listenForMessages()
        
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionError = nil
        }
    }
    
    /// Stop real-time location updates
    func stopRealTimeUpdates() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    /// Send location update through WebSocket
    func sendLocationUpdate(dogId: UUID, location: CLLocationCoordinate2D) {
        guard let webSocketTask = webSocketTask else { return }
        
        let update = DogLocationRequest(
            dogId: dogId,
            latitude: location.latitude,
            longitude: location.longitude,
            timestamp: Date()
        )
        
        do {
            let data = try JSONEncoder().encode(update)
            let message = URLSessionWebSocketTask.Message.data(data)
            
            webSocketTask.send(message) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.connectionError = error
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.connectionError = error
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func listenForMessages() {
        guard let webSocketTask = webSocketTask else { return }
        
        webSocketTask.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleWebSocketMessage(message)
                // Continue listening for more messages
                self?.listenForMessages()
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.connectionError = error
                    self?.isConnected = false
                }
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            handleLocationUpdate(data)
        case .string(let string):
            if let data = string.data(using: .utf8) {
                handleLocationUpdate(data)
            }
        @unknown default:
            break
        }
    }
    
    private func handleLocationUpdate(_ data: Data) {
        do {
            let update = try JSONDecoder().decode(DogLocationUpdate.self, from: data)
            
            DispatchQueue.main.async {
                // Update or add the dog location
                if let index = self.nearbyDogs.firstIndex(where: { $0.id == update.id }) {
                    // Update existing dog's location
                    var updatedDog = self.nearbyDogs[index]
                    updatedDog = Dog(
                        id: updatedDog.id,
                        name: updatedDog.name,
                        breed: updatedDog.breed,
                        age: updatedDog.age,
                        interests: updatedDog.interests,
                        aboutMe: updatedDog.aboutMe,
                        photos: updatedDog.photos,
                        location: update.location,
                        ownerId: updatedDog.ownerId,
                        ownerName: updatedDog.ownerName,
                        isOnline: true,
                        updatedAt: Date.now,
                        createdAt: Date.now
                    )
                    self.nearbyDogs[index] = updatedDog
                } else if update.isOnline {
                    // Add new online dog - fetch full details if needed
                    // For now, we'll skip adding until we have full dog data
                    print("New dog detected: \(update.id)")
                }
                
                // Remove offline dogs
                self.nearbyDogs = self.nearbyDogs.filter { dog in
                    // Keep dogs that are still online based on recent updates
                    return update.isOnline || dog.id != update.id
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.connectionError = error
            }
        }
    }
}

// MARK: - Helper Types
struct EmptyResponse: Codable {
    // Empty response for endpoints that don't return data
}

// MARK: - Extensions
extension DogLocationService {
    /// Convenience method to convert DogLocationUpdate to Dog model
    func convertToDog(_ locationUpdate: DogLocationUpdate) -> Dog? {
        // This would require fetching additional dog details from your Dog model
        // For now, we return nil since we need more than just location data
        return nil
    }
    
    /// Get distance between two coordinates
    func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) / 1000.0 // Convert to kilometers
    }
    
    /// Fetch dogs for a specific region (convenience method)
//    func fetchDogsInRegion(center: CLLocationCoordinate2D, span: MKCoordinateSpan) async throws -> [Dog] {
//        let request = NearbyDogsRequest(
//            northEastLat: center.latitude + span.latitudeDelta / 2,
//            northEastLon: center.longitude + span.longitudeDelta / 2,
//            southWestLat: center.latitude - span.latitudeDelta / 2,
//            southWestLon: center.longitude - span.longitudeDelta / 2
//        )
//        
//        let response = try await fetchNearbyDogs(request: request)
//        return response.dogs
//    }
} 
