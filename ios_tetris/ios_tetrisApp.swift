import SwiftUI

@main
struct ios_tetrisApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                GameView()
            } else {
                OnboardingView {
                    hasSeenOnboarding = true
                }
            }
        }
    }
}
