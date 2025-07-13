//// Example of how to use DogLocationService for real-time dog location updates
//// This file shows basic usage patterns - you can remove it once you're familiar with the API
//
//import SwiftUI
//import CoreLocation
//
//// Example usage in a SwiftUI view
//struct LocationServiceExampleView: View {
//    @StateObject private var locationService = DogLocationService.shared
//    @EnvironmentObject private var locationManager: LocationManager
//    @State private var userDogId = UUID() // Replace with actual dog ID
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            // Connection status
//            HStack {
//                Circle()
//                    .fill(locationService.isConnected ? Color.green : Color.red)
//                    .frame(width: 10, height: 10)
//                Text(locationService.isConnected ? "Connected" : "Disconnected")
//            }
//            
//            // Nearby dogs count
//            Text("Nearby Dogs: \(locationService.nearbyDogs.count)")
//                .font(.headline)
//            
//            // List of nearby dogs
//            List(locationService.nearbyDogs, id: \.dogId) { dogLocation in
//                VStack(alignment: .leading) {
//                    Text("Dog ID: \(dogLocation.dogId)")
//                        .font(.caption)
//                    Text("Location: \(dogLocation.latitude, specifier: "%.4f"), \(dogLocation.longitude, specifier: "%.4f")")
//                        .font(.caption2)
//                    Text("Updated: \(dogLocation.timestamp, style: .time)")
//                        .font(.caption2)
//                        .foregroundColor(.secondary)
//                }
//            }
//            
//            // Control buttons
//            HStack {
//                Button("Start Tracking") {
//                    startRealTimeTracking()
//                }
//                .disabled(locationService.isConnected)
//                
//                Button("Stop Tracking") {
//                    locationService.stopRealTimeUpdates()
//                }
//                .disabled(!locationService.isConnected)
//            }
//            
//            // Manual location update
//            Button("Update My Location") {
//                updateMyLocation()
//            }
//            .disabled(!locationService.isConnected)
//            
//            // Error display
//            if let error = locationService.connectionError {
//                Text("Error: \(error.localizedDescription)")
//                    .foregroundColor(.red)
//                    .font(.caption)
//            }
//        }
//        .padding()
//        .onAppear {
//            startRealTimeTracking()
//        }
//        .onDisappear {
//            locationService.stopRealTimeUpdates()
//        }
//    }
//    
//    private func startRealTimeTracking() {
//        guard let userLocation = locationManager.userLocation else {
//            print("User location not available")
//            return
//        }
//        
//        locationService.startRealTimeUpdates(
//            userLocation: userLocation.coordinate,
//            radius: 5.0 // 5km radius
//        )
//    }
//    
//    private func updateMyLocation() {
//        guard let userLocation = locationManager.userLocation else {
//            print("User location not available")
//            return
//        }
//        
//        locationService.sendLocationUpdate(
//            dogId: userDogId,
//            location: userLocation.coordinate
//        )
//    }
//}
//
//// Example usage in a ViewModel
//class ExampleViewModel: ObservableObject {
//    private let locationService = DogLocationService.shared
//    private let dogProfileService = DogProfileService.shared
//    
//    @Published var nearbyDogs: [Dog] = []
//    @Published var isLoading = false
//    @Published var error: Error?
//    
//    func fetchNearbyDogs(userLocation: CLLocationCoordinate2D) {
//        isLoading = true
//        Task {
//            do {
//                // Fetch nearby dogs using the REST API
//                let dogs = try await locationService.fetchNearbyDogs(
//                    userLocation: userLocation,
//                    radius: 5.0
//                )
//                
//                await MainActor.run {
//                    self.nearbyDogs = dogs
//                    self.isLoading = false
//                }
//            } catch {
//                await MainActor.run {
//                    self.error = error
//                    self.isLoading = false
//                }
//            }
//        }
//    }
//    
//    func startRealTimeUpdates(userLocation: CLLocationCoordinate2D) {
//        locationService.startRealTimeUpdates(
//            userLocation: userLocation,
//            radius: 5.0
//        )
//    }
//    
//    func stopRealTimeUpdates() {
//        locationService.stopRealTimeUpdates()
//    }
//}
//
//#Preview {
//    LocationServiceExampleView()
//        .environmentObject(LocationManager())
//} 
