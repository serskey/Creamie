import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Settings View")
                Text("Adjust your app settings here")
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
} 