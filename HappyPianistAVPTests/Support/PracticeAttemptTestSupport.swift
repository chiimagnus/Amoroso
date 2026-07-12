import Foundation
@testable import HappyPianistAVP

func testAttemptOutcome(
    matched: Bool,
    pressedNotes _: Set<Int> = [],
    expectedNotes _: [Int] = []
) -> StepAttemptMatchResult {
    matched ? .matched : .insufficientEvidence
}
