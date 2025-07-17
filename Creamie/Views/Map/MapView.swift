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
    
    // MARK: - Computed Properties
    private var hasLocationPermission: Bool {
        locationManager.authorizationStatus == .authorizedWhenInUse ||
        locationManager.authorizationStatus == .authorizedAlways
    }

    private var filteredDogs: [Dog] {
        viewModel.nearbyDogs.filter { dog in
            let matchesBreed = selectedBreeds.contains(dog.breed)
            let matchesSearch = searchText.isEmpty || 
                               dog.name.lowercased().contains(searchText.lowercased()) ||
                               dog.breed.rawValue.lowercased().contains(searchText.lowercased())
            return matchesBreed && matchesSearch
        }
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            mapContent
            mapOverlay
        }
        .sheet(isPresented: $showingFilters) {
            FilterView(selectedBreeds: $selectedBreeds)
                .presentationDetents([.medium])
        }
        .sheet(item: $selectedDog) { dog in
            MapDogProfileView(dog: dog, selectedTab: $selectedTab, selectedChatId: $selectedChatId)
                .presentationDetents([.medium])
                .presentationBackgroundInteraction(.enabled)
        }
        .onAppear {
            setupInitialState()
        }
        .onChange(of: locationManager.userLocation) { _, newLocation in
            handleLocationChange(newLocation)
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
                viewModel.debouncedFetchDogs()
            }
            .simultaneously(with:
                MagnificationGesture()
                            .onChanged { _ in
                                isTrackingUserLocation = false
                            }
                    .onEnded { _ in
                        viewModel.debouncedFetchDogs()
                    }
            )
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
            
            if hasLocationPermission {
                myLocationButton
            }
        }
    }
    
    var searchAndFilterBar: some View {
        HStack(spacing: 12) {
            // Search Bar
            HStack {
                Image("magnifyingglass")
                
                TextField("Search dogs...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            viewModel.fetchNearbyDogs()
        }
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
        
        viewModel.debouncedFetchDogs()
    }
    
    func centerOnUserLocation() {
        withAnimation {
            position = .userLocation(fallback: .automatic)
            isTrackingUserLocation = true
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

// TODO: remove searchFilterBar from the top
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
                // TODO: Go deeply to this specific app's location setting
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
