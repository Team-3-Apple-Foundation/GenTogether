//
//  FirebaseEnvironment.swift
//  GenTogether
//
//  Small startup check so a missing GoogleService-Info.plist fails
//  gracefully (a clear console warning) instead of a cryptic crash inside
//  FirebaseApp.configure().
//

import Foundation

enum FirebaseEnvironment {
    /// True when a GoogleService-Info.plist is bundled with the app and
    /// contains the keys FirebaseApp.configure() requires.
    static var isConfigured: Bool {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              plist["PROJECT_ID"] != nil else {
            return false
        }
        return true
    }

    /// Prints a loud, developer-facing warning. Call before
    /// `FirebaseApp.configure()` when `isConfigured` is false so the app
    /// still launches (with Firebase features unavailable) instead of
    /// crashing.
    static func warnIfMissingConfiguration() {
        guard !isConfigured else { return }
        #if DEBUG
        print("""
        ⚠️ ⚠️ ⚠️ ------------------------------------------------------------
        GoogleService-Info.plist was not found in the app bundle.
        Firebase has NOT been configured — authentication, Firestore, and
        Storage calls will fail until this file is added.

        1. Download GoogleService-Info.plist from the Firebase Console
           (Project settings > Your apps > iOS app).
        2. Drag it into the GenTogether/ folder in Xcode, making sure
           "Add to target: GenTogether" is checked.
        See FIREBASE_SETUP.md for full instructions.
        ------------------------------------------------------------ ⚠️ ⚠️ ⚠️
        """)
        #endif
    }

    /// Every service method that touches Auth.auth() / Firestore.firestore()
    /// / Storage.storage() must call this FIRST, before referencing those
    /// APIs. Firebase's SDKs crash with a fatal error if used before
    /// FirebaseApp.configure() has run, so this turns a missing plist into
    /// a normal, catchable, user-facing error instead of an app crash.
    static func requireConfigured() throws {
        guard isConfigured else {
            throw FirebaseNotConfiguredError.missingConfiguration
        }
    }
}

enum FirebaseNotConfiguredError: LocalizedError {
    case missingConfiguration

    var errorDescription: String? {
        "Firebase isn't set up yet — GoogleService-Info.plist is missing. See FIREBASE_SETUP.md."
    }
}
