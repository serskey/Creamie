//
//  EditProfileView.swift
//  Creamie
//
//  Created by Siqi Xu on 2025/7/28.
//

import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthenticationService
    @State private var name = ""
    @State private var email = ""
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    
                    Button(action: {
                        // TODO: Handle save
                    }) {
                        Image(systemName: "checkmark")
                    }
                    .foregroundColor(Color.primary)
                }
            }
            .onAppear {
                // Pre-populate with current user data
                if let user = authService.currentUser {
                    name = user.name
                    email = user.email
                }
            }
        }
    }
}
