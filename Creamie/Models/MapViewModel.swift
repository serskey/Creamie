//
//  MapViewModel.swift
//  Creamie
//
//  Created by Siqi Xu on 7/16/25.
//

import MapKit
import CoreLocation

@MainActor
class MapViewModel: ObservableObject {
    @Published var nearbyDogs: [Dog] = []
    
    private let locationService = DogLocationService.shared
    private var lastFetchedRegion: MKCoordinateRegion?
    private var currentVisibleRegion: MKCoordinateRegion?
    private var fetchTimer: Timer?
    
    private(set) var isInitialLoad = true
    
    // MARK: - Constants
    private enum Constants {
        static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        static let fetchThresholdDistance: Double = 1000 // meters
        static let fetchThresholdSpan: Double = 0.01
        static let debounceDelay: TimeInterval = 0.5
    }
    
    func setInitialRegion(center: CLLocationCoordinate2D) {
        currentVisibleRegion = MKCoordinateRegion(center: center, span: Constants.defaultSpan)
    }
    
    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        currentVisibleRegion = region
    }
    
    func fetchNearbyDogs() {
        guard let region = getCurrentVisibleRegion(),
              shouldFetchForRegion(region) else { return }
        
        let boundingBox = createBoundingBox(from: region)
        
        Task {
            do {
                let response = try await locationService.fetchNearbyDogs(request: boundingBox)
                
                await MainActor.run {
                    self.nearbyDogs = response.dogs
                    self.lastFetchedRegion = region
                    self.isInitialLoad = false
                }
            } catch {
                await MainActor.run {
                    // TODO: Print out error
                    print("Failed to fetch dogs")
                    self.nearbyDogs = []
                }
            }
        }
    }
    
    func debouncedFetchDogs() {
        fetchTimer?.invalidate()
        fetchTimer = Timer.scheduledTimer(withTimeInterval: Constants.debounceDelay, repeats: false) { _ in
            Task { @MainActor in
                self.fetchNearbyDogs()
            }
        }
    }
    
    deinit {
        fetchTimer?.invalidate()
    }
}

// MARK: - MapViewModel Private Methods
private extension MapViewModel {
    func getCurrentVisibleRegion() -> MKCoordinateRegion? {
        return currentVisibleRegion
    }
    
    func shouldFetchForRegion(_ region: MKCoordinateRegion) -> Bool {
        guard !isInitialLoad else { return true }
        guard let lastRegion = lastFetchedRegion else { return true }
        
        let distance = distanceBetweenRegions(region, lastRegion)
        let spanDifference = abs(region.span.latitudeDelta - lastRegion.span.latitudeDelta)
        
        return distance > Constants.fetchThresholdDistance || spanDifference > Constants.fetchThresholdSpan
    }
    
    func createBoundingBox(from region: MKCoordinateRegion) -> NearbyDogsRequest {
        let center = region.center
        let span = region.span
        
        return NearbyDogsRequest(
            northEastLat: center.latitude + span.latitudeDelta / 2,
            northEastLon: center.longitude + span.longitudeDelta / 2,
            southWestLat: center.latitude - span.latitudeDelta / 2,
            southWestLon: center.longitude - span.longitudeDelta / 2
        )
    }
    
    func distanceBetweenRegions(_ region1: MKCoordinateRegion, _ region2: MKCoordinateRegion) -> Double {
        let location1 = CLLocation(latitude: region1.center.latitude, longitude: region1.center.longitude)
        let location2 = CLLocation(latitude: region2.center.latitude, longitude: region2.center.longitude)
        return location1.distance(from: location2)
    }
}
