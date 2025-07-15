import SwiftUI
import MapKit

// Custom enum that conforms to Hashable
enum MapStyleOption: String, Hashable, CaseIterable {
    case standard
    case hybrid
    case satellite
    
    var mapStyle: MapStyle {
        switch self {
        case .standard:
            return .standard
        case .hybrid:
            return .hybrid
        case .satellite:
            return .imagery
        }
    }
}

struct FullScreenMapView: View {
    let dog: Dog
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition
    @State private var mapStyleOption: MapStyleOption = .standard
    
    init(dog: Dog) {
        self.dog = dog
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: dog.latitude, longitude: dog.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $cameraPosition, selection: .constant(nil), scope: nil) {
                Annotation(dog.name, coordinate: CLLocationCoordinate2D(latitude: dog.latitude, longitude: dog.longitude)) {
                    Image(systemName: "pawprint.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                        .background(Circle().fill(Color.white).shadow(radius: 2))
                }
            }
            .mapStyle(mapStyleOption.mapStyle)
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.3)))
                    }
                    
                    Spacer()
                    
                    Picker("Map Style", selection: $mapStyleOption) {
                        Text("Standard").tag(MapStyleOption.standard)
                        Text("Hybrid").tag(MapStyleOption.hybrid)
                        Text("Satellite").tag(MapStyleOption.satellite)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.8)))
                    .padding()
                }
                
                Spacer()
                
                Button(action: {
                    // Open in Maps app
                    let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: dog.latitude, longitude: dog.longitude)))
                    mapItem.name = "\(dog.name)'s Location"
                    mapItem.openInMaps(launchOptions: nil)
                }) {
                    HStack {
                        Image(systemName: "map.fill")
                        Text("Open in Maps")
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                    .foregroundColor(.blue)
                    .shadow(radius: 2)
                }
                .padding(.bottom, 40)
            }
            .padding()
        }
    }
} 
