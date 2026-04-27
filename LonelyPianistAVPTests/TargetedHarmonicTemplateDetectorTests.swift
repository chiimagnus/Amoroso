import Testing
@testable import LonelyPianistAVP
import Foundation

struct TargetedHarmonicTemplateDetectorTests {
    @Test func harmonicSignalProducesExpectedEvent() throws {
        let samples = SyntheticAudioFixtures.harmonic(midiNote: 60)
        let spectrum = try VDSPAudioSpectrumAnalyzer().analyze(samples: samples, sampleRate: 48_000, timestamp: .now)
        let frame = TargetedHarmonicTemplateDetector().detect(spectrumFrame: spectrum, expectedMIDINotes: [60], wrongCandidateMIDINotes: [61], generation: 3, suppressing: false, requestedMode: .harmonicTemplate, profile: .lowLatencyDefault)
        #expect(frame.templateMatchResults.contains { $0.midiNote == 60 && $0.role == .expected })
    }

    @Test func suppressWindowBlocksEventsButKeepsDebugResults() throws {
        let samples = SyntheticAudioFixtures.harmonic(midiNote: 60)
        let spectrum = try VDSPAudioSpectrumAnalyzer().analyze(samples: samples, sampleRate: 48_000, timestamp: .now)
        let frame = TargetedHarmonicTemplateDetector().detect(spectrumFrame: spectrum, expectedMIDINotes: [60], wrongCandidateMIDINotes: [61], generation: 3, suppressing: true, requestedMode: .harmonicTemplate, profile: .lowLatencyDefault)
        #expect(frame.events.isEmpty)
        #expect(frame.templateMatchResults.isEmpty == false)
    }
}
