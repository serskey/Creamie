import Foundation
import SwiftUI

@MainActor
class DogProfileViewModel: ObservableObject {
    @Published var dogs: [Dog] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showingAddDog = false
    
    func fetchDogs() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // TODO: Replace with actual API call
            // Simulating network delay
            try await Task.sleep(nanoseconds: 1_000_000_000)
            dogs = Dog.sampleDogs
        } catch {
            self.error = error
        }
    }
    
    func refreshDogs() {
        Task {
            await fetchDogs()
        }
    }
}
