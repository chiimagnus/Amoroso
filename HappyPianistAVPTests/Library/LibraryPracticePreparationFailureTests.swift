import Foundation
@testable import HappyPianistAVP
import Testing

@Test(arguments: [
    (PracticePreparationError.scoreFileNotFound, DiagnosticCode.practiceScoreFileNotFound, "找不到曲谱文件"),
    (PracticePreparationError.invalidMXLArchive, DiagnosticCode.practiceMXLInvalidArchive, "压缩曲谱已损坏"),
    (PracticePreparationError.missingMXLContainer, DiagnosticCode.practiceMXLMissingContainer, "压缩曲谱缺少入口文件"),
    (PracticePreparationError.missingMXLRootfile, DiagnosticCode.practiceMXLMissingRootfile, "压缩曲谱没有指定主曲谱"),
    (PracticePreparationError.invalidMXLContainer, DiagnosticCode.practiceMXLInvalidContainer, "压缩曲谱入口文件无效"),
    (PracticePreparationError.noPlayableNotes, DiagnosticCode.practiceNoPlayableNotes, "曲谱中没有可练习的音符"),
    (PracticePreparationError.missingMeasureStructure, DiagnosticCode.practiceMissingMeasureStructure, "曲谱的小节结构不完整"),
])
func preparationFailuresMapToConcretePresentation(
    error: PracticePreparationError,
    code: DiagnosticCode,
    title: String
) throws {
    let file = try #require(
        DiagnosticFileReference(
            fileName: "example.musicxml",
            relativePath: "SongLibrary/scores/example.musicxml"
        )
    )

    let failure = LibraryPracticePreparationFailure.map(
        error,
        entryID: UUID(),
        file: file
    )

    #expect(failure.code == code)
    #expect(failure.title == title)
    #expect(failure.technicalDetails.contains("relativePath: SongLibrary/scores/example.musicxml"))
    #expect(failure.technicalDetails.contains("/Users/") == false)
}

@Test
func xmlPreparationFailurePreservesParserLocation() throws {
    let file = try #require(
        DiagnosticFileReference(
            fileName: "broken.musicxml",
            relativePath: "SongLibrary/scores/broken.musicxml"
        )
    )
    let failure = LibraryPracticePreparationFailure.map(
        .xmlParseFailed(line: 42, column: 7, reason: "tag mismatch"),
        entryID: UUID(),
        file: file
    )

    #expect(failure.code == .practiceXMLParseFailed)
    #expect(failure.sourceLocation == DiagnosticSourceLocation(line: 42, column: 7))
    #expect(failure.technicalDetails.contains("line: 42"))
    #expect(failure.technicalDetails.contains("column: 7"))
}

@Test
func missingMXLScoreIncludesOnlyArchiveRelativePath() throws {
    let file = try #require(
        DiagnosticFileReference(
            fileName: "broken.mxl",
            relativePath: "SongLibrary/scores/broken.mxl"
        )
    )
    let failure = LibraryPracticePreparationFailure.map(
        .missingMXLScore(path: "scores/main.musicxml"),
        entryID: UUID(),
        file: file
    )

    #expect(failure.code == .practiceMXLMissingScore)
    #expect(failure.reason.contains("scores/main.musicxml"))
}
