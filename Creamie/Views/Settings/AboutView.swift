//
//  AboutView.swift
//  Creamie
//
//  Created by Siqi Xu on 2025/7/28.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
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
                        dismiss()
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
