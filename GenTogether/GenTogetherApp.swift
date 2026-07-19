import SwiftUI
import GoogleSignIn
import FirebaseCore

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
        [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Fail gracefully rather than crashing inside FirebaseApp.configure()
        // when GoogleService-Info.plist hasn't been added yet — see
        // FIREBASE_SETUP.md. FirebaseApp.configure() itself is only called
        // once, here, for the whole app.
        FirebaseEnvironment.warnIfMissingConfiguration()
        if FirebaseEnvironment.isConfigured {
            FirebaseApp.configure()
            // GIDSignIn needs its own client ID, separate from
            // FirebaseApp.configure() — read it straight from the options
            // FirebaseApp already parsed out of GoogleService-Info.plist
            // rather than hardcoding it a second time.
            if let clientID = FirebaseApp.app()?.options.clientID {
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            }
        }
        return true
    }
}

@main
struct GenTogetherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .onOpenURL { url in
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
