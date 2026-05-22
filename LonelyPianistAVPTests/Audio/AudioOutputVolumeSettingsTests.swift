import Foundation
@testable import LonelyPianistAVP
import Testing

struct AudioOutputVolumeSettingsTests {
    @Test func defaultIsOneWhenUnset() {
        let suiteName = "AudioOutputVolumeSettingsTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        #expect(AudioOutputVolumeSettings.readAudioOutputVolume(from: userDefaults) == 1.0)
    }

    @Test func clampsBelowZeroToZero() {
        let suiteName = "AudioOutputVolumeSettingsTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        userDefaults.set(-0.1, forKey: AudioOutputVolumeSettings.userDefaultsKey)
        #expect(AudioOutputVolumeSettings.readAudioOutputVolume(from: userDefaults) == 0.0)
    }

    @Test func clampsAboveOneToOne() {
        let suiteName = "AudioOutputVolumeSettingsTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        userDefaults.set(1.1, forKey: AudioOutputVolumeSettings.userDefaultsKey)
        #expect(AudioOutputVolumeSettings.readAudioOutputVolume(from: userDefaults) == 1.0)
    }

    @Test func nonFiniteFallsBackToDefault() {
        let suiteName = "AudioOutputVolumeSettingsTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        userDefaults.set(Double.nan, forKey: AudioOutputVolumeSettings.userDefaultsKey)
        #expect(AudioOutputVolumeSettings.readAudioOutputVolume(from: userDefaults) == 1.0)
    }
}

