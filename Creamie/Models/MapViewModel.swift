import MapKit
import CoreLocation
import Combine

@MainActor
class MapViewModel: ObservableObject {
    @Published var nearbyDogs: [Dog] = []
    @Published var searchResults: [Dog] = []
    @Published var isSearching = false
    @Published var searchError: String?
    @Published var isRealTimeConnected = false
    
    private let locationService = DogLocationService.shared
    private let dogProfileService = DogProfileService.shared
    private var lastFetchedRegion: MKCoordinateRegion?
    private var currentVisibleRegion: MKCoordinateRegion?
    private var fetchTimer: Timer?
    private var searchTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private(set) var isInitialLoad = true
    
    // MARK: - Constants
    private enum Constants {
        static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        static let fetchThresholdDistance: Double = 1000 // meters
        static let fetchThresholdSpan: Double = 0.01
        static let debounceDelay: TimeInterval = 0.5
        static let searchDebounceDelay: TimeInterval = 0.3
        static let defaultSearchRadius: Double = 10.0 // km
    }
    
    // MARK: - Initialization
    
    init() {
        subscribeToRealTimeUpdates()
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
                    print("Failed to fetch dogs: \(error)")
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
    
    // MARK: - Search Functionality
    
    /// Search dogs with text input (searches both name and breed)
    func searchDogs(query: String, userLocation: CLLocation?) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearSearch()
            return
        }
        
        searchTimer?.invalidate()
        searchTimer = Timer.scheduledTimer(withTimeInterval: Constants.searchDebounceDelay, repeats: false) { _ in
            Task { @MainActor in
                await self.performSearch(query: query, userLocation: userLocation)
            }
        }
    }
    
    /// Search dogs by specific breed
    func searchDogsByBreed(_ breed: DogBreed) {
        Task {
            await MainActor.run {
                self.isSearching = true
                self.searchError = nil
            }
            
            do {
                let dogs = try await dogProfileService.getDogsByBreed(breed)
                
                await MainActor.run {
                    self.searchResults = dogs
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.searchError = "Failed to search by breed: \(error.localizedDescription)"
                    self.searchResults = []
                    self.isSearching = false
                }
            }
        }
    }
    
    /// Search nearby dogs within a specific radius
    func searchNearbyDogs(location: CLLocation, radius: Double = Constants.defaultSearchRadius) {
        Task {
            await MainActor.run {
                self.isSearching = true
                self.searchError = nil
            }
            
            do {
                let locationStruct = Location(latitude: location.coordinate.latitude,
                                           longitude: location.coordinate.longitude)
                let dogs = try await dogProfileService.getNearbyDogs(location: locationStruct, radius: radius)
                
                await MainActor.run {
                    self.searchResults = dogs
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.searchError = "Failed to search nearby dogs: \(error.localizedDescription)"
                    self.searchResults = []
                    self.isSearching = false
                }
            }
        }
    }
    
    /// Clear search results and return to map view
    func clearSearch() {
        searchTimer?.invalidate()
        searchResults = []
        searchError = nil
        isSearching = false
    }
    
    /// Get combined results (nearby dogs + search results for display)
    var displayedDogs: [Dog] {
        return searchResults.isEmpty ? nearbyDogs : searchResults
    }
    
    // MARK: - Real-time Location Updates
    
    /// Subscribe to real-time location updates from DogLocationService WebSocket
    private func subscribeToRealTimeUpdates() {
        // Observe nearbyDogs changes from DogLocationService (updated via WebSocket)
        locationService.$nearbyDogs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedDogs in
                self?.handleRealTimeLocationUpdates(updatedDogs)
            }
            .store(in: &cancellables)
        
        // Track WebSocket connection status
        locationService.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRealTimeConnected)
    }
    
    /// Start real-time WebSocket connection for the user's current location
    func startRealTimeUpdates(userLocation: CLLocationCoordinate2D, radius: Double = Constants.defaultSearchRadius) {
        locationService.startRealTimeUpdates(userLocation: userLocation, radius: radius)
    }
    
    /// Stop real-time WebSocket connection
    func stopRealTimeUpdates() {
        locationService.stopRealTimeUpdates()
    }
    
    /// Handle incoming real-time location updates from DogLocationService
    private func handleRealTimeLocationUpdates(_ updatedDogs: [Dog]) {
        // Merge real-time updates into the local nearbyDogs array
        for updatedDog in updatedDogs {
            if let index = nearbyDogs.firstIndex(where: { $0.id == updatedDog.id }) {
                if updatedDog.isOnline {
                    // Update existing dog's position and status
                    nearbyDogs[index] = updatedDog
                } else {
                    // Dog went offline — remove from map (Requirement 3.2)
                    nearbyDogs.remove(at: index)
                }
            } else if updatedDog.isOnline {
                // Dog came online — add marker at current location (Requirement 3.3)
                nearbyDogs.append(updatedDog)
            }
        }
        
        // Remove dogs that disappeared from the service's list entirely (went offline)
        let updatedDogIds = Set(updatedDogs.map { $0.id })
        if !updatedDogIds.isEmpty {
            nearbyDogs.removeAll { dog in
                !updatedDogIds.contains(dog.id) && !dog.isOnline
            }
        }
    }
    
    deinit {
        fetchTimer?.invalidate()
        searchTimer?.invalidate()
        cancellables.removeAll()
        locationService.stopRealTimeUpdates()
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
    
    func performSearch(query: String, userLocation: CLLocation?) async {
        await MainActor.run {
            self.isSearching = true
            self.searchError = nil
        }
        
        do {
            // Determine if query is likely a breed or a name
            let breeds = DogBreed.allCases
            let matchingBreed = breeds.first { breed in
                breed.rawValue.lowercased().contains(query.lowercased()) ||
                query.lowercased().contains(breed.rawValue.lowercased())
            }
            
            var location: Location? = nil
            if let userLoc = userLocation {
                location = Location(latitude: userLoc.coordinate.latitude,
                                  longitude: userLoc.coordinate.longitude)
            }
            
            // Search with both name and breed parameters
            let dogs = try await dogProfileService.searchDogs(
                query: query,
                breed: matchingBreed?.rawValue,
                location: location,
                radius: Constants.defaultSearchRadius
            )
            
            await MainActor.run {
                self.searchResults = dogs
                self.isSearching = false
            }
        } catch {
            await MainActor.run {
                self.searchError = "Search failed: \(error.localizedDescription)"
                self.searchResults = []
                self.isSearching = false
            }
        }
    }
}
