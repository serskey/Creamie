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
    @State private var selectedChatId: UUID?
    @State private var isLoading = true
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var dogProfileViewModel: DogProfileViewModel
    @State private var showingLocationAlert = false
    @State private var showTabBar = true
    
    // Use single shared instances
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var authViewModel = AuthenticationViewModel()
    
    var body: some View {
        Group {
            if isLoading {
                SplashView()
                    .onAppear {
                        print("🔄 Showing SplashView")
                    }
            } else if !authService.isAuthenticated {
                AuthenticationView(viewModel: authViewModel)
                    .environmentObject(authService)
                    .onAppear {
                        print("🔄 Showing AuthenticationView")
                    }
            } else {
                mainContent
                    .onAppear {
                        print("🔄 Showing mainContent - authenticated!")
                        // Defer non-critical initialization until after main content appears
                        deferredInitialization()
                    }
            }
        }
        .task {
            await concurrentStartupSequence()
        }
        .onChange(of: authService.isAuthenticated) { oldValue, newValue in
            print("🔄 ContentView: Authentication changed from \(oldValue) to \(newValue)")
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
                    .environmentObject(dogProfileViewModel)
                case 1:
                    DogProfilesView()
                case 2:
                    MessagesView(
                        chatViewModel: chatViewModel,
                        selectedChatId: $selectedChatId,
                        showTabBar: $showTabBar)
                case 3:
                    SettingsView()
                        .environmentObject(authService)
                default:
                    EmptyView()
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
        .onChange(of: locationManager.authorizationStatus) {
            checkLocationPermission()
        }
        .alert("Location Access Required", isPresented: $showingLocationAlert) {
            Button("Open Settings") {
                // Pending Go deeply to this specific app's location setting
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
    
    // MARK: - Concurrent Startup Sequence
    
    /// Runs auth state loading and Supabase real-time connection concurrently
    /// during the splash screen. Once auth resolves, prefetches dog profiles
    /// and chat list in parallel. Transitions to main content when both auth
    /// is resolved and the minimum 2-second splash duration has elapsed.
    private func concurrentStartupSequence() async {
        let splashStart = Date()
        let minimumSplashDuration: TimeInterval = 2.0
        
        // Phase 1: Run auth state loading and Supabase connection concurrently
        await withTaskGroup(of: Void.self) { group in
            // Auth state is already loaded synchronously in AuthenticationService.init(),
            // but we ensure the Supabase real-time connection starts in parallel
            group.addTask {
                await supabase.realtimeV2.connect()
            }
            
            // Wait for both to complete
            await group.waitForAll()
        }
        
        // Phase 2: If authenticated, prefetch dog profiles and chat list concurrently
        if authService.isAuthenticated, let userId = authService.currentUser?.id {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await dogProfileViewModel.fetchUserDogs(userId: userId)
                }
                group.addTask {
                    await chatViewModel.fetchChatsByCurrentUserId(currentUserId: userId)
                }
                await group.waitForAll()
            }
        }
        
        // Phase 3: Ensure minimum splash duration has elapsed before transitioning
        let elapsed = Date().timeIntervalSince(splashStart)
        if elapsed < minimumSplashDuration {
            let remaining = minimumSplashDuration - elapsed
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
        
        // Transition to main content
        withAnimation(.easeInOut(duration: 0.5)) {
            isLoading = false
        }
    }
    
    // MARK: - Deferred Initialization
    
    /// Defers non-critical initialization until after the main content is displayed.
    /// This includes location permission requests and tracking preference loading.
    private func deferredInitialization() {
        // Request location permission after main content appears
        if authService.isAuthenticated {
            locationManager.requestPermission()
        }
        checkLocationPermission()
        
        // Load tracking preferences after main content appears
        dogProfileViewModel.loadTrackingPreferences()
    }
    
    private func checkLocationPermission() {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            showingLocationAlert = true
        default:
            showingLocationAlert = false
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationManager())
        .environmentObject(ChatViewModel())
        .environmentObject(DogProfileViewModel(locationTracker: DogLocationTracker()))
}
