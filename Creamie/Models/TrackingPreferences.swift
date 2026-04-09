import Foundation
import CoreLocation

/// Model for persisting location tracking preferences for individual dogs
struct TrackingPreferences: Codable {
    let dogId: UUID
    let isEnabled: Bool
    let lastKnownLocation: CLLocationCoordinate2D?
    let lastUpdateTime: Date?
    
    enum CodingKeys: String, CodingKey {
        case dogId
        case isEnabled
        case lastKnownLatitude
        case lastKnownLongitude
        case lastUpdateTime
    }
    
    init(dogId: UUID, isEnabled: Bool, lastKnownLocation: CLLocationCoordinate2D? = nil, lastUpdateTime: Date? = nil) {
        self.dogId = dogId
        self.isEnabled = isEnabled
        self.lastKnownLocation = lastKnownLocation
        self.lastUpdateTime = lastUpdateTime
    }
    
    // Custom encoding to handle CLLocationCoordinate2D
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dogId, forKey: .dogId)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encodeIfPresent(lastKnownLocation?.latitude, forKey: .lastKnownLatitude)
        try container.encodeIfPresent(lastKnownLocation?.longitude, forKey: .lastKnownLongitude)
        try container.encodeIfPresent(lastUpdateTime, forKey: .lastUpdateTime)
    }
    
    // Custom decoding to handle CLLocationCoordinate2D
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dogId = try container.decode(UUID.self, forKey: .dogId)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        lastUpdateTime = try container.decodeIfPresent(Date.self, forKey: .lastUpdateTime)
        
        if let latitude = try container.decodeIfPresent(Double.self, forKey: .lastKnownLatitude),
           let longitude = try container.decodeIfPresent(Double.self, forKey: .lastKnownLongitude) {
            lastKnownLocation = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            lastKnownLocation = nil
        }
    }
}
