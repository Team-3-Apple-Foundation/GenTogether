//
//  AuthView.swift
//  GenTogether
//
//  Entry screen shown when there is no signed-in Firebase user. Offers
//  guest access plus registered sign-in/create-account, matching the
//  "Registered account and guest mode" functional requirement.
//

import SwiftUI
import GoogleSignInSwift

struct AuthView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""

    private enum Mode: String, CaseIterable {
        case signIn = "Sign In"
        case createAccount = "Create Account"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        Text("GenTogether")
                            .font(.largeTitle.bold())
                        Text("Learn to spot AI-generated images, together.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 32)

                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 12) {
                        if mode == .createAccount {
                            TextField("Display name", text: $displayName)
                                .textContentType(.name)
                                .textFieldStyle(.roundedBorder)
                        }
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        SecureField("Password", text: $password)
                            .textContentType(mode == .signIn ? .password : .newPassword)
                            .textFieldStyle(.roundedBorder)
                    }

                    if let errorMessage = authViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        Group {
                            if authViewModel.isLoading {
                                ProgressView()
                            } else {
                                Text(mode.rawValue)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)

                    HStack(spacing: 12) {
                        Divider()
                        Text("or").font(.footnote).foregroundStyle(.secondary)
                        Divider()
                    }

                    GoogleSignInButton(scheme: .light, style: .wide) {
                        Task { await authViewModel.signInWithGoogle() }
                    }
                    .frame(height: 44)
                    .disabled(authViewModel.isLoading)

                    Button {
                        Task { await authViewModel.continueAsGuest() }
                    } label: {
                        Text("Continue as Guest")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(authViewModel.isLoading)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func submit() async {
        switch mode {
        case .signIn:
            await authViewModel.signIn(email: email, password: password)
        case .createAccount:
            await authViewModel.createAccount(email: email, password: password, displayName: displayName)
        }
    }
}

#Preview {
    AuthView().environmentObject(AuthViewModel())
}
