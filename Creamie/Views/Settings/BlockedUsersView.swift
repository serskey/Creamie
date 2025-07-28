//
//  BlockedUsersView.swift
//  Creamie
//
//  Created by Siqi Xu on 2025/7/28.
//

import SwiftUI

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
