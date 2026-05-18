import Foundation

protocol PracticeInputEventSourceProtocol: AnyObject {
    func eventsStream() -> AsyncStream<PracticeInputEvent>

    func start() throws
    func stop()
}

protocol ProtocolSeparatedPracticeInputEventSourceProtocol: AnyObject {
    func midi1EventsStream() -> AsyncStream<MIDI1InputEvent>
    func midi2EventsStream() -> AsyncStream<MIDI2InputEvent>

    func start() throws
    func stop()
}
