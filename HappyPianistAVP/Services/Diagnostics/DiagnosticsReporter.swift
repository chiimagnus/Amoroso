import Foundation
import os

struct DiagnosticRecordResult: Equatable, Sendable {
    let persistedForExport: Bool
}

protocol DiagnosticsReporting: Sendable {
    @discardableResult
    func record(_ event: DiagnosticEvent) async -> DiagnosticRecordResult
}

protocol SystemDiagnosticsSinkProtocol: Sendable {
    func record(_ event: DiagnosticEvent)
}

struct OSLogDiagnosticsSink: SystemDiagnosticsSinkProtocol {
    private let subsystem: String

    init(subsystem: String = Bundle.main.bundleIdentifier ?? "HappyPianistAVP") {
        self.subsystem = subsystem
    }

    func record(_ event: DiagnosticEvent) {
        let logger = Logger(subsystem: subsystem, category: event.category.rawValue)
        let message = "[\(event.code.rawValue, privacy: .public)] \(event.summary, privacy: .public) | stage=\(event.stage, privacy: .public) | reason=\(event.reason, privacy: .private(mask: .hash))"
        switch event.severity {
        case .debug:
            logger.debug("\(message)")
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .error:
            logger.error("\(message)")
        }
    }
}

actor AppDiagnosticsReporter: DiagnosticsReporting {
    private let systemSink: any SystemDiagnosticsSinkProtocol
    private let exportStore: any DiagnosticsStoreProtocol

    init(
        systemSink: any SystemDiagnosticsSinkProtocol = OSLogDiagnosticsSink(),
        exportStore: any DiagnosticsStoreProtocol
    ) {
        self.systemSink = systemSink
        self.exportStore = exportStore
    }

    func record(_ event: DiagnosticEvent) async -> DiagnosticRecordResult {
        systemSink.record(event)
        guard event.persistence == .exportable else {
            return DiagnosticRecordResult(persistedForExport: false)
        }
        do {
            try await exportStore.append(event)
            return DiagnosticRecordResult(persistedForExport: true)
        } catch {
            let fallback = DiagnosticEvent(
                severity: .error,
                code: .diagnosticsStoreWriteFailed,
                category: .diagnostics,
                stage: "append",
                summary: "无法写入可导出的诊断日志",
                reason: String(describing: error),
                persistence: .systemOnly
            )
            systemSink.record(fallback)
            return DiagnosticRecordResult(persistedForExport: false)
        }
    }
}

actor InMemoryDiagnosticsReporter: DiagnosticsReporting {
    private(set) var events: [DiagnosticEvent] = []
    private let persistResult: Bool

    init(persistResult: Bool = true) {
        self.persistResult = persistResult
    }

    func record(_ event: DiagnosticEvent) -> DiagnosticRecordResult {
        events.append(event)
        return DiagnosticRecordResult(
            persistedForExport: event.persistence == .exportable && persistResult
        )
    }
}
