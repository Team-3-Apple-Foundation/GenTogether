//
//  AuthService.swift
//  GenTogether
//
//  Thin wrapper around FirebaseAuth. Publishes the current FirebaseAuth
//  user so view models can react to sign-in/sign-out/guest state without
//  each of them registering their own listener.
//

import Foundation
import Combine
import UIKit
import FirebaseAuth
import GoogleSignIn

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var firebaseUser: User?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private init() {
        // Guarded: Auth.auth() crashes with a fatal error if FirebaseApp
        // hasn't been configured (e.g. GoogleService-Info.plist missing).
        // Skipping listener setup here just means firebaseUser stays nil —
        // every method below still fails gracefully via requireConfigured().
        guard FirebaseEnvironment.isConfigured else { return }
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.firebaseUser = user
        }
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
    }

    var currentUser: User? {
        guard FirebaseEnvironment.isConfigured else { return nil }
        return Auth.auth().currentUser
    }

    var isAuthenticated: Bool {
        currentUser != nil
    }

    var isAnonymous: Bool {
        currentUser?.isAnonymous ?? false
    }

    /// Signs in anonymously for "Continue as guest". The resulting Firebase
    /// UID is stable until sign-out, so guest progress persists across app
    /// launches as long as the user doesn't sign out. If Firebase already
    /// has a cached anonymous session (e.g. app relaunch), that session is
    /// reused instead of minting a new UID.
    @discardableResult
    func continueAsGuest() async throws -> User {
        try FirebaseEnvironment.requireConfigured()

        if let existingUser = Auth.auth().currentUser, existingUser.isAnonymous {
            debugLogGuestSignIn(uid: existingUser.uid, isAnonymous: true, reused: true)
            return existingUser
        }

        do {
            let result = try await Auth.auth().signInAnonymously()
            debugLogGuestSignIn(uid: result.user.uid, isAnonymous: result.user.isAnonymous, reused: false)
            return result.user
        } catch {
            let nsError = error as NSError
            #if DEBUG
            print("""
            [AuthService] Guest sign-in failed — domain: \(nsError.domain), code: \(nsError.code)
            If domain is FIRAuthErrorDomain and code is 17999/operation-not-allowed, \
            Anonymous Authentication is likely disabled in the Firebase Console \
            (Authentication → Sign-in method → Anonymous → Enable).
            """)
            #endif
            throw AuthServiceError.signInFailed(error)
        }
    }

    private func debugLogGuestSignIn(uid: String, isAnonymous: Bool, reused: Bool) {
        #if DEBUG
        print("[AuthService] Guest sign-in \(reused ? "reused existing session" : "succeeded") — uid: \(uid), isAnonymous: \(isAnonymous)")
        #endif
    }

    @discardableResult
    func createAccount(email: String, password: String, displayName: String) async throws -> User {
        try FirebaseEnvironment.requireConfigured()
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            try await applyDisplayName(displayName, to: result.user)
            return result.user
        } catch {
            throw AuthServiceError.createAccountFailed(error)
        }
    }

    @discardableResult
    func signIn(email: String, password: String) async throws -> User {
        try FirebaseEnvironment.requireConfigured()
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            return result.user
        } catch {
            throw AuthServiceError.signInFailed(error)
        }
    }

    /// Sends a Firebase password-reset email. Firebase handles the email
    /// delivery and hosts the reset page (see Authentication → Templates →
    /// Password reset in the console), so the app only needs to trigger it.
    func sendPasswordReset(email: String) async throws {
        try FirebaseEnvironment.requireConfigured()
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                Auth.auth().sendPasswordReset(withEmail: email) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        } catch {
            throw AuthServiceError.passwordResetFailed(error)
        }
    }

    func signOut() throws {
        try FirebaseEnvironment.requireConfigured()
        do {
            try Auth.auth().signOut()
        } catch {
            throw AuthServiceError.signOutFailed(error)
        }
    }

    /// Upgrades the current anonymous (guest) session to a permanent
    /// email/password account. Because this uses `link(with:)` rather than
    /// creating a brand-new account, the Firebase UID — and therefore every
    /// Firestore document already written under `users/{uid}` — is
    /// preserved.
    @discardableResult
    func linkAnonymousAccount(email: String, password: String, displayName: String) async throws -> User {
        try FirebaseEnvironment.requireConfigured()
        guard let user = Auth.auth().currentUser, user.isAnonymous else {
            throw AuthServiceError.noAnonymousUserToLink
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        do {
            let result = try await user.link(with: credential)
            try await applyDisplayName(displayName, to: result.user)
            return result.user
        } catch {
            throw AuthServiceError.linkingFailed(error)
        }
    }

    /// Signs in with Google via GIDSignIn, then exchanges the Google
    /// credential for a Firebase session. If the current session is an
    /// anonymous guest, links the credential instead of replacing the
    /// session outright, preserving the guest's Firebase UID and existing
    /// Firestore progress — unless that Google account is already tied to
    /// a different Firebase user, in which case we fall back to signing in
    /// as that existing account (Firebase's normal "already in use" case).
    @discardableResult
    func signInWithGoogle(presenting viewController: UIViewController) async throws -> User {
        try FirebaseEnvironment.requireConfigured()
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthServiceError.googleSignInFailed(GoogleSignInError.missingIDToken)
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )

            if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
                do {
                    let linkResult = try await currentUser.link(with: credential)
                    return linkResult.user
                } catch {
                    // Most likely "credential already in use" — that Google
                    // account already has its own Firebase user. Fall back to
                    // signing into that existing account instead of failing.
                    let authResult = try await Auth.auth().signIn(with: credential)
                    return authResult.user
                }
            } else {
                let authResult = try await Auth.auth().signIn(with: credential)
                return authResult.user
            }
        } catch {
            throw AuthServiceError.googleSignInFailed(error)
        }
    }

    private func applyDisplayName(_ displayName: String, to user: User) async throws {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()
    }
}

enum AuthServiceError: LocalizedError {
    case noAnonymousUserToLink
    case signInFailed(Error)
    case createAccountFailed(Error)
    case signOutFailed(Error)
    case linkingFailed(Error)
    case googleSignInFailed(Error)
    case passwordResetFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noAnonymousUserToLink:
            return "There is no guest session to upgrade. Continue as a guest first."
        case .signInFailed(let error):
            return "Couldn't sign in: \(error.localizedDescription)"
        case .createAccountFailed(let error):
            return "Couldn't create your account: \(error.localizedDescription)"
        case .signOutFailed(let error):
            return "Couldn't sign out: \(error.localizedDescription)"
        case .linkingFailed(let error):
            return "Couldn't upgrade your guest account: \(error.localizedDescription)"
        case .googleSignInFailed(let error):
            return "Couldn't sign in with Google: \(error.localizedDescription)"
        case .passwordResetFailed(let error):
            return "Couldn't send the reset email: \(error.localizedDescription)"
        }
    }
}

enum GoogleSignInError: LocalizedError {
    case missingIDToken
    case missingPresentingViewController

    var errorDescription: String? {
        switch self {
        case .missingIDToken:
            return "Google didn't return an ID token."
        case .missingPresentingViewController:
            return "Couldn't find a screen to present Google Sign-In from."
        }
    }
}
