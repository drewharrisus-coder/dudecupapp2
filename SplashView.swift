import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    
    var body: some View {
        if isActive {
            // Route through auth gate — shows login screen if not authenticated
            AuthGateView()
        } else {
            ZStack {
                // This is your Beastie Orange!
                Color("DudeCupGreen")
                    .ignoresSafeArea()
                
                Image("DudeCupTextLogo")
                    .resizable()
                    .scaledToFit()
                    .padding(40)
            }
            .onAppear {
                // Hold the splash screen for 1.5 seconds, then fade to the app
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.isActive = true
                    }
                }
            }
        }
    }
}
