import UIKit

/// Thin wrapper around UIFeedbackGenerator.
/// All methods must be called on the main thread.
enum Haptics {
    private static let light  = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy  = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigid  = UIImpactFeedbackGenerator(style: .rigid)
    private static let notify = UINotificationFeedbackGenerator()

    static func move()     { light.impactOccurred() }
    static func rotate()   { light.impactOccurred(intensity: 0.6) }
    static func hold()     { medium.impactOccurred(intensity: 0.5) }
    static func lock()     { medium.impactOccurred() }
    static func hardDrop() { heavy.impactOccurred() }
    static func lineClear(count: Int) {
        if count == 4 { rigid.impactOccurred() }
        else          { heavy.impactOccurred(intensity: CGFloat(count) * 0.25 + 0.25) }
    }
    static func gameOver() { notify.notificationOccurred(.error) }
}
