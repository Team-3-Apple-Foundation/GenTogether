//
//  UpgradeAccountView.swift
//  GenTogether
//
//  Sheet that upgrades an anonymous guest session to a permanent account —
//  either email/password or Google — via Firebase account linking
//  (AuthService.linkAnonymousAccount / .signInWithGoogle), preserving the
//  Firebase UID and every Firestore document already written under it.
//

import SwiftUI
import GoogleSignInSwift

struct UpgradeAccountView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""

    /// The name was already collected during onboarding and saved to
    /// users/{uid}.displayName — no need to ask for it again here.
    @State private var profile: UserProfile?

    private var displayName: String {
        profile?.displayName ?? authViewModel.displayName ?? "Member"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Create Your Account") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                }
                Button {
                    Task {
                        await authViewModel.upgradeGuestAccount(email: email, password: password, displayName: displayName)
                        if authViewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                } label: {
                    if authViewModel.loadingAction == .email {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Create Account").frame(maxWidth: .infinity)
                        
                    }
                }
                .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
                

                Section {
                    GoogleSignInButton(scheme: .light, style: .wide) {
                        Task {
                            await authViewModel.signInWithGoogle()
                            if authViewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .frame(height: 44)
                    .disabled(authViewModel.isLoading)
                    .listRowInsets(EdgeInsets())
                    .padding(8)
                }

                if let errorMessage = authViewModel.errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Create a Permanent Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                guard let userId = authViewModel.currentUserId else { return }
                profile = try? await UserService.shared.fetchCurrentUserProfile(userId: userId)
            }
        }
    }
}

#Preview {
    UpgradeAccountView()
        .environmentObject(AuthViewModel())
}
