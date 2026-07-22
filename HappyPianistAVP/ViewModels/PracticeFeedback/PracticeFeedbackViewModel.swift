import Foundation
import Observation

@MainActor
@Observable
final class PracticeFeedbackViewModel {
    private let sleeper: any SleeperProtocol
    private var dismissalTask: Task<Void, Never>?
    private(set) var cue: PracticeFeedbackEvent?
    private(set) var coachingPresentation: PracticeCoachingPresentation?

    init(sleeper: any SleeperProtocol = TaskSleeper()) {
        self.sleeper = sleeper
    }

    func present(
        _ event: PracticeFeedbackEvent?,
        coachingDecision: CoachingDecision? = nil
    ) {
        dismissalTask?.cancel()
        guard let event else {
            cue = nil
            coachingPresentation = nil
            return
        }
        cue = event
        coachingPresentation = coachingDecision.flatMap(Self.presentation)
        dismissalTask = Task { [weak self, sleeper] in
            try? await sleeper.sleep(for: .seconds(3))
            guard Task.isCancelled == false else { return }
            self?.cue = nil
            self?.coachingPresentation = nil
        }
    }

    func cancel() {
        dismissalTask?.cancel()
        dismissalTask = nil
        cue = nil
        coachingPresentation = nil
    }

    private static func presentation(for decision: CoachingDecision) -> PracticeCoachingPresentation? {
        var sourceLabels: [String] = []
        if let hand = decision.action.handFocus,
           let label = handSourceLabel(hand)
        {
            sourceLabels.append("手部依据：\(label)")
        }
        let fingeringSources = Set(decision.action.fingerings.map(\.provenance))
        let orderedFingeringLabels: [(MusicXMLFingeringProvenance, String)] = [
            (.score, "原谱"),
            (.teacher, "教师"),
            (.user, "你的确认"),
        ]
        let fingeringLabels = orderedFingeringLabels.compactMap { source, label in
            fingeringSources.contains(source) ? label : nil
        }
        if fingeringLabels.isEmpty == false {
            sourceLabels.append("指法依据：\(fingeringLabels.joined(separator: "、"))")
        }
        guard sourceLabels.isEmpty == false else { return nil }
        return PracticeCoachingPresentation(
            sourceLabel: sourceLabels.joined(separator: "；"),
            fingeringText: decision.action.fingerings.fingeringDisplayText
        )
    }

    private static func handSourceLabel(_ assignment: ScoreHandAssignment) -> String? {
        switch assignment.provenance {
        case .score:
            "原谱"
        case .teacher:
            "教师"
        case .user:
            "你的确认"
        case .heuristic:
            assignment.confidence.map {
                "推测（\($0.formatted(.percent.precision(.fractionLength(0))))）"
            } ?? "推测"
        case .unresolved:
            nil
        }
    }
}
