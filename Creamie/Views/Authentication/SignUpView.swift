//
//  SignUpView.swift
//  Creamie
//
//  Created by Siqi Xu on 2025/7/28.
//

import SwiftUI

struct SignUpView: View {
    let viewModel: AuthenticationViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var phoneNumber = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var agreedToTerms = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("Create Account")
                        .font(.largeTitle.bold())
                        .foregroundColor(.primary)
                    
                    Text("Join the dog loving community")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Form
                VStack(spacing: 20) {
                    // Name Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        
                        TextField("Enter your name", text: $name)
                            .textFieldStyle(CustomTextFieldStyle())
                            .keyboardType(.default)
                            .textContentType(.name)
                            .autocapitalization(.none)
                    }
                    
                    
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(CustomTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    
                    // Phone Number Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Phone Number")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        
                        TextField("Enter your phone number", text: $phoneNumber)
                            .textFieldStyle(CustomTextFieldStyle())
                            .keyboardType(.numberPad)
                            .textContentType(.telephoneNumber)
                            .autocapitalization(.none)
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        
                        HStack {
                            if showPassword {
                                TextField("Create a password", text: $password)
                            } else {
                                SecureField("Create a password", text: $password)
                            }
                            
                            Button(action: {
                                showPassword.toggle()
                            }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.newPassword)
                    }
                    
                    // Confirm Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        
                        HStack {
                            if showConfirmPassword {
                                TextField("Confirm your password", text: $confirmPassword)
                            } else {
                                SecureField("Confirm your password", text: $confirmPassword)
                            }
                            
                            Button(action: {
                                showConfirmPassword.toggle()
                            }) {
                                Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.newPassword)
                    }
                    
                    // Password validation
                    if !password.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            PasswordRequirement(
                                text: "At least 8 characters",
                                isValid: password.count >= 8
                            )
                            PasswordRequirement(
                                text: "Passwords match",
                                isValid: !confirmPassword.isEmpty && password == confirmPassword
                            )
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    // Terms and Conditions
                    HStack(alignment: .top, spacing: 12) {
                        Button(action: {
                            agreedToTerms.toggle()
                        }) {
                            Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                .foregroundColor(agreedToTerms ? Color.pink.opacity(0.7) : .gray)
                                .font(.title2)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("I agree to the Terms of Service and Privacy Policy")
                                .font(.caption)
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 16) {
                                Button("Terms of Service") {
                                    // Handle terms
                                }
                                Button("Privacy Policy") {
                                    // Handle privacy
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.purple)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 32)
                
                // Sign Up Button
                VStack(spacing: 16) {
                    Button(action: {
                        Task {
                            await viewModel.signUp(email: email, password: password, name: name, phoneNumber: phoneNumber)
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text("Create Account")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .glassEffect(.clear.interactive().tint(Color.pink.opacity(0.7)))
                    .disabled(viewModel.isLoading || !isFormValid)
                    
                    // Login Link
                    HStack {
                        Text("Already have an account?")
                            .foregroundColor(.secondary)
                        Button("Sign In") {
                            viewModel.currentStep = .login
                        }
                        .foregroundColor(.purple)
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal, 32)
                
                Spacer(minLength: 50)
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    viewModel.currentStep = .welcome
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        password.count >= 8 &&
        password == confirmPassword &&
        agreedToTerms
    }
}

struct PasswordRequirement: View {
    let text: String
    let isValid: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isValid ? .green : .gray)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(isValid ? .green : .secondary)
            
            Spacer()
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
