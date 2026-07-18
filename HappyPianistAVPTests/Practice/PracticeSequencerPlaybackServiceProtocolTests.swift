import Foundation
@testable import HappyPianistAVP
import Testing

@Test
func sequencerPlaybackServiceProtocolCarriesCanonicalCommandsAcrossActorBoundary() async throws {
    actor FakeSequencerPlaybackService: PracticeSequencerPlaybackServiceProtocol {
        private(set) var resetCommands: [PerformanceTransportCommand] = []
        private(set) var commands: [PracticePlaybackCommand] = []

        func warmUp() async throws {}
        func stop(resetCommands: [PerformanceTransportCommand]) async {
            self.resetCommands = resetCommands
        }
        func load(sequence _: PracticeSequencerSequence) async throws {}
        func play(fromSeconds _: TimeInterval) async throws {}
        func currentSeconds() async -> TimeInterval {
            0
        }

        func playOneShot(commands _: [PracticePlaybackCommand], durationSeconds _: TimeInterval) async throws {}
        func execute(commands: [PracticePlaybackCommand]) async throws {
            self.commands.append(contentsOf: commands)
        }
        func stopAllLiveNotes() async {}

        func snapshot() -> (commands: [PracticePlaybackCommand], reset: [PerformanceTransportCommand]) {
            (commands, resetCommands)
        }
    }

    func accept(_ service: PracticeSequencerPlaybackServiceProtocol) {
        _ = service
    }

    let service = FakeSequencerPlaybackService()
    accept(service)
    let commands = [
        PracticePlaybackCommand(sourceEventID: "note-1", kind: .noteOn(midi: 60, velocity: 87)),
        PracticePlaybackCommand(sourceEventID: "pedal-1", kind: .controlChange(controller: 64, value: 96)),
    ]
    try await service.execute(commands: commands)
    await service.stop(resetCommands: PerformanceTransportReducer.fullResetCommands)

    let snapshot = await service.snapshot()
    #expect(snapshot.commands == commands)
    #expect(snapshot.reset == PerformanceTransportReducer.fullResetCommands)
}
