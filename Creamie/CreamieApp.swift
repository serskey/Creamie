//
//  CreamieApp.swift
//  Creamie
//
//  Created by Siqi Xu on 7/6/25.
//

import SwiftUI
import CoreLocation
import Combine
import Supabase

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var userLocation: CLLocation?
    @Published var isLocationUpdating = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Get initial authorization status
        authorizationStatus = locationManager.authorizationStatus
        print("LocationManager init - Authorization status: \(authorizationStatus.rawValue)")
        
        // Check if Info.plist has required keys
        if let _ = Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") {
            print("✅ NSLocationWhenInUseUsageDescription is present in Info.plist")
        } else {
            print("❌ NSLocationWhenInUseUsageDescription is MISSING from Info.plist")
            print("⚠️ Location permission dialog will NOT appear without this key!")
        }
    }
    
    func requestPermission() {
        // Status meanings: 0=notDetermined, 1=restricted, 2=denied, 3=authorizedAlways, 4=authorizedWhenInUse
        print("📍 Requesting location permission...")
        print("Current authorization status before request: \(locationManager.authorizationStatus.rawValue)")
        
        // Check if we can request authorization
        if locationManager.authorizationStatus == .notDetermined {
            print("Status is notDetermined, requesting authorization...")
            locationManager.requestWhenInUseAuthorization()
        } else {
            print("Cannot request - status is already: \(locationManager.authorizationStatus.rawValue)")
        }
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("Cannot start location updates - not authorized")
            return
        }
        
        print("🔄 Starting location updates...")
        isLocationUpdating = true
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        print("🛑 Stopping location updates...")
        isLocationUpdating = false
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            print("🔄 Authorization status changed to: \(self.authorizationStatus.rawValue)")
            
            // Automatically start location updates when permission is granted
            if self.authorizationStatus == .authorizedWhenInUse || self.authorizationStatus == .authorizedAlways {
                self.startLocationUpdates()
            } else {
                self.stopLocationUpdates()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.userLocation = location
            print("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isLocationUpdating = false
        }
    }
}

@main
struct CreamieApp: App {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var authService = AuthenticationService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(chatViewModel)
                .environmentObject(authService)
                .task {
                    await supabase.realtimeV2.connect()
                }
        }
    }
}
