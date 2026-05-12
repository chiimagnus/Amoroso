import Foundation

enum MIDISourceMonitoringConnectionState: Sendable, Equatable {
    case idle
    case connected(sourceCount: Int)
    case failed(message: String)
}

protocol MIDISourceMonitoringServiceProtocol: AnyObject {
    var onConnectionStateChange: (@Sendable (MIDISourceMonitoringConnectionState) -> Void)? { get set }
    var onSourceNamesChange: (@Sendable ([String]) -> Void)? { get set }
    var onLastErrorMessageChange: (@Sendable (String?) -> Void)? { get set }

    func start() throws
    func stop()
    func refreshSources() throws
}
