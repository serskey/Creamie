//
//  Untitled.swift
//  Creamie
//
//  Created by Siqi Xu on 7/15/25.
//

import Foundation

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
