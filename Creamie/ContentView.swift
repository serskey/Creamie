//
//  ContentView.swift
//  Creamie
//
//  Created by Siqi Xu on 7/6/25.
//

import SwiftUI
import CoreLocation

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var mapViewId = UUID()
    @State private var dogProfileViewId = UUID()
    @State private var selectedChatId: UUID?
    @State private var isLoading = true
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @State private var showingLocationAlert = false
    @State private var showTabBar = true
    
    var body: some View {
        Group {
            if isLoading {
                SplashView()
                    .onAppear {
                        startLoadingSequence()
                    }
            } else {
                mainContent
            }
        }
    }
    
    private var mainContent: some View {
        ZStack {
            // Tab Content
            Group {
                switch selectedTab {
                case 0:
                    MapView(selectedTab: $selectedTab,
                            selectedChatId: $selectedChatId)
                        .id(mapViewId)
                case 1:
                    DogProfilesView()
                        .id(dogProfileViewId)
                case 2:
                    MessagesView(
                        chatViewModel: chatViewModel,
                        selectedChatId: $selectedChatId,
                        showTabBar: $showTabBar)
                case 3:
                    SettingsView()
                default:
                    MapView(selectedTab: $selectedTab, selectedChatId: $selectedChatId)
                        .id(mapViewId)
                }
            }
            
            // Floating Tab Bar
            if showTabBar {
                VStack {
                    Spacer()
                    TabBar(selectedTab: $selectedTab)
                }
            }
        }
        .onAppear {
            checkLocationPermission()
        }
        .onChange(of: locationManager.authorizationStatus) {
            checkLocationPermission()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // When switching to map tab (0), create a new ID to force refresh
            if newValue == 0 {
                // Small delay to ensure smooth transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    mapViewId = UUID()
                }
            }
        }
        .alert("Location Access Required", isPresented: $showingLocationAlert) {
            Button("Open Settings") {
                // TODO: Go deeply to this specific app's location setting
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
            .buttonStyle(.glassProminent)
            .tint(.purple)
            
            Button("Cancel", role: .cancel) {
                
            }
            .buttonStyle(.glassProminent)
            .tint(.pink)

        } message: {
            Text("Creamie needs access to your location to show nearby dogs. Please enable location access in Settings.")
        }
    }
    
    private func checkLocationPermission() {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            showingLocationAlert = true
        default:
            showingLocationAlert = false
        }
    }
    
    private func startLoadingSequence() {
        // Request location permission during splash
        locationManager.requestPermission()
        
        // Minimum splash duration of 2.5 seconds for nice UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isLoading = false
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationManager())
        .environmentObject(ChatViewModel())
}
