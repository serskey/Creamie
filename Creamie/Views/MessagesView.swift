import SwiftUI

struct MessagesView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Messages View")
                Text("Chat with other pet owners here")
            }
            .navigationTitle("Messages")
        }
    }
}

#Preview {
    MessagesView()
} 