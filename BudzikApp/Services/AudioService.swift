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

    /// Near-silent player kept alive while an alarm is scheduled. Holds the
    /// `audio` background mode so `UNUserNotificationCenter` + `CMPedometer`
    /// continue to fire reliably on a locked device.
    private var silentPlayer: AVAudioPlayer?
    private var isPlayingSilent: Bool = false

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
        if !isPlayingSilent {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    // MARK: - Silent background keep-alive

    /// Starts a near-silent looping playback so iOS keeps the app's audio
    /// session active in the background. Uses `.mixWithOthers` so the user's
    /// music / podcasts continue uninterrupted while an alarm is pending.
    func startSilentBackgroundAudio() {
        guard !isPlayingSilent else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[AudioService] Failed to configure silent session: \(error)")
            return
        }

        guard let url = Bundle.main.url(forResource: "alarm", withExtension: "caf")
            ?? Bundle.main.url(forResource: "alarm", withExtension: "wav")
            ?? Bundle.main.url(forResource: "alarm", withExtension: "mp3")
        else {
            print("[AudioService] Silent keep-alive: no alarm asset found")
            return
        }

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = 0.01
            p.prepareToPlay()
            p.play()
            silentPlayer = p
            isPlayingSilent = true
        } catch {
            print("[AudioService] Silent player failed: \(error)")
        }
    }

    func stopSilentBackgroundAudio() {
        silentPlayer?.stop()
        silentPlayer = nil
        isPlayingSilent = false
        if !isPlaying {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
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
