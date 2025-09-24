import SwiftUI
import GoogleSignIn

@main
struct MardHelplineDEMOApp: App {
    @StateObject private var router = AppRouter()
    
    init() {
        // Configure Google Sign-In - FIXED
        if let path = Bundle.main.path(forResource: "client_768935080812-coqu2kca5413ransr5il09sak6thms99.apps.googleusercontent.com", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let clientId = plist["CLIENT_ID"] as? String {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
            print("✅ Google Sign-In configured successfully")
        } else {
            print("❌ GoogleService-Info.plist not found or CLIENT_ID missing")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(router)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
