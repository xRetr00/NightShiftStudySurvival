import AVFoundation
import AudioToolbox
import Foundation
import UIKit

@MainActor
final class AlarmFeedbackService {
    static let shared = AlarmFeedbackService()

    private var beepPlayer: AVAudioPlayer?
    private var soundTimer: Timer?
    private var hapticTimer: Timer?

    private init() {}

    func start(
        sound: SoundProfile,
        haptics: HapticPattern,
        strongHapticsEnabled: Bool,
        soundStyle: String,
        loudnessProfile: String
    ) {
        stop()

        configureAudioSession()
        startSoundLoop(for: sound, style: soundStyle, loudnessProfile: loudnessProfile)
        startHapticPulse(pattern: haptics, enabled: strongHapticsEnabled)
    }

    func stop() {
        soundTimer?.invalidate()
        soundTimer = nil
        hapticTimer?.invalidate()
        hapticTimer = nil

        beepPlayer?.stop()
        beepPlayer = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)
    }

    private func startSoundLoop(for profile: SoundProfile, style: String, loudnessProfile: String) {
        if loadAndPlayBundledSound(profile: profile, style: style, loudnessProfile: loudnessProfile) {
            return
        }

        // Fallback to system sound pulses when bundled assets are not present.
        AudioServicesPlaySystemSound(1106)

        let interval = soundPulseInterval(for: profile)
        soundTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            AudioServicesPlaySystemSound(1106)
        }
    }

    private func loadAndPlayBundledSound(profile: SoundProfile, style: String, loudnessProfile: String) -> Bool {
        let resource = soundResourceName(profile: profile, style: style)
        guard let url = Bundle.main.url(forResource: resource, withExtension: "wav") else {
            return false
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = volume(for: loudnessProfile)
            player.prepareToPlay()
            player.play()
            beepPlayer = player
            return true
        } catch {
            return false
        }
    }

    private func soundResourceName(profile: SoundProfile, style: String) -> String {
        let styleKey = style.lowercased().replacingOccurrences(of: " ", with: "_")
        return "alarm_\(styleKey)_\(profile.rawValue.lowercased())"
    }

    private func volume(for loudnessProfile: String) -> Float {
        switch loudnessProfile.lowercased() {
        case "low":
            return 0.4
        case "medium":
            return 0.65
        case "max":
            return 1.0
        default:
            return 0.85
        }
    }

    private func startHapticPulse(pattern: HapticPattern, enabled: Bool) {
        guard enabled else { return }

        let interval = hapticInterval(for: pattern)
        hapticTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            let generator = UINotificationFeedbackGenerator()
            switch pattern {
            case .lightPulse:
                generator.notificationOccurred(.success)
            case .mediumDoubleTap:
                generator.notificationOccurred(.warning)
            case .strongPulse, .rampBurst, .criticalLongPulse:
                generator.notificationOccurred(.error)
            case .none:
                break
            }
        }
    }

    private func soundPulseInterval(for profile: SoundProfile) -> TimeInterval {
        switch profile {
        case .gentleLoop:
            return 20
        case .standardLoop:
            return 8
        case .loudFastLoop:
            return 4
        case .aggressiveAlternating:
            return 2
        case .emergencyMax:
            return 1
        case .mathLockUrgent:
            return 2
        case .silent:
            return 60
        }
    }

    private func hapticInterval(for pattern: HapticPattern) -> TimeInterval {
        switch pattern {
        case .lightPulse:
            return 10
        case .mediumDoubleTap:
            return 5
        case .strongPulse:
            return 3
        case .rampBurst:
            return 2
        case .criticalLongPulse:
            return 1
        case .none:
            return 60
        }
    }
}
