import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    // MARK: - Bindings
    @Binding var selectedTab: Int
    @Binding var selectedChatId: UUID?
    
    // MARK: - Environment & Services
    @EnvironmentObject private var locationManager: LocationManager
    @StateObject private var viewModel = MapViewModel()
    
    // MARK: - UI State
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedDog: Dog?
    @State private var showingFilters = false
    @State private var selectedBreeds: Set<DogBreed> = Set(DogBreed.popularBreeds)
    @State private var isTrackingUserLocation = true
    @State private var searchText = ""
    @State private var isSemanticSearchActive = false
    
    // MARK: - Computed Properties
    private var hasLocationPermission: Bool {
        locationManager.authorizationStatus == .authorizedWhenInUse ||
        locationManager.authorizationStatus == .authorizedAlways
    }

    private var filteredDogs: [Dog] {
        let dogsToFilter = viewModel.displayedDogs
        
        return dogsToFilter.filter { dog in
            let matchesBreed = selectedBreeds.contains(dog.breed)
            let matchesSearch = searchText.isEmpty || isSemanticSearchActive ||
                               dog.name.lowercased().contains(searchText.lowercased()) ||
                               dog.breed.rawValue.lowercased().contains(searchText.lowercased())
            return matchesBreed && matchesSearch
        }
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            mapContent
            if hasLocationPermission {
                mapOverlay
            }
            
            // Search loading indicator
            if viewModel.isSearching {
                searchLoadingOverlay
            }
        }
        .sheet(isPresented: $showingFilters) {
            FilterView(selectedBreeds: $selectedBreeds)
                .presentationDetents([.medium])
        }
        .sheet(item: $selectedDog) { dog in
            MapDogProfileView(selectedDog: dog,
                              selectedTab: $selectedTab,
                              selectedChatId: $selectedChatId)
            .presentationDetents([.medium])
            .presentationBackgroundInteraction(.enabled)
        }
        .onAppear {
            setupInitialState()
        }
        .onChange(of: locationManager.userLocation) { _, newLocation in
            handleLocationChange(newLocation)
        }
        .onChange(of: searchText) { _, newValue in
            handleSearchTextChange(newValue)
        }
        .alert("Search Error", isPresented: .constant(viewModel.searchError != nil)) {
            Button("OK") {
                viewModel.searchError = nil
            }
        } message: {
            if let error = viewModel.searchError {
                Text(error)
            }
        }
    }
}

// MARK: - Map Content
private extension MapView {
    @ViewBuilder
    var mapContent: some View {
        if hasLocationPermission {
            mapWithAnnotations
        } else if locationManager.authorizationStatus == .notDetermined {
            LocationPermissionRequestView()
        } else {
            LocationPermissionDeniedView()
        }
    }
    
    var mapWithAnnotations: some View {
        Map(position: $position, selection: $selectedDog) {
            // User location marker
            if let userLocation = locationManager.userLocation {
                Annotation("You", coordinate: userLocation.coordinate) {
                    UserLocationMarker()
                }
            }
            
            // Dog markers
            ForEach(filteredDogs) { dog in
                Annotation(dog.name, coordinate: CLLocationCoordinate2D(latitude: dog.latitude, longitude: dog.longitude)) {
                    DogMarker(dog: dog)
                }
                .tag(dog)
            }
        }
        .mapStyle(.standard)
        .mapControlVisibility(.hidden)
        .onMapCameraChange { context in
            handleCameraChange(context)
        }
        .gesture(mapInteractionGesture)
    }
    
    var mapInteractionGesture: some Gesture {
        DragGesture()
            .onChanged { _ in
                isTrackingUserLocation = false
            }
            .onEnded { _ in
                if !isSemanticSearchActive {
                    viewModel.debouncedFetchDogs()
                }
            }
            .simultaneously(with:
                MagnificationGesture()
                    .onChanged { _ in
                        isTrackingUserLocation = false
                    }
                    .onEnded { _ in
                        if !isSemanticSearchActive {
                            viewModel.debouncedFetchDogs()
                        }
                    }
            )
    }
    
    var searchLoadingOverlay: some View {
        VStack {
            Spacer()
            HStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                Text("Searching...")
                    .foregroundColor(Color.pink)
                    .font(.default)
                    .fontWeight(.bold)
            }
            .padding(30)
            .glassEffect(.clear.interactive().tint(Color.purple.opacity(0.5)))
            .cornerRadius(15)
            Spacer()
        }
    }

}

