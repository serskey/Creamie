import SwiftUI
import Combine

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct SignUpRequest: Codable {
    let email: String
    let password: String
    let name: String
    let phoneNumber: String
}

struct UpdateProfileRequest: Codable {
    let name: String
    let phoneNumber: String
    let photos: [String]?
}

struct AuthResponse: Codable {
    let success: Bool
    let message: String?
    let user: User?
    let token: String?
}

struct User: Codable, Identifiable {
    let id: UUID
    let name: String
    let email: String
    let phoneNumber: String?
    let photos: [String]?
    let createdAt: String
    let updatedAt: String
    
    var firstName: String {
        name.components(separatedBy: " ").first ?? name
    }
    
    var lastName: String {
        let components = name.components(separatedBy: " ")
        return components.count > 1 ? components.dropFirst().joined(separator: " ") : ""
    }
}


@MainActor
class AuthenticationViewModel: ObservableObject {
    enum AuthStep {
        case welcome
        case login
        case signUp
        case userSetup
        case complete
    }
    
    // MARK: - Published Properties
    @Published var currentStep: AuthStep = .welcome
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let authService = AuthenticationService.shared // Direct reference to singleton
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var isAuthenticated: Bool {
        authService.isAuthenticated
    }
    
    var currentUser: User? {
        authService.currentUser
    }
    
    // MARK: - Initialization
    init() {
        setupAuthenticationObserver()
        
        // Check if user is already authenticated
        if authService.isAuthenticated {
            currentStep = .complete
        }
    }
    
    // MARK: - Private Setup
    private func setupAuthenticationObserver() {
        // Listen for authentication changes
        authService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                guard let self = self else { return }
                
                if isAuthenticated {
                    self.currentStep = .complete
                    self.clearError()
                    print("🔄 User authenticated - moved to complete step")
                } else {
                    // Reset to welcome when user signs out
                    self.currentStep = .welcome
                    self.clearError()
                    print("🔄 User signed out - moved to welcome step")
                }
            }
            .store(in: &cancellables)
        
        // Also listen for loading state changes from the auth service
        authService.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isServiceLoading in
                // You can sync loading state if needed
                // self?.isLoading = isServiceLoading
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func signIn(email: String, password: String) async {
        await performAuthAction { [weak self] in
            guard let self = self else {
                throw AuthenticationError.notAuthenticated
            }
            
            let user = try await self.authService.signIn(email: email, password: password)
            
            // Debug: Check auth state after signin
            print("🔄 After signin - Service isAuthenticated: \(self.authService.isAuthenticated)")
            print("🔄 After signin - ViewModel isAuthenticated: \(self.isAuthenticated)")
            print("🔄 After signin - Current user: \(user.name)")
            
            // The currentStep will be updated automatically via the publisher
            return "Successfully signed in as \(user.name)"
        }
    }
    
    func signUp(email: String, password: String, name: String, phoneNumber: String) async {
        await performAuthAction { [weak self] in
            guard let self = self else {
                throw AuthenticationError.notAuthenticated
            }
            
            let user = try await self.authService.signUp(
                email: email,
                password: password,
                name: name,
                phoneNumber: phoneNumber
            )
            
            print("🔄 After signup - User: \(user.name)")
            return "✅ Successfully registered as \(user.name)"
        }
    }
    
    func updateProfile(name: String, phoneNumber: String, photos: [String]? = nil) async {
        await performAuthAction { [weak self] in
            guard let self = self else {
                throw AuthenticationError.notAuthenticated
            }
            
            let user = try await self.authService.updateUserProfile(
                name: name,
                phoneNumber: phoneNumber,
                photos: photos
            )
            
            // Manually set to complete since profile update doesn't change auth state
            self.currentStep = .complete
            return "✅ Profile updated successfully for \(user.name)"
        }
    }
    
    func signOut() {
        authService.signOut()
        // currentStep will be updated automatically via the publisher
        clearError()
        print("🔄 User signed out")
    }
    
