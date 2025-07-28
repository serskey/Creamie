//
//  Untitled.swift
//  Creamie
//
//  Created by Siqi Xu on 7/15/25.
//

import Foundation

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

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct SignUpRequest: Codable {
    let email: String
    let password: String
    let name: String
    let phoneNumber: String
}

struct UpdateProfileRequest: Codable {
    let name: String
    let phoneNumber: String
    let photos: [String]?
}

struct AuthResponse: Codable {
    let success: Bool
    let message: String?
    let user: User?
    let token: String?
}
