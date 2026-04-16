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
    private var previewStopWorkItem: DispatchWorkItem?
    private let supportedExtensions = ["wav", "mp3", "m4a", "caf", "aiff"]

    private init() {}

    func start(
        sound: SoundProfile,
        haptics: HapticPattern,
        strongHapticsEnabled: Bool,
        soundStyle: String,
        loudnessProfile: String,
        preferredWebSoundName: String? = nil,
        webSoundOnly: Bool = false
    ) {
        stop()

        configureAudioSession()
        startSoundLoop(
            for: sound,
            style: soundStyle,
            loudnessProfile: loudnessProfile,
            preferredWebSoundName: preferredWebSoundName,
            webSoundOnly: webSoundOnly
        )
        startHapticPulse(pattern: haptics, enabled: strongHapticsEnabled)
    }

    func preview(style: String, loudnessProfile: String, webSoundName: String? = nil) {
        start(
            sound: .emergencyMax,
            haptics: .none,
            strongHapticsEnabled: false,
            soundStyle: style,
            loudnessProfile: loudnessProfile,
            preferredWebSoundName: webSoundName,
            webSoundOnly: webSoundName != nil
        )

        let stopItem = DispatchWorkItem { [weak self] in
            self?.stop()
        }
        previewStopWorkItem?.cancel()
        previewStopWorkItem = stopItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: stopItem)
    }

    func stop() {
        previewStopWorkItem?.cancel()
        previewStopWorkItem = nil

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

    private func startSoundLoop(
        for profile: SoundProfile,
        style: String,
        loudnessProfile: String,
        preferredWebSoundName: String?,
        webSoundOnly: Bool
    ) {
        if let preferredWebSoundName,
           loadAndPlayResource(named: preferredWebSoundName, volume: 1.0) {
            return
        }

        if webSoundOnly {
            AudioServicesPlaySystemSound(1106)
            soundTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                AudioServicesPlaySystemSound(1106)
            }
            return
        }

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
        return loadAndPlayResource(named: resource, volume: volume(for: loudnessProfile))
    }

    private func loadAndPlayResource(named resource: String, volume: Float) -> Bool {
        for ext in supportedExtensions {
            guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
                continue
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = -1
                player.volume = volume
                player.prepareToPlay()
                player.play()
                beepPlayer = player
                return true
            } catch {
                continue
            }
        }

        return false
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
