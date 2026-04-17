import Foundation

protocol OMRConversionServiceProtocol {
    func convert(inputURL: URL) throws -> URL
}

enum OMRConversionError: LocalizedError {
    case serverDirectoryNotFound
    case pythonInterpreterNotFound(URL)
    case conversionFailed(String)
    case outputPathMissing

    var errorDescription: String? {
        switch self {
        case .serverDirectoryNotFound:
            return "OMR server directory not found. Set LONELY_PIANIST_OMR_SERVER_DIR or run from repository root."
        case .pythonInterpreterNotFound(let url):
            return "Python interpreter not found at \(url.path)."
        case .conversionFailed(let message):
            return message
        case .outputPathMissing:
            return "Conversion succeeded but output path was not found in converter output."
        }
    }
}

struct OMRConversionService: OMRConversionServiceProtocol {
    private let fileManager: FileManager
    private let environment: [String: String]

    init(fileManager: FileManager = .default, environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.fileManager = fileManager
        self.environment = environment
    }

    func convert(inputURL: URL) throws -> URL {
        let serverDirectory = try resolveServerDirectory()
        let pythonPath = serverDirectory.appendingPathComponent(".venv/bin/python")
        guard fileManager.fileExists(atPath: pythonPath.path) else {
            throw OMRConversionError.pythonInterpreterNotFound(pythonPath)
        }

        let process = Process()
        process.executableURL = pythonPath
        process.currentDirectoryURL = serverDirectory
        process.arguments = ["-m", "omr.cli", "--input", inputURL.path]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw OMRConversionError.conversionFailed(stderr.isEmpty ? stdout : stderr)
        }

        let outputPath = stdout
            .split(separator: "\n")
            .first(where: { $0.hasPrefix("musicxml_path=") })
            .map { String($0.dropFirst("musicxml_path=".count)) }

        guard let outputPath else {
            throw OMRConversionError.outputPathMissing
        }

        return URL(fileURLWithPath: outputPath)
    }

    private func resolveServerDirectory() throws -> URL {
        if let explicit = environment["LONELY_PIANIST_OMR_SERVER_DIR"] {
            let url = URL(fileURLWithPath: explicit)
            if fileManager.fileExists(atPath: url.path) {
                return url
            }
        }

        let cwdCandidate = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .appendingPathComponent("piano_dialogue_server")
        if fileManager.fileExists(atPath: cwdCandidate.path) {
            return cwdCandidate
        }

        throw OMRConversionError.serverDirectoryNotFound
    }
}
