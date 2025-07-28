//
//  UserSetupView.swift
//  Creamie
//
//  Created by Siqi Xu on 2025/7/28.
//

import SwiftUI

struct UserSetupView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @State private var name = ""
    @State private var phoneNumber = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Complete Your Profile")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                TextField("Full Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Phone Number", text: $phoneNumber)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.phonePad)
            }
            .padding(.horizontal)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
            
            Button("Complete Setup") {
                Task {
                    await viewModel.updateProfile(
                        name: name,
                        phoneNumber: phoneNumber
                    )
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isLoading || name.isEmpty || phoneNumber.isEmpty)
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding()
            }
        }
        .padding()
        .onAppear {
            // Pre-populate with current user data if available
            if let user = viewModel.currentUser {
                name = user.name
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
