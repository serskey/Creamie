//
//  AuthenticationService.swift
//  Creamie
//
//  Created by Siqi Xu on 2025/7/27.
//

import SwiftUI
import Supabase


class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    private let apiService = APIService.shared
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private let tokenKey = "auth_token"
    private let userKey = "current_user"
    
    init() {
        loadSavedAuthState()
    }
    
    // MARK: - Public Methods
    
    func signIn(email: String, password: String) async throws -> User {
        let request = LoginRequest(email: email, password: password)
        let response: AuthResponse = try await apiService.request(
            endpoint: "/user/login",
            method: .POST,
            body: request,
            responseType: AuthResponse.self
        )
        
        guard response.success, let user = response.user, let token = response.token else {
            throw AuthenticationError.loginFailed(response.message ?? "Login failed")
        }
        
        await handleSuccessfulAuth(user: user, token: token)
        return user
    }
    
    func signUp(email: String, password: String, name: String, phoneNumber: String) async throws -> User {
        let request = SignUpRequest(
            email: email,
            password: password,
            name: name,
            phoneNumber: phoneNumber
        )
        
        let response: AuthResponse = try await apiService.request(
            endpoint: "/user/register",
            method: .POST,
            body: request,
            responseType: AuthResponse.self
        )
            
        guard response.success, let user = response.user, let token = response.token else {
            throw AuthenticationError.registrationFailed(response.message ?? "Registration failed")
        }
        
        await handleSuccessfulAuth(user: user, token: token)
        return user
    }
    
    func updateUserProfile(name: String, phoneNumber: String, photos: [String]?) async throws -> User {
        guard isAuthenticated else {
            throw AuthenticationError.notAuthenticated
        }
        
        let request = UpdateProfileRequest(
            name: name,
            phoneNumber: phoneNumber,
            photos: photos
        )
        
        let response: AuthResponse = try await apiService.request(
            endpoint: "/user/profile",
            method: .PUT,
            body: request,
            responseType: AuthResponse.self
        )
        
        guard response.success, let user = response.user else {
            throw AuthenticationError.profileUpdateFailed(response.message ?? "Profile update failed")
        }
        
        await MainActor.run {
            currentUser = user
            saveUserData(user)
        }
        return user
    }
        
    func signOut() {
        DispatchQueue.main.async { [weak self] in
            self?.isAuthenticated = false
            self?.currentUser = nil
            self?.clearSavedAuthData()
        }
    }
        
    func refreshToken() async throws -> User {
        guard let _ = getSavedToken() else {
            throw AuthenticationError.notAuthenticated
        }
        
        let response: AuthResponse = try await apiService.request(
            endpoint: "/user/refresh",
            method: .POST,
            responseType: AuthResponse.self
        )
        
        guard response.success, let user = response.user, let token = response.token else {
            // If refresh fails, sign out the user
            signOut()
            throw AuthenticationError.tokenRefreshFailed(response.message ?? "Token refresh failed")
        }
        
        await handleSuccessfulAuth(user: user, token: token)
        return user
    }
        
    // MARK: - Private Methods
        
    @MainActor
    private func handleSuccessfulAuth(user: User, token: String) async {
        currentUser = user
        isAuthenticated = true
        saveAuthData(user: user, token: token)
        
        // Debug logging
        print("✅ Authentication successful:")
        print("   User: \(user.name) (\(user.email))")
        print("   UserId: \(user.id)")
        print("   Token saved: \(token.prefix(20))...")
        print("   isAuthenticated: \(isAuthenticated)")
    }
        
    // MARK: - Data Persistence
        
    private func saveAuthData(user: User, token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        saveUserData(user)
    }
        
    private func saveUserData(_ user: User) {
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
    }
        
    private func loadSavedAuthState() {
        guard let token = getSavedToken(),
              let userData = UserDefaults.standard.data(forKey: userKey),
              let user = try? JSONDecoder().decode(User.self, from: userData) else {
            return
        }
        
        // Make sure UI updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            self?.currentUser = user
            self?.isAuthenticated = true
        }
    }
        
    private func getSavedToken() -> String? {
        return UserDefaults.standard.string(forKey: tokenKey)
    }
        
    private func clearSavedAuthData() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
    }
}

enum AuthenticationError: Error, LocalizedError {
    case loginFailed(String)
    case registrationFailed(String)
    case profileUpdateFailed(String)
    case tokenRefreshFailed(String)
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .loginFailed(let message):
            return message
        case .registrationFailed(let message):
            return message
        case .profileUpdateFailed(let message):
            return message
        case .tokenRefreshFailed(let message):
            return message
        case .notAuthenticated:
            return "Not authenticated"
        }
    }
}
