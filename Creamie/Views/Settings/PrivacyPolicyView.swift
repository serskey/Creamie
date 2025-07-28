//
//  PrivacyPolicyView.swift
//  Creamie
//
//  Created by Siqi Xu on 2025/7/28.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
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
                        dismiss()
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
