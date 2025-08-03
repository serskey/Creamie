//
//  DogHealthcareService.swift
//  Creamie
//
//  Created by Siqi Xu on 2025/8/1.
//

import Foundation

class DogHealthcareService: ObservableObject {
    static let shared = DogHealthcareService()
    
    private let apiService = APIService.shared
    
    func fetchHealthData(request: GetDogHealthRequest) async throws -> GetDogHealthResponse {
        print("🔍 Fetching health data of dog \(request.dogId) from backend...")
        let response = try await apiService.request(
            endpoint: "/dogs/health",
            method: .POST,
            body: request,
            responseType: GetDogHealthResponse.self
        )
        
        print("🐾 Fetched health data for dog \(response.dogId) from backend")
        return response
    }
    
    func saveHealthData(request: SaveDogHealthRequest) async throws -> SaveDogHealthResponse {
        print("💾 Saving health data for dog \(request.dogId) to backend...")
        let response = try await apiService.request(
            endpoint: "/dogs/health/save",
            method: .POST,
            body: request,
            responseType: SaveDogHealthResponse.self
        )
        
        print("✅ Saved health data for dog \(response.dogId) to backend")
        return response
    }
}
