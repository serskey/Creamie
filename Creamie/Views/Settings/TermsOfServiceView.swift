//
//  TermsOfServiceView.swift
//  Creamie
//
//  Created by Siqi Xu on 2025/7/28.
//

import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
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
                        dismiss()
                    }
                }
            }
        }
    }
}
