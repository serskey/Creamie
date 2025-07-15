//
//  UserModel.swift
//  Creamie
//
//  Created by Siqi Xu on 7/13/25.
//
import Foundation

struct User: Codable, Identifiable {
    var id: String
    var displayName: String
    var email: String
    var photoUrl: String
    var createdAt: Date
}

