import SwiftUI
import MapKit

struct MapView: View {
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var searchText = ""
    @State private var selectedDog: Dog?
    @State private var showingFilters = false
    @State private var selectedBreeds: Set<DogBreed> = Set(DogBreed.popularBreeds)
    @State private var searchResults: [MKMapItem] = []
    @State private var route: MKRoute?
    @State private var showingCard = false
    
    var filteredDogs: [Dog] {
        Dog.sampleDogs.filter { selectedBreeds.contains($0.breed) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $position, selection: $selectedDog) {
                    UserAnnotation()
                    
                    ForEach(filteredDogs) { dog in
                        Annotation(dog.name, coordinate: dog.location) {
                            DogMarker(dog: dog, isSelected: selectedDog?.id == dog.id)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedDog = dog
                                        showingCard = true
                                    }
                                }
                        }
                    }
                    
                    if let route {
                        MapPolyline(route)
                            .stroke(.blue, lineWidth: 3)
                    }
                }
                .mapStyle(.standard)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                
                VStack {
                    searchAndFilterBar
                    
                    Spacer()
                    
                    if let selected = selectedDog, showingCard {
                        DogPreviewCard(
                            dog: selected,
                            onGetDirections: {
                                calculateRoute(to: selected.location)
                            },
                            onClose: {
                                withAnimation(.spring(response: 0.3)) {
                                    showingCard = false
                                    selectedDog = nil
                                }
                            }
                        )
                        .transition(.move(edge: .bottom))
                    }
                }
            }
            .navigationTitle("Nearby Dogs")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingFilters) {
                FilterView(selectedBreeds: $selectedBreeds)
                    .presentationDetents([.medium])
            }
        }
    }
    
    private var searchAndFilterBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search location", text: $searchText)
                    .autocorrectionDisabled()
            }
            .padding(8)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 2)
            
            Button(action: { showingFilters.toggle() }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(.white)
                    .clipShape(Circle())
                    .shadow(radius: 2)
            }
        }
        .padding()
    }
    
    private func calculateRoute(to coordinate: CLLocationCoordinate2D) {
        // Implementation for calculating route
        // This would use MKDirections to get route from user location to dog
    }
} 