    func refreshToken() async {
        await performAuthAction { [weak self] in
            guard let self = self else {
                throw AuthenticationError.notAuthenticated
            }
            
            let user = try await self.authService.refreshToken()
            return "Token refreshed for \(user.name)"
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func navigateToStep(_ step: AuthStep) {
        currentStep = step
        clearError()
        print("🔄 Navigated to step: \(step)")
    }
    
    // MARK: - Validation Methods
    func validateEmail(_ email: String) -> String? {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if email.isEmpty {
            return "Email is required"
        } else if !emailPredicate.evaluate(with: email) {
            return "Please enter a valid email address"
        }
        return nil
    }
    
    func validatePassword(_ password: String) -> String? {
        if password.isEmpty {
            return "Password is required"
        } else if password.count < 8 {
            return "Password must be at least 8 characters long"
        }
        return nil
    }
    
    func validateName(_ name: String) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return "Name is required"
        } else if trimmedName.count < 2 {
            return "Name must be at least 2 characters long"
        }
        return nil
    }
    
    func validatePhoneNumber(_ phoneNumber: String) -> String? {
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPhone.isEmpty {
            return "Phone number is required"
        } else if trimmedPhone.count < 10 {
            return "Please enter a valid phone number"
        }
        return nil
    }
    
    // MARK: - Private Methods
    
    private func performAuthAction(_ action: @escaping () async throws -> String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let successMessage = try await action()
            print("✅ \(successMessage)")
            // You can show success messages if needed
        } catch let error as AuthenticationError {
            errorMessage = error.localizedDescription
            print("❌ Auth error: \(error.localizedDescription)")
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            print("❌ API error: \(error.localizedDescription)")
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            print("❌ Unexpected error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
}

// MARK: - Form Validation Helper
extension AuthenticationViewModel {
    func validateLoginForm(email: String, password: String) -> [String] {
        var errors: [String] = []
        
        if let emailError = validateEmail(email) {
            errors.append(emailError)
        }
        
        if let passwordError = validatePassword(password) {
            errors.append(passwordError)
        }
        
        return errors
    }
    
    func validateSignUpForm(email: String, password: String, name: String, phoneNumber: String) -> [String] {
        var errors: [String] = []
        
        if let emailError = validateEmail(email) {
            errors.append(emailError)
        }
        
        if let passwordError = validatePassword(password) {
            errors.append(passwordError)
        }
        
        if let nameError = validateName(name) {
            errors.append(nameError)
        }
        
        if let phoneError = validatePhoneNumber(phoneNumber) {
            errors.append(phoneError)
        }
        
        return errors
    }
    
    func validateProfileForm(name: String, phoneNumber: String) -> [String] {
        var errors: [String] = []
        
        if let nameError = validateName(name) {
            errors.append(nameError)
        }
        
        if let phoneError = validatePhoneNumber(phoneNumber) {
            errors.append(phoneError)
        }
        
        return errors
    }
    
    // MARK: - Convenience computed properties
    var isFormValid: Bool {
        errorMessage == nil && !isLoading
    }
    
    var showLoadingIndicator: Bool {
        isLoading
    }
    
    var hasError: Bool {
        errorMessage != nil
    }
    
    // MARK: - Convenience methods for specific validations
    func isLoginFormValid(email: String, password: String) -> Bool {
        return validateLoginForm(email: email, password: password).isEmpty
    }
    
    func isSignUpFormValid(email: String, password: String, name: String, phoneNumber: String) -> Bool {
        return validateSignUpForm(email: email, password: password, name: name, phoneNumber: phoneNumber).isEmpty
    }
    
    func isProfileFormValid(name: String, phoneNumber: String) -> Bool {
        return validateProfileForm(name: name, phoneNumber: phoneNumber).isEmpty
    }
}

// MARK: - Authentication State Helpers
extension AuthenticationViewModel {
    var shouldShowWelcome: Bool {
        currentStep == .welcome
    }
    
    var shouldShowLogin: Bool {
        currentStep == .login
    }
    
    var shouldShowSignUp: Bool {
        currentStep == .signUp
    }
    
    var shouldShowUserSetup: Bool {
        currentStep == .userSetup
    }
    
    var shouldShowMainApp: Bool {
        currentStep == .complete && isAuthenticated
    }
    
    func handleAuthenticationSuccess() {
        // Called when authentication is successful
        // You can add analytics tracking, notifications, etc. here
        clearError()
        print("🎉 Authentication successful!")
    }
    
    func handleAuthenticationFailure(_ error: Error) {
        // Called when authentication fails
        // You can add error logging, analytics, etc. here
        if let authError = error as? AuthenticationError {
            errorMessage = authError.localizedDescription
        } else if let apiError = error as? APIError {
            errorMessage = apiError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
        print("💥 Authentication failed: \(errorMessage ?? "Unknown error")")
    }
}
