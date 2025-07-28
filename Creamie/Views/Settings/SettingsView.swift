import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject var authService: AuthenticationService
    @State private var notificationsEnabled = true
    @State private var showOnMap = true
    @State private var autoAcceptPlaydates = false
    @State private var showingAbout = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTerms = false
    @State private var showingLogoutAlert = false
    @StateObject private var dogProfileViewModel = DogProfileViewModel()
    @AppStorage("isOnline") private var isOnline = true
    
    
    var body: some View {
        NavigationStack {
            
            List {
                // Profile Section
                Section {
                    HStack(spacing: 16) {
                        // Profile picture placeholder
                        Circle()
                            .fill(Color.purple.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.title2)
                                    .foregroundColor(Color.purple)
                            }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authService.currentUser?.name ?? "User")
                                .font(.headline)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        NavigationLink(destination: EditProfileView()) {}
                    }
                    .padding(.vertical, 4)
                }
                
                // App Preferences
                Section("App Preferences") {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        Text("Push Notifications")
                        Spacer()
                        Toggle("", isOn: $notificationsEnabled)
                    }
                    
//                    HStack {
//                        Image(systemName: "map.fill")
//                            .foregroundColor(.green)
//                            .frame(width: 24)
//                        Text("Show My Dogs on Map")
//                        Spacer()
//                        Toggle("", isOn: $showOnMap)
//                    }
                    
//                    HStack {
//                        Image(systemName: "calendar.badge.checkmark")
//                            .foregroundColor(.blue)
//                            .frame(width: 24)
//                        Text("Auto-Accept Playdates")
//                        Spacer()
//                        Toggle("", isOn: $autoAcceptPlaydates)
//                    }
                }
                
                // Privacy & Security
                Section("Privacy & Security") {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Location Services")
                            Text(locationStatusText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Settings") {
                            openLocationSettings()
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
//                    // Deprecate this for now since user can turn off in each dag profile card
//                    HStack {
//                        Image(systemName: "eye.slash.fill")
//                            .foregroundColor(.purple)
//                            .frame(width: 24)
//                        Text("Show My Dogs on Map")
//                        Spacer()
//                        Toggle("", isOn: $isOnline)
//                            .onChange(of: isOnline) {
//                                Task {
//                                    await updateOnlineStatus(isOnline: isOnline)
//                                }
//                            }
//                    }
                    
                    NavigationLink(destination: BlockedUsersView()) {
                        HStack {
                            Image(systemName: "person.2.slash")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            Text("Blocked Users")
                        }
                    }
                }
                
                // Support & Information
                Section("Support & Information") {
                    Button(action: { showingAbout = true }) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("About Creamie")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: sendFeedback) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            Text("Send Feedback")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: { showingPrivacyPolicy = true }) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: { showingTerms = true }) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                // Account Actions
                Section {
                    Button(action: { showingLogoutAlert = true }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            Text("Sign Out")
                        }
                    }
                    .foregroundColor(.red)
                }
                
                // App Version
                Section {
                    HStack {
                        Text("Version")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showingTerms) {
            TermsOfServiceView()
        }
        .alert("Sign Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    private var locationStatusText: String {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "Enabled"
        case .denied, .restricted:
            return "Disabled"
        case .notDetermined:
            return "Not Set"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func openLocationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func sendFeedback() {
        // TODO: real email address
        if let url = URL(string: "mailto:support@creamie.app?subject=Feedback") {
            UIApplication.shared.open(url)
        }
    }
    
    private func signOut() {
        authService.signOut()
        print("👋 User signed out")
    }
    
    private func updateOnlineStatus(isOnline: Bool) async {
        await dogProfileViewModel.updateDogOnlineStatus(isOnline: isOnline,
                                                        userId: authService.currentUser?.id)
    }
}

#Preview {
    SettingsView()
        .environmentObject(LocationManager())
        .environmentObject(AuthenticationService())
}
