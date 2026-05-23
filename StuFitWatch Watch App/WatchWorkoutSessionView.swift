//
//  WatchWorkoutSessionView.swift
//  StuFitWatch Watch App
//
//  Created by Kiro on 16/3/2026.
//

import SwiftUI
import WatchConnectivity

struct WatchWorkoutSessionView: View {
    @EnvironmentObject private var watchSessionManager: WatchSessionManager
    
    var body: some View {
        VStack(spacing: 0) {
            if watchSessionManager.isResting {
                restView
            } else {
                nextSetView
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    // MARK: - Rest View
    private var restView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Total workout time at top
                Text(totalTimeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()

                // Large rest timer
                VStack(spacing: 8) {
                    Text("REST")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .tracking(2)

                    Text(watchSessionManager.restTimeString)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                }

                // Next set info
                if let nextLabel = watchSessionManager.nextSetLabel {
                    VStack(spacing: 4) {
                        Text("NEXT")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .tracking(1)

                        if let nextExercise = watchSessionManager.nextExerciseName,
                           nextExercise != watchSessionManager.exerciseName {
                            Text(nextExercise)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }

                        Text(nextLabel)
                            .font(.caption)
                            .fontWeight(.semibold)

                        if let weight = watchSessionManager.nextSetWeight {
                            Text(String(format: "%.1f kg", weight))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.accentColor)
                        }

                        if let platesDesc = watchSessionManager.nextSetPlatesDescription, !platesDesc.isEmpty {
                            Text(platesDesc)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }

                // Skip rest button
                Button(action: { watchSessionManager.skipRest() }) {
                    Text("Skip Rest")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color.orange.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Next Set View (after rest)
    private var nextSetView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Total workout time at top
                Text(totalTimeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()

                // Current set info
                VStack(spacing: 8) {
                    Text(watchSessionManager.currentSetLabel)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(watchSessionManager.platesDescription)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                // Action buttons
                VStack(spacing: 10) {
                    Button(action: { watchSessionManager.completeSet(didFail: false) }) {
                        Text("Complete")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(.black)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    if !watchSessionManager.isWarmupSet {
                        Button(action: { watchSessionManager.completeSet(didFail: true) }) {
                            Text("Failed")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundColor(.white)
                                .background(Color.red.opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Helpers
    private var totalTimeString: String {
        let minutes = Int(watchSessionManager.elapsedTime) / 60
        let seconds = Int(watchSessionManager.elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    WatchWorkoutSessionView()
}
