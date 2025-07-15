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
    var id: UUID
    var name: String
    var breed: DogBreed
    var age: Int
    var interests: [String]?
    var aboutMe: String?
    var photos: [String]
    var location: Location
    var ownerId: UUID
    var ownerName: String?
    var isOnline: Bool
    var updatedAt: Date?
    var createdAt: Date?
    
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
            location: Location,
            ownerId: UUID,
            ownerName: String? = nil,
            isOnline: Bool,
            updatedAt: Date,
            createdAt: Date? = nil,
        ) {
            self.id = id
            self.name = name
            self.breed = breed
            self.age = age
            self.interests = interests
            self.location = location
            self.photos = photos
            self.aboutMe = aboutMe
            self.ownerId = ownerId
            self.ownerName = ownerName
            self.isOnline = isOnline
            self.updatedAt = updatedAt
            self.createdAt = createdAt
        }
}

//// MARK: - Sample Data
//// TODO: Grab it from backend DB
//extension Dog {
//    static var sampleDogs: [Dog] {
//        [
//            Dog(id: UUID(), name: "Max", breed: .labrador, age: 3,
//                interests: ["Swimming", "Tennis Balls", "Hiking"],
//                location: Location(latitude: 37.7859, longitude: -122.4006),
//                photos: ["dog_Max"],
//                ownerId: "123456",
//                ownerName: "Sarah Johnson"),
//                isOnline: true
//            
//            
//            Dog(id: UUID(), name: "Creamie", breed: .cockapoo, age: 2,
//                interests: ["Running", "Snow", "Howling"],
//                location: Location(latitude: 37.7861, longitude: -122.4013),
//                photos: ["dog_Creamie", "dog_Creamie2"],
//                aboutMe: "I am Creamie!",
//                ownerId: "123456",
//                ownerName: "John Doe"),
//                isOnline: true
//            
//            Dog(id: UUID(), name: "Bella", breed: .goldenRetriever, age: 4,
//                location: Location(latitude: 37.9861, longitude: -122.4020),
//                photos: ["dog_Sample"],
//                ownerId: "123456",
//                ownerName: "Emily Chen"),
//                isOnline: true
////
////            Dog(id: UUID(), name: "Charlie", breed: .frenchBulldog, age: 1,
////                interests: ["Naps", "Treats", "Short Walks"],
////                location: CLLocationCoordinate2D(latitude: 34.0505, longitude: -118.2428),
////                photos: ["dog_frenchie"]),
////
////            Dog(id: UUID(), name: "Daisy", breed: .corgi, age: 2,
////                interests: ["Belly Rubs", "Agility", "Herding"],
////                location: CLLocationCoordinate2D(latitude: 34.0555, longitude: -118.2420),
////                photos: ["dog_corgi"])
//        ]
//    }
//}

