import SwiftUI
import Supabase

// MARK: - Authentication View
struct AuthenticationView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                switch viewModel.currentStep {
                case .welcome:
                    WelcomeView(viewModel: viewModel)
                case .login:
                    LoginView(viewModel: viewModel)
                case .signUp:
                    SignUpView(viewModel: viewModel)
                case .userSetup:
                    UserSetupView(viewModel: viewModel)
                case .complete:
                    // This case shouldn't be reached as the main ContentView
                    // will show the main content when isAuthenticated is true
                    Text("Authentication Complete")
                }
            }
            .animation(.easeInOut, value: viewModel.currentStep)
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}
