//
//  WelcomeView.swift
//  Creamie
//
//  Created by Siqi Xu on 2025/7/28.
//

import SwiftUI

struct WelcomeView: View {
    let viewModel: AuthenticationViewModel
    
    var body: some View {
        ZStack {
            // Background with dog silhouettes
            backgroundView
            
            VStack(spacing: 40) {
                Spacer()
                
                // App Logo/Title
                VStack(spacing: 16) {
                    Image("Splash")
                        .resizable()
                        .scaledToFit() 
                        .font(.system(size: 100))
                        .foregroundColor(.purple)
                    
                    Text("Creamie")
                        .font(.largeTitle.bold())
                        .foregroundColor(.primary)
                    
                    Text("Connect with dog lovers\nin your neighborhood")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button(action: {
                        viewModel.currentStep = .signUp
                    }) {
                        Text("Create New Account")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .glassEffect(.clear.interactive().tint(Color.pink.opacity(0.7)))
                    
                    Button(action: {
                        viewModel.currentStep = .login
                    }) {
                        Text("Sign in")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .glassEffect(.clear.interactive().tint(Color.purple))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .ignoresSafeArea()
    }
    
    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Decorative paw prints
            VStack {
                HStack {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.purple)
                        .rotationEffect(.degrees(-15))
                    Spacer()
                }
                .padding(.top, 100)
                .padding(.leading, 50)
                
                Spacer()
                
                HStack {
                    Spacer()
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 25))
                        .foregroundColor(.pink)
                        .rotationEffect(.degrees(30))
                }
                .padding(.bottom, 200)
                .padding(.trailing, 80)
            }
        }
    }
}

#Preview {
    WelcomeView(viewModel: AuthenticationViewModel())
}
