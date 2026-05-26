import Foundation
import AVFoundation
import AudioToolbox

/// Plays the alarm sound on a loop. Configures an AVAudioSession in the
/// `.playback` category so audio continues from background / lock screen
/// and overrides the hardware silent switch.
final class AudioService {
    static let shared = AudioService()

    private var player: AVAudioPlayer?
    private var fallbackTimer: Timer?
    private var isPlaying: Bool = false
    private var volumeObservation: NSKeyValueObservation?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    /// Configures the shared audio session and starts the looping alarm.
    /// Must be called when the app is in the foreground — the caller
    /// (`ActiveAlarmViewModel.startSession`) is reached only after the user
    /// taps the notification, which brings the app forward.
    func playAlarm() {
        guard !isPlaying else { return }

        do {
            // .playback overrides the silent switch; .default mode keeps things simple.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[AudioService] Failed to configure session: \(error)")
        }

        if let url = Bundle.main.url(forResource: "alarm", withExtension: "caf")
            ?? Bundle.main.url(forResource: "alarm", withExtension: "wav")
            ?? Bundle.main.url(forResource: "alarm", withExtension: "mp3") {
            do {
                let p = try AVAudioPlayer(contentsOf: url)
                p.numberOfLoops = -1
                p.volume = 1.0
                p.prepareToPlay()
                p.play()
                player = p
                isPlaying = true
                startVolumeObserver()
                return
            } catch {
                print("[AudioService] Player failed, falling back to system sound: \(error)")
            }
        }

        // Fallback — repeating system sound. Not perfect from background, but acceptable for MVP.
        isPlaying = true
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            AudioServicesPlayAlertSound(SystemSoundID(1005))
        }
        startVolumeObserver()
    }

    func stopAlarm() {
        stopVolumeObserver()
        player?.stop()
        player = nil
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    // MARK: - Volume observation

    /// Observe device output volume via KVO. There is no public
    /// `outputVolumeDidChangeNotification` on `AVAudioSession`, so KVO on the
    /// `outputVolume` property is the supported way to react to the user
    /// pressing the volume-down hardware buttons.
    private func startVolumeObserver() {
        guard volumeObservation == nil else { return }
        volumeObservation = AVAudioSession.sharedInstance().observe(
            \.outputVolume,
            options: [.new]
        ) { [weak self] _, change in
            guard let self, self.isPlaying else { return }
            let newVolume = change.newValue ?? AVAudioSession.sharedInstance().outputVolume
            guard newVolume < Constants.alarmMinVolume else { return }
            // Snap the player back to full volume — we cannot raise the device volume
            // programmatically, but this ensures the alarm uses every available decibel.
            DispatchQueue.main.async {
                self.player?.volume = 1.0
            }
        }
    }

    private func stopVolumeObserver() {
        volumeObservation?.invalidate()
        volumeObservation = nil
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
        else { return }

        switch type {
        case .began:
            player?.pause()
        case .ended:
            if let optionsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
                if options.contains(.shouldResume) {
                    player?.play()
                }
            }
        @unknown default:
            break
        }
    }
}
