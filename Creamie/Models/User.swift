//
//  UserModel.swift
//  Creamie
//
//  Created by Siqi Xu on 7/13/25.
//
import Foundation


struct User: Codable, Identifiable {
    let id: UUID
    let name: String
    let email: String
    let phoneNumber: String?
    let photos: [String]?
    let createdAt: String
    let updatedAt: String
    
    var firstName: String {
        name.components(separatedBy: " ").first ?? name
    }
    
    var lastName: String {
        let components = name.components(separatedBy: " ")
        return components.count > 1 ? components.dropFirst().joined(separator: " ") : ""
    }
}
