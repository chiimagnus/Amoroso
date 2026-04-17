import Foundation

protocol PianoCalibrationStoreProtocol {
    func load() throws -> PianoCalibration?
    func save(_ calibration: PianoCalibration) throws
}

enum PianoCalibrationStoreError: Error {
    case documentsUnavailable
}

struct PianoCalibrationStore: PianoCalibrationStoreProtocol {
    private let fileManager: FileManager
    private let fileName: String

    init(fileManager: FileManager = .default, fileName: String = "piano-calibration.json") {
        self.fileManager = fileManager
        self.fileName = fileName
    }

    func load() throws -> PianoCalibration? {
        let fileURL = try calibrationFileURL()
        guard fileManager.fileExists(atPath: fileURL.path()) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(PianoCalibration.self, from: data)
    }

    func save(_ calibration: PianoCalibration) throws {
        let fileURL = try calibrationFileURL()
        let data = try JSONEncoder().encode(calibration)
        try data.write(to: fileURL, options: .atomic)
    }

    private func calibrationFileURL() throws -> URL {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw PianoCalibrationStoreError.documentsUnavailable
        }
        return documents.appendingPathComponent(fileName)
    }
}
