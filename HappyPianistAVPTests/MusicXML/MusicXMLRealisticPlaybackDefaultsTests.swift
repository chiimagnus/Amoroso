@testable import HappyPianistAVP
import Testing

@Test
func musicXMLRealisticPlaybackDefaultsAreHardcodedForNoSettingsSwitches() {
    let expressivity = MusicXMLRealisticPlaybackDefaults.expressivityOptions

    #expect(MusicXMLRealisticPlaybackDefaults.practiceScoreOrder == .written)
    #expect(MusicXMLRealisticPlaybackDefaults.referencePlaybackScoreOrder == .performed)
    #expect(PracticePreparationOptions.practice.scoreOrder == .written)
    #expect(PracticePreparationOptions.referencePlayback.scoreOrder == .performed)
    #expect(MusicXMLRealisticPlaybackDefaults.performanceTimingEnabled == true)
    #expect(expressivity.wedgeEnabled == true)
    #expect(expressivity.graceEnabled == true)
    #expect(expressivity.fermataEnabled == true)
    #expect(expressivity.arpeggiateEnabled == true)
    #expect(expressivity.wordsSemanticsEnabled == true)
}

// Grep gate for local/CI regression checks:
// rg -n 'UserDefaults\.standard\.bool\(forKey:
