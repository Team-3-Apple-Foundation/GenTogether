//
//  UpgradeAccountView.swift
//  GenTogether
//
//  Sheet that upgrades an anonymous guest session to a permanent
//  email/password account (Firebase account linking), preserving the
//  Firebase UID and every Firestore document already written under it.
//

import SwiftUI

struct UpgradeAccountView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Create Your Account") {
                    TextField("Display name", text: $displayName)
                        .textContentType(.name)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                }

                if let errorMessage = authViewModel.errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Upgrade Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await authViewModel.upgradeGuestAccount(email: email, password: password, displayName: displayName)
                            if authViewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty || displayName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    UpgradeAccountView()
        .environmentObject(AuthViewModel())
}
