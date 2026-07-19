protocol StepMatcherProtocol {
    func matches(expectedNotes: [Int], pressedNotes: Set<Int>) -> Bool
}

struct StepMatcher: StepMatcherProtocol {
    func matches(expectedNotes: [Int], pressedNotes: Set<Int>) -> Bool {
        let expected = Set(expectedNotes)
        return expected.isEmpty == false && expected.isSubset(of: pressedNotes)
    }
}
