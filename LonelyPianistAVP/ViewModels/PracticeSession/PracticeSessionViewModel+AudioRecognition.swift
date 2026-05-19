import Foundation

extension PracticeSessionViewModel {
    func refreshAudioRecognitionForCurrentState() {
        refreshPracticeInputForCurrentState()
        guard let currentStep else {
            audioRecognitionCoordinator?.stop()
            return
        }

        let expectedMIDINotes = uniqueMIDINotes(in: currentStep)
        let expectedByHand = uniqueMIDINotesByHand(in: currentStep)
        let suppressUntil = audioRecognitionSuppressUntil.flatMap { $0 > .now ? $0 : nil }
        let handGateBoost = handGateState.isNearKeyboard || handGateState.hasDownwardMotion

        audioRecognitionCoordinator?.refresh(
            for: .init(
                practiceState: state,
                autoplayState: autoplayState,
                isManualReplayPlaying: isManualReplayPlaying,
                isAudioRecognitionEnabled: isPracticeAudioRecognitionEnabled,
                expectedMIDINotes: expectedMIDINotes,
                expectedRightMIDINotes: expectedByHand.right,
                expectedLeftMIDINotes: expectedByHand.left,
                wrongCandidateMIDINotes: makeWrongCandidateMIDINotes(expectedMIDINotes),
                handGateBoost: handGateBoost,
                isHandSeparatedStepMatchingEnabled: isHandSeparatedStepMatchingEnabled,
                suppressUntil: suppressUntil
            )
        )
    }

    func refreshAudioRecognitionFromSettings() {
        practiceAudioRecognitionDetectorModeSnapshot = Self.readPracticeAudioRecognitionDetectorMode()
        harmonicTemplateTuningProfileSnapshot = Self.profile(for: practiceAudioRecognitionDetectorModeSnapshot)
        audioRecognitionService?.configureDetectorMode(
            practiceAudioRecognitionDetectorModeSnapshot,
            profile: harmonicTemplateTuningProfileSnapshot
        )
        refreshAudioRecognitionForCurrentState()
    }

    func stopAudioRecognition() {
        stopPracticeInput()
        audioRecognitionCoordinator?.stop()
    }

    @discardableResult
    func prepareAudioRecognitionSuppressWindowForPlayback() -> Date {
        let suppressUntil = Date().addingTimeInterval(audioRecognitionSuppressDuration)
        audioRecognitionSuppressUntil = suppressUntil
        audioRecognitionService?.suppressRecognition(
            until: suppressUntil,
            generation: audioRecognitionGeneration
        )
        return suppressUntil
    }

    private func makeWrongCandidateMIDINotes(_ expectedMIDINotes: [Int]) -> [Int] {
        var result: Set<Int> = []
        for note in expectedMIDINotes {
            result.insert(note - 2)
            result.insert(note - 1)
            result.insert(note + 1)
            result.insert(note + 2)
        }
        result.subtract(expectedMIDINotes)
        return result.sorted()
    }

    private var isPracticeAudioRecognitionEnabled: Bool {
        audioRecognitionEnabledSnapshot
    }

    var audioRecognitionGenerationForTesting: Int {
        audioRecognitionGeneration
    }

    var audioRecognitionSuppressRemainingSeconds: TimeInterval {
        guard let audioRecognitionSuppressUntil else { return 0 }
        return max(0, audioRecognitionSuppressUntil.timeIntervalSinceNow)
    }

    private static func readPracticeAudioRecognitionDetectorMode() -> PracticeAudioRecognitionDetectorMode {
        if let rawValue = UserDefaults.standard.string(forKey: "practiceStep3AudioRecognitionMode"),
           let mode = PracticeAudioRecognitionDetectorMode(rawValue: rawValue)
        {
            return mode
        }
        return .harmonicTemplate
    }

    private static func profile(for _: PracticeAudioRecognitionDetectorMode) -> HarmonicTemplateTuningProfile {
        .lowLatencyDefault
    }
}

