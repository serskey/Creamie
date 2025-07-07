import Foundation
import CoreLocation
import SwiftUI

struct Dog: Identifiable, Hashable {
    let id: UUID
    let name: String
    let breed: DogBreed
    let age: Int
    let interests: [String]
    let location: CLLocationCoordinate2D
    let photo: String  // Name of the image asset
    
    static func == (lhs: Dog, rhs: Dog) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Sample Data
// TODO: Grab it from backend DB
extension Dog {
    static var sampleDogs: [Dog] {
        [
            Dog(id: UUID(), name: "Max", breed: .labrador, age: 3, 
                interests: ["Swimming", "Tennis Balls", "Hiking"],
                location: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
                photo: "dog_Max"),
            
            Dog(id: UUID(), name: "Creamie", breed: .cockapoo, age: 2,
                interests: ["Running", "Snow", "Howling"],
                location: CLLocationCoordinate2D(latitude: 34.0548, longitude: -118.2453),
                photo: "dog_Creamie"),
            
//            Dog(id: UUID(), name: "Bella", breed: .goldenRetriever, age: 4,
//                interests: ["Frisbee", "Beach", "Cuddles"],
//                location: CLLocationCoordinate2D(latitude: 34.0530, longitude: -118.2490),
//                photo: "dog_golden"),
//            
//            Dog(id: UUID(), name: "Charlie", breed: .frenchBulldog, age: 1,
//                interests: ["Naps", "Treats", "Short Walks"],
//                location: CLLocationCoordinate2D(latitude: 34.0505, longitude: -118.2428),
//                photo: "dog_frenchie"),
//            
//            Dog(id: UUID(), name: "Daisy", breed: .corgi, age: 2,
//                interests: ["Belly Rubs", "Agility", "Herding"],
//                location: CLLocationCoordinate2D(latitude: 34.0555, longitude: -118.2420),
//                photo: "dog_corgi")
        ]
    }
} 
