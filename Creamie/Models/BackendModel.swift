//
//  Untitled.swift
//  Creamie
//
//  Created by Siqi Xu on 7/15/25.
//

import Foundation

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
