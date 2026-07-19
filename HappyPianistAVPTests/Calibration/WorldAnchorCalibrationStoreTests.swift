import Foundation
@testable import HappyPianistAVP
import Testing

@Test
func storedWorldAnchorCalibrationSupportsCodableRoundTrip() throws {
    let calibration = try StoredWorldAnchorCalibration(
        a0AnchorID: #require(UUID(uuidString: "11111111-2222-3333-4444-555555555555")),
        c8AnchorID: #require(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")),
        whiteKeyWidth: 0.031,
        touchCalibration: PianoModeTouchCalibrationService.conservativeDefault(for: .realAudio),
        generatedAt: Date(timeIntervalSince1970: 1_735_689_600)
    )

    let encoded = try JSONEncoder().encode(calibration)
    let decoded = try JSONDecoder().decode(StoredWorldAnchorCalibration.self, from: encoded)

    #expect(decoded == calibration)
}

@Test
func storedWorldAnchorCalibrationRejectsLegacyPayloadWithoutTouchCalibration() throws {
    let legacyJSON = Data(
        #"{"a0AnchorID":"11111111-2222-3333-4444-555555555555","c8AnchorID":"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE","whiteKeyWidth":0.031,"generatedAt":0}"#.utf8
    )

    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(StoredWorldAnchorCalibration.self, from: legacyJSON)
    }
}

@Test
func worldAnchorCalibrationStoreReturnsNilWhenFileMissing() throws {
    let tempDirectory = try makeTemporaryDocumentsDirectory()
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let fileManager = TestDocumentsFileManager(documentsURL: tempDirectory)
    let store = WorldAnchorCalibrationStore(
        fileManager: fileManager,
        fileName: "missing-\(UUID().uuidString).json"
    )

    let loaded = try store.load()
    #expect(loaded == nil)
}

@Test
func worldAnchorCalibrationStoreCanSaveAndLoadRoundTrip() throws {
    let tempDirectory = try makeTemporaryDocumentsDirectory()
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let fileManager = TestDocumentsFileManager(documentsURL: tempDirectory)
    let store = WorldAnchorCalibrationStore(
        fileManager: fileManager,
        fileName: "world-anchor-calibration.json"
    )

    let calibration = try StoredWorldAnchorCalibration(
        a0AnchorID: #require(UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF")),
        c8AnchorID: #require(UUID(uuidString: "FEDCBA98-7654-3210-FEDC-BA9876543210")),
        whiteKeyWidth: 0.027,
        touchCalibration: PianoModeTouchCalibrationService.conservativeDefault(for: .realAudio),
        generatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    try store.save(calibration)
    let loaded = try store.load()

    #expect(loaded == calibration)
}

private func makeTemporaryDocumentsDirectory() throws -> URL {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appending(
            path: "WorldAnchorCalibrationStoreTests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    return tempDirectory
}

private final class TestDocumentsFileManager: FileManager {
    private let documentsURL: URL

    init(documentsURL: URL) {
        self.documentsURL = documentsURL
        super.init()
    }

    override func urls(for directory: SearchPathDirectory, in domainMask: SearchPathDomainMask) -> [URL] {
        if directory == .documentDirectory {
            return [documentsURL]
        }
        return super.urls(for: directory, in: domainMask)
    }
}

@Test
func worldAnchorCalibrationStoreQuarantinesCorruptFileAndAllowsRecalibration() throws {
    let tempDirectory = try makeTemporaryDocumentsDirectory()
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let fileManager = TestDocumentsFileManager(documentsURL: tempDirectory)
    let fileName = "world-anchor-calibration.json"
    let store = WorldAnchorCalibrationStore(fileManager: fileManager, fileName: fileName)
    let fileURL = tempDirectory.appending(path: fileName)
    let corruptData = Data("{not-json".utf8)
    try corruptData.write(to: fileURL)

    #expect(try store.load() == nil)
    #expect(fileManager.fileExists(atPath: fileURL.path()) == false)

    let quarantinedURLs = try fileManager.contentsOfDirectory(
        at: tempDirectory,
        includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.hasPrefix("world-anchor-calibration.corrupt-") }
    #expect(quarantinedURLs.count == 1)
    #expect(try Data(contentsOf: #require(quarantinedURLs.first)) == corruptData)

    let replacement = try StoredWorldAnchorCalibration(
        a0AnchorID: #require(UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF")),
        c8AnchorID: #require(UUID(uuidString: "FEDCBA98-7654-3210-FEDC-BA9876543210")),
        whiteKeyWidth: 0.027,
        touchCalibration: PianoModeTouchCalibrationService.conservativeDefault(for: .realAudio),
        generatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    try store.save(replacement)
    #expect(try store.load() == replacement)
}
