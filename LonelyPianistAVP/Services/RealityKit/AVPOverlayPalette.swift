import UIKit

enum AVPOverlayPalette {
    // Calibration
    static let reticleColor: UIColor = .systemYellow.withAlphaComponent(0.9)
    static let reticleReadyColor: UIColor = .systemGreen.withAlphaComponent(0.9)
    static let a0AnchorColor: UIColor = .systemBlue.withAlphaComponent(0.9)
    static let c8AnchorColor: UIColor = .systemPurple.withAlphaComponent(0.9)

    /// Hand tracking debug
    static let handTipColor: UIColor = .systemGreen.withAlphaComponent(0.9)

    // Practice feedback
    static let feedbackNoneColor: UIColor = .systemTeal.withAlphaComponent(0.65)
    static let feedbackCorrectColor: UIColor = .systemGreen.withAlphaComponent(0.75)
    static let feedbackWrongColor: UIColor = .systemRed.withAlphaComponent(0.75)
}
