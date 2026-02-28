//
//  AudioSessionManager.swift
//  FullFitness
//
//  Created by Copilot on 16/2/2026.
//

import AVFoundation

class AudioSessionManager {
    static let shared = AudioSessionManager()

    private enum SessionTransition {
        case none
        case activate
        case deactivate
    }

    private final class AudioSessionCoordinator {
        private let queue = DispatchQueue(label: "com.stufit.audio-session-coordinator")
        private var activeRequestCount = 0
        private var isSessionActive = false

        func acquire() -> SessionTransition {
            queue.sync {
                activeRequestCount += 1
                guard !isSessionActive else { return .none }
                isSessionActive = true
                return .activate
            }
        }

        func release() -> SessionTransition {
            queue.sync {
                guard activeRequestCount > 0 else { return .none }
                activeRequestCount -= 1
                guard activeRequestCount == 0, isSessionActive else { return .none }
                isSessionActive = false
                return .deactivate
            }
        }

        func forceReleaseAll() -> SessionTransition {
            queue.sync {
                activeRequestCount = 0
                guard isSessionActive else { return .none }
                isSessionActive = false
                return .deactivate
            }
        }

        func hasPendingRequests() -> Bool {
            queue.sync {
                activeRequestCount > 0
            }
        }
    }
    
    private let audioSession = AVAudioSession.sharedInstance()
    private let coordinator = AudioSessionCoordinator()

    var onInterruptionBegan: (() -> Void)?
    var onInterruptionEnded: ((_ shouldResume: Bool) -> Void)?
    
    private init() {
        setupAudioSession()
        registerAudioSessionObservers()
    }
    
    /// Configure the audio session for fitness coaching
    /// This pauses podcasts and other background audio when we need to play sounds
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.interruptSpokenAudioAndMixWithOthers, .duckOthers]
            )
        } catch {
            print("Failed to set audio session category: \(error.localizedDescription)")
        }
    }

    private func registerAudioSessionObservers() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )
        center.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession
        )
    }
    
    /// Request audio focus for transient speech prompts.
    func requestSpeechFocus() {
        let transition = coordinator.acquire()
        guard transition == .activate else { return }

        do {
            try audioSession.setActive(true)
            print("Audio session activated for coaching speech")
        } catch {
            print("Failed to activate audio session: \(error.localizedDescription)")
        }
    }
    
    /// Release audio focus after transient speech prompts complete.
    func releaseSpeechFocus() {
        let transition = coordinator.release()
        guard transition == .deactivate else { return }

        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("Audio session deactivated - external audio may resume")
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    @objc
    private func handleInterruption(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else {
            return
        }

        switch type {
        case .began:
            onInterruptionBegan?()
        case .ended:
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            let shouldResume = coordinator.hasPendingRequests() && options.contains(.shouldResume)
            onInterruptionEnded?(shouldResume)

            if !shouldResume {
                let transition = coordinator.forceReleaseAll()
                guard transition == .deactivate else { return }
                do {
                    try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                } catch {
                    print("Failed to deactivate after interruption: \(error.localizedDescription)")
                }
            }
        @unknown default:
            break
        }
    }

    @objc
    private func handleRouteChange(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable, .newDeviceAvailable, .override:
            if !coordinator.hasPendingRequests() {
                let transition = coordinator.forceReleaseAll()
                guard transition == .deactivate else { return }
                do {
                    try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                } catch {
                    print("Failed to deactivate after route change: \(error.localizedDescription)")
                }
            }
        default:
            break
        }
    }
}

// MARK: - Helper function to format plates for speech
func formatPlatesForSpeech(_ plates: [Double]) -> String {
    guard !plates.isEmpty else { return "bar only"  }
    
    var plateCount: [Double: Int] = [:]
    for plate in plates {
        plateCount[plate, default: 0] += 1
    }
    
    let formatted = plateCount
        .sorted { $0.key > $1.key }
        .map { plate, count in
            let plateString = plate == Double(Int(plate)) ? String(Int(plate)) : String(plate)
            return count > 1 ? "\(plateString) kg times \(count)" : "\(plateString) kg"
        }
        .joined(separator: ", ")
    
    return "each side: \(formatted)"
}
