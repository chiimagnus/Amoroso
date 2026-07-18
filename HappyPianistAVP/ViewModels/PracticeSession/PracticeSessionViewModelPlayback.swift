import Foundation

extension PracticeSessionViewModel {
    func startAutoplayTaskIfNeeded() {
        playbackControlService?.startAutoplayTaskIfNeeded()
    }

    func stopAutoplayTask() {
        playbackControlService?.stopAutoplayTask()
    }

    func smoothNotationScrollTick() -> Double? {
        playbackControlService?.smoothNotationScrollTick()
    }

    func rebuildAutoplayTimeline() {
        cancelAutoplayTimelineBuild()
        guard
            self.stateStore.isActiveRangeInvalid == false,
            let performancePlan = self.performancePlan
        else {
            self.autoplayTimeline = .empty
            return
        }

        self.autoplayTimeline = .empty
        let generation = autoplayTimelineBuildGeneration
        let guideProjection = self.highlightGuides
        let stepProjection = self.steps
        let tempoMap = self.tempoMap
        let handMode = self.practiceHandMode
        let activeRange = self.activeRange
        autoplayTimelineBuildTask = Task { @MainActor [weak self] in
            let timeline = await AutoplayPerformanceTimeline.buildOffMain(
                plan: performancePlan,
                guideProjection: guideProjection,
                stepProjection: stepProjection,
                tempoMap: tempoMap,
                practiceHandMode: handMode,
                activeRange: activeRange
            )
            guard let self,
                  Task.isCancelled == false,
                  self.autoplayTimelineBuildGeneration == generation
            else { return }
            self.autoplayTimeline = timeline
            self.autoplayTimelineBuildTask = nil
        }
    }

    func cancelAutoplayTimelineBuild() {
        autoplayTimelineBuildGeneration &+= 1
        autoplayTimelineBuildTask?.cancel()
        autoplayTimelineBuildTask = nil
    }

    func startManualReplay(with plan: ManualReplayPlan) {
        stopVirtualPianoInput()
        manualReplayService?.startManualReplay(with: plan)
    }

    func stopManualReplayTask(restoreAudioRecognition: Bool = true) {
        manualReplayService?.stopManualReplayTask(restoreAudioRecognition: restoreAudioRecognition)
    }
}
