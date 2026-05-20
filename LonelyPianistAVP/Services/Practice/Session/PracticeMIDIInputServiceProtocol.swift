protocol PracticeMIDIInputServiceProtocol: AnyObject {
    func refresh(context: PracticeInputRefreshContext)
    func stop()
}
