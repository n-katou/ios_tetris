import SwiftUI

@main
struct ios_tetrisApp: App {
    @State private var showGame = false

    var body: some Scene {
        WindowGroup {
            if showGame {
                GameView()
            } else {
                OnboardingView { showGame = true }
            }
        }
    }
}
