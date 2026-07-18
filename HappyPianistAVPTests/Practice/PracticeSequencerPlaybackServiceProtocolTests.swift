import Foundation
@testable import HappyPianistAVP
import Testing

@Test
@MainActor
func sequencerPlaybackServiceProtocolSupportsDependencyInjection() {
    final class FakeSequencerPlaybackService: PracticeSequencerPlaybackServiceProtocol {
        private(set) var resetCommands: [PerformanceTransportCommand] = []

        func warmUp() throws {}
        func stop(resetCommands: [PerformanceTransportCommand]) {
            self.resetCommands = resetCommands
        }
        func load(sequence _: PracticeSequencerSequence) throws {}
        func play(fromSeconds _: TimeInterval) throws {}
        func currentSeconds() -> TimeInterval {
            0
        }

        func playOneShot(noteOns _: [PracticeOneShotNoteOn], durationSeconds _: TimeInterval) throws {}
        func startLiveNotes(midiNotes _: Set<Int>) throws {}
        func stopLiveNotes(midiNotes _: Set<Int>) {}
        func stopAllLiveNotes() {}
    }

    func accept(_ service: PracticeSequencerPlaybackServiceProtocol) {
        _ = service
    }

    let service = FakeSequencerPlaybackService()
    accept(service)
    service.stop(resetCommands: PerformanceTransportReducer.fullResetCommands)
    #expect(service.resetCommands == PerformanceTransportReducer.fullResetCommands)
}
