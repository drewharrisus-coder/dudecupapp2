//
//  The_RugApp.swift
//  The Rug
//

import SwiftUI
import FirebaseCore

@main
struct TheRugApp: App {
    // 1. Initialize our new store
    @State private var bettingStore = BettingStore()
    
    // 2. Track the app's lifecycle state
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                // 3. Keep the old managers injected so the app still compiles during refactoring
                .environment(TournamentManager.shared)
                .environment(AuthManager.shared)
                
                // 4. Inject the new BettingStore for our updated views
                .environment(bettingStore)
        }
        // 5. Tie the Firestore listeners to the app lifecycle
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                bettingStore.startListening()
            } else if newPhase == .background {
                bettingStore.stopListening()
            }
        }
    }
}
