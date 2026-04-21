import Foundation
import Testing
@testable import LonelyPianistAVP

@Test
func bundledSampleScoreResourcesExistAndParse() throws {
    let bundle = Bundle(for: AppModel.self)
    let subdirectory = "Resources/SampleScores/坂本龙一"

    let musicXMLFileName = "Opus – Ryuichi Sakamoto (Piano Transcription).musicxml"
    let pdfFileName = "Opus – Ryuichi Sakamoto (Piano Transcription).pdf"
    let mp3FileName = "Opus – Ryuichi Sakamoto (Piano Transcription).mp3"

    let musicXMLURL = bundle.url(
        forResource: musicXMLFileName,
        withExtension: nil,
        subdirectory: subdirectory
    ) ?? bundle.url(forResource: musicXMLFileName, withExtension: nil)
    #expect(musicXMLURL != nil)

    let pdfURL = bundle.url(forResource: pdfFileName, withExtension: nil, subdirectory: subdirectory)
        ?? bundle.url(forResource: pdfFileName, withExtension: nil)
    #expect(pdfURL != nil)

    let mp3URL = bundle.url(forResource: mp3FileName, withExtension: nil, subdirectory: subdirectory)
        ?? bundle.url(forResource: mp3FileName, withExtension: nil)
    #expect(mp3URL != nil)

    guard let musicXMLURL else { return }
    let score = try MusicXMLParser().parse(fileURL: musicXMLURL)
    let buildResult = PracticeStepBuilder().buildSteps(from: score)
    #expect(buildResult.steps.isEmpty == false)
}
