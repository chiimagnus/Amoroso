protocol PracticeAudioRecognitionInputServiceProtocol: AnyObject {
    func refresh(context: PracticeInputRefreshContext)
    func stop()
}
