import SwiftUI
import MapKit

struct MapView: View {
    // Binding to track current tab selection
    @Binding var selectedTab: Int
    @Binding var selectedChatId: UUID?
    
    @EnvironmentObject private var locationManager: LocationManager
    @State private var position: MapCameraPosition = .automatic
    @State private var searchText = ""
    @State private var selectedDog: Dog?
    @State private var showingFilters = false
    @State private var selectedBreeds: Set<DogBreed> = Set(DogBreed.popularBreeds)
    @State private var locationSearchResults: [MKMapItem] = []
    @State private var route: MKRoute?
    @State private var isTrackingUserLocation = true
    

    // Filters the dogs from sample dog pool based on the selected breeds
    var filteredDogs: [Dog] {
        Dog.sampleDogs.filter { selectedBreeds.contains($0.breed) }
    }
    
    var body: some View {
        ZStack {
                // Show map only if we have permission
                if locationManager.authorizationStatus == .authorizedWhenInUse ||
                   locationManager.authorizationStatus == .authorizedAlways {
                    Map(position: $position, selection: $selectedDog) {
                        // Shows user's current location
                        if let userLocation = locationManager.userLocation {
                            Annotation("You", coordinate: userLocation.coordinate) {
                                UserLocationMarker()
                            }
                        }
                        
                        ForEach(filteredDogs) { dog in
                            Annotation(dog.name, coordinate: dog.location) {
                                DogMarker(dog: dog)
                            }
                            .tag(dog)
                        }
                        
                        if let route {
                            MapPolyline(route)
                                .stroke(.blue, lineWidth: 3)
                        }
                    }
                    .mapStyle(.standard)
                    .mapControlVisibility(.hidden)
                    .onAppear {
                        // Set position to user location when map appears
                        position = .userLocation(fallback: .automatic)
                        isTrackingUserLocation = true
                    }
                    .gesture(
                        // Detect when user manually interacts with map
                        DragGesture(minimumDistance: 3)
                            .onChanged { _ in
                                isTrackingUserLocation = false
                            }
                    )
                } else if locationManager.authorizationStatus == .notDetermined {
                    // Waiting for user to grant permission
                    VStack(spacing: 20) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Location Access Required")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Creamie needs your location to show dogs near you")
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button("Enable Location Access") {
                            locationManager.requestPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    // Permission denied
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
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                
                VStack {
                    // search bar, filter button, and location button on the top
                    HStack {
                        searchAndFilterBar
                        
                        Spacer()
                        
                        if locationManager.authorizationStatus == .authorizedWhenInUse ||
                           locationManager.authorizationStatus == .authorizedAlways {
                            // My Location Button in the top right corner
                            CircularButton(
                                icon: "location.fill",
                                size: 50,
                                isSelected: isTrackingUserLocation,
                                action: {
                                    withAnimation {
                                        position = .userLocation(fallback: .automatic)
                                        isTrackingUserLocation = true
                                    }
                                }
                            )
                            .padding(.trailing, 16)
                        }
                    }
                    
                    Spacer()
                }
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
    }
    
    private var searchAndFilterBar: some View {
        HStack {
            // Search Location
            HStack {
                Image("magnifyingglass")
                
                TextField("Search location", text: $searchText)
                    .autocorrectionDisabled()
                    .foregroundStyle(.primary)
            }
            .padding(8)
            .background{Color.clear}
            .glassEffect(.clear.tint(Color.clear).interactive())
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            CircularButton(
                icon: "line.3.horizontal.decrease.circle.fill",
                size: 50,
                isSelected: showingFilters,
                action: { showingFilters.toggle() }
            )

        }
        .padding(.leading, 16)
    }
    
    private func calculateRoute(to coordinate: CLLocationCoordinate2D) {
        // Implementation for calculating route
        // This would use MKDirections to get route from user location to dog
    }
}