// MARK: - Map Overlay
private extension MapView {
    var mapOverlay: some View {
        VStack {
            topControls
            Spacer()
        }
    }
    
    var topControls: some View {
        HStack {
            searchAndFilterBar
            
            Spacer()
            
            myLocationButton
        }
    }
    
    var searchAndFilterBar: some View {
        HStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.purple)
                
                TextField("Search dogs...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .onSubmit {
                        performSearch()
                    }
                
                // Search/Clear button
                if !searchText.isEmpty {
                    if !isSemanticSearchActive {
                        // Search button - only show when not actively searching
                        Button(action: {
                            performSearch()
                        }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(Color.pink)
                                .font(.system(size: 16))
                        }
                    } else {
                        // Clear button - show when search is active
                        Button(action: {
                            clearSearch()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.pink)
                                .font(.system(size: 16))
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.clear)
            .glassEffect(.clear.tint(Color.clear).interactive())
            .cornerRadius(25)
            
            // Filter Button
            filterButton
        }
        .padding(.leading, 16)
    }
    
    var filterButton: some View {
        CircularButton(
            icon: "line.3.horizontal.decrease.circle.fill",
            size: 50,
            isSelected: showingFilters,
            action: { showingFilters.toggle() }
        )
    }
    
    var myLocationButton: some View {
        CircularButton(
            icon: "location.fill",
            size: 50,
            isSelected: isTrackingUserLocation,
            action: centerOnUserLocation
        )
        .padding(.trailing, 16)
    }
}

// MARK: - Actions
private extension MapView {
    func setupInitialState() {
        guard let userLocation = locationManager.userLocation else { return }
        
        position = .userLocation(fallback: .automatic)
        isTrackingUserLocation = true
        viewModel.setInitialRegion(center: userLocation.coordinate)
        viewModel.fetchNearbyDogs()
    }
    
    func handleLocationChange(_ newLocation: CLLocation?) {
        guard let _ = newLocation,
              viewModel.isInitialLoad else { return }
        
        viewModel.fetchNearbyDogs()
    }
    
    func handleCameraChange(_ context: MapCameraUpdateContext) {
        viewModel.updateVisibleRegion(context.region)
        
        // Check if user has moved away from their location
        if isTrackingUserLocation {
            if let userLocation = locationManager.userLocation {
                let userCoordinate = userLocation.coordinate
                let currentCenter = context.region.center
                
                // Calculate distance between current center and user location
                let distance = CLLocation(latitude: currentCenter.latitude, longitude: currentCenter.longitude)
                    .distance(from: CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude))
                
                // If moved more than 100 meters away, stop tracking
                if distance > 100 {
                    isTrackingUserLocation = false
                }
            }
        }
        
        if !isTrackingUserLocation {
            position = .region(context.region)
        }
        
        // Only fetch new dogs if not actively searching
        if !isSemanticSearchActive {
            viewModel.debouncedFetchDogs()
        }
    }
    
    func centerOnUserLocation() {
        withAnimation {
            position = .userLocation(fallback: .automatic)
            isTrackingUserLocation = true
        }
        
//        // clear sermatic search when back to my location
//        if isSearchActive {
//            clearSearch()
//        }
    }
    
    func handleSearchTextChange(_ newValue: String) {
        // Only clear search if text becomes empty
        if newValue.isEmpty {
            clearSearch()
        }
    }
    
    func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearSearch()
            return
        }
        
        isSemanticSearchActive = true
        viewModel.searchDogs(query: searchText, userLocation: locationManager.userLocation)
    }
    
    func clearSearch() {
        searchText = ""
        isSemanticSearchActive = false
        viewModel.clearSearch()
        
        // Return to showing nearby dogs
        if hasLocationPermission {
            viewModel.fetchNearbyDogs()
        }
    }
}

// MARK: - Location Permission Views
struct LocationPermissionRequestView: View {
    @EnvironmentObject private var locationManager: LocationManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.circle")
                .font(.system(size: 60))
                .foregroundColor(Color.purple)
            
            Text("Location Access Required")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Creamie needs your location to show dogs near you")
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Enable Location Access") {
                locationManager.requestPermission()
            }
            .buttonStyle(.glassProminent)
            .tint(.purple)

        }
        .padding()
    }
}

struct LocationPermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Location Access Denied")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Please enable location access in Settings to see nearby dogs.")
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.glassProminent)
            .tint(.purple)
        }
        .padding()
    }
}
