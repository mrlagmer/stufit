//
//  AudioSessionManager.swift
//  FullFitness
//
//  Created by Copilot on 16/2/2026.
//

import AVFoundation

class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    private init() {
        setupAudioSession()
    }
    
    /// Configure the audio session for fitness coaching
    /// This pauses podcasts and other background audio when we need to play sounds
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.duckOthers, .defaultToSpeaker]
            )
        } catch {
            print("Failed to set audio session category: \(error.localizedDescription)")
        }
    }
    
    /// Activate the audio session before playing sounds
    /// This will pause any playing podcasts
    func activateAudioSession() {
        do {
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("Audio session activated - podcasts will be paused")
        } catch {
            print("Failed to activate audio session: \(error.localizedDescription)")
        }
    }
    
    /// Deactivate the audio session after sounds finish playing
    /// This allows podcasts to resume playback
    func deactivateAudioSession() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("Audio session deactivated - podcasts can resume")
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
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
