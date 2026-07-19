import Foundation
import simd

@MainActor
final class KeyContactDetectionService {
    let calibration: PianoTouchCalibration
    private var tracker = PianoKeyContactTracker()

    init(
        calibration: PianoTouchCalibration = PianoModeTouchCalibrationService.conservativeDefault(
            for: .virtualPiano
        )
    ) {
        self.calibration = calibration
    }

    func reset() {
        tracker.reset()
    }

    func detect(
        fingerTips: FingerTipsSnapshot,
        keyboardGeometry: PianoKeyboardGeometry,
        at timestamp: PerformanceMonotonicInstant
    ) -> [PianoKeyContactObservation] {
        tracker.detect(
            fingerTips: fingerTips,
            keyboardGeometry: keyboardGeometry,
            at: timestamp,
            pressThresholdMeters: calibration.planeOffsetMeters,
            releaseThresholdMeters: calibration.releaseThresholdMeters,
            retriggerDebounceSeconds: calibration.retriggerDebounceSeconds
        )
    }
}
