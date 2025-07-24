import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @State private var notificationsEnabled = true
    @State private var showOnMap = true
    @State private var autoAcceptPlaydates = false
    @State private var shareStatus = true
    @State private var showingAbout = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTerms = false
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationStack {
            
            List {
                // Profile Section
                Section {
                    HStack(spacing: 16) {
                        // Profile picture placeholder
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("John Doe")
                                .font(.headline)
                            Text("john.doe@example.com")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        NavigationLink(destination: EditProfileView()) {
                            Text("Edit")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
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
                    
                    HStack {
                        Image(systemName: "map.fill")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        Text("Show My Dogs on Map")
                        Spacer()
                        Toggle("", isOn: $showOnMap)
                    }
                    
                    HStack {
                        Image(systemName: "calendar.badge.checkmark")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("Auto-Accept Playdates")
                        Spacer()
                        Toggle("", isOn: $autoAcceptPlaydates)
                    }
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
                    
                    HStack {
                        Image(systemName: "eye.slash.fill")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        Text("Display Dog Online Status")
                        Spacer()
                        Toggle("", isOn: $shareStatus)
                    }
                    
                    NavigationLink(destination: BlockedUsersView()) {
                        HStack {
                            Image(systemName: "person.2.slash")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            Text("Blocked Users")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
//            .navigationTitle("Settings")
            
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
                // Handle logout
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
        // In a real app, this would open mail app or feedback form
        if let url = URL(string: "mailto:support@creamie.app?subject=Feedback") {
            UIApplication.shared.open(url)
        }
    }
    
    private func signOut() {
        // Handle sign out logic
        print("User signed out")
        // In a real app, you would:
        // - Clear user session
        // - Clear stored data
        // - Navigate to login screen
    }
}

// MARK: - Supporting Views

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = "John Doe"
    @State private var email = "john.doe@example.com"
    @State private var bio = "Dog lover and Creamie owner!"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Information") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section("About") {
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Handle save
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct BlockedUsersView: View {
    @State private var blockedUsers: [String] = []
    
    var body: some View {
        List {
            if blockedUsers.isEmpty {
                ContentUnavailableView {
                    Label("No Blocked Users", systemImage: "person.2.slash")
                } description: {
                    Text("Users you block will appear here")
                }
            } else {
                ForEach(blockedUsers, id: \.self) { user in
                    HStack {
                        Text(user)
                        Spacer()
                        Button("Unblock") {
                            blockedUsers.removeAll { $0 == user }
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image("Creamie_Selfie")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    Text("Creamie")
                        .font(.largeTitle.bold())
                    
                    Text("Connect with dog owners in your area and arrange playdates for your furry friends!")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features:")
                            .font(.headline)
                        
                        FeatureRow(icon: "map", text: "Find nearby dogs on an interactive map")
                        FeatureRow(icon: "message", text: "Chat with other dog owners")
                        FeatureRow(icon: "calendar", text: "Schedule playdates")
                        FeatureRow(icon: "photo", text: "Share photos of your dogs")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy Policy")
                        .font(.largeTitle.bold())
                    
                    Text("Last updated: \(Date().formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Group {
                        PolicySection(title: "Information We Collect", content: "We collect information you provide when creating your profile, including your name, email, and dog information.")
                        
                        PolicySection(title: "Location Data", content: "We use your location to show nearby dogs and enable meetups. Location data is only shared with your explicit consent.")
                        
                        PolicySection(title: "Data Security", content: "We implement security measures to protect your personal information and ensure data privacy.")
                        
                        PolicySection(title: "Contact Us", content: "If you have questions about this policy, contact us at privacy@creamie.app")
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss
                    }
                }
            }
        }
    }
}

struct TermsOfServiceView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Terms of Service")
                        .font(.largeTitle.bold())
                    
                    Text("Last updated: \(Date().formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Group {
                        PolicySection(title: "Acceptance of Terms", content: "By using Creamie, you agree to these terms and conditions.")
                        
                        PolicySection(title: "User Responsibilities", content: "Users are responsible for their dogs' behavior during meetups and must ensure their pets are properly vaccinated.")
                        
                        PolicySection(title: "Prohibited Conduct", content: "Users must not engage in harassment, share inappropriate content, or misrepresent their dogs or themselves.")
                        
                        PolicySection(title: "Limitation of Liability", content: "Creamie is not responsible for incidents that occur during user-arranged meetups.")
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss
                    }
                }
            }
        }
    }
}

struct PolicySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(LocationManager())
} 
