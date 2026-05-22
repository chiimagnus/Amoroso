import UIKit

extension PianoGuideHighlightTintToken {
    var uiColor: UIColor {
        switch self {
        case .rightHandWhiteKey:
            .systemYellow
        case .rightHandBlackKey:
            .systemOrange
        case .leftHandKey:
            .systemCyan
        }
    }
}

