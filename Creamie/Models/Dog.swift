import Foundation
import CoreLocation
import SwiftUI

struct Location: Codable, Hashable {
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct Dog: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let breed: DogBreed
    let age: Int
    let interests: [String]?
    let location: Location
    let photos: [String]  // Names of the image assets or saved photos
    let aboutMe: String?
    let ownerName: String?  // Name of the dog's owner
    
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
            location: Location,
            photos: [String],
            aboutMe: String? = nil,
            ownerName: String? = nil
        ) {
            self.id = id
            self.name = name
            self.breed = breed
            self.age = age
            self.interests = interests
            self.location = location
            self.photos = photos
            self.aboutMe = aboutMe
            self.ownerName = ownerName
        }
}

// MARK: - Sample Data
// TODO: Grab it from backend DB
extension Dog {
    static var sampleDogs: [Dog] {
        [
            Dog(id: UUID(), name: "Max", breed: .labrador, age: 3, 
                interests: ["Swimming", "Tennis Balls", "Hiking"],
                location: Location(latitude: 37.7859, longitude: -122.4006),
                photos: ["dog_Max"],
                ownerName: "Sarah Johnson"),
            
            Dog(id: UUID(), name: "Creamie", breed: .cockapoo, age: 2,
                interests: ["Running", "Snow", "Howling"],
                location: Location(latitude: 37.7861, longitude: -122.4013),
                photos: ["dog_Creamie", "dog_Creamie2"],
                aboutMe: "I am Creamie!",
                ownerName: "John Doe"),
            
            Dog(id: UUID(), name: "Bella", breed: .goldenRetriever, age: 4,
                location: Location(latitude: 37.9861, longitude: -122.4020),
                photos: ["dog_Sample"],
                ownerName: "Emily Chen"),
//
//            Dog(id: UUID(), name: "Charlie", breed: .frenchBulldog, age: 1,
//                interests: ["Naps", "Treats", "Short Walks"],
//                location: CLLocationCoordinate2D(latitude: 34.0505, longitude: -118.2428),
//                photos: ["dog_frenchie"]),
//            
//            Dog(id: UUID(), name: "Daisy", breed: .corgi, age: 2,
//                interests: ["Belly Rubs", "Agility", "Herding"],
//                location: CLLocationCoordinate2D(latitude: 34.0555, longitude: -118.2420),
//                photos: ["dog_corgi"])
        ]
    }
} 
