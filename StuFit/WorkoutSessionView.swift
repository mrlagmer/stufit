//
//  WorkoutSessionView.swift
//  FullFitness
//
//  Created by Copilot on 31/1/2026.
//

import AVFoundation
import FoundationModels
import SwiftUI
import UIKit
import UserNotifications

struct WorkoutSessionView: View {
    private struct SessionSetResult {
        let setIndex: Int
        let targetReps: Int
        let actualReps: Int
        let weight: Double
        let isWarmup: Bool
        let didFail: Bool
    }

    @ObservedObject var healthStore: HealthStore
    var workout: ProgramWorkout
    var onBack: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var currentExerciseIndex: Int = 0
    @State private var currentSetIndex: Int = 0
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showingCompleteAlert = false
    @State private var showingEndSessionConfirmation = false
    @State private var isSessionEnding = false
    @State private var onRestTimer: Bool = false
    @State private var restEndingAnnounced = false
    @State private var restCompletedAnnounced = false
    @State private var speechSynthesizer = SpeechSynthesizerDelegate()
    @State private var hasAnnouncedFirstExercise = false
    @State private var warmupSetsPerExercise: [String: [WarmupSet]] = [:]
    @State private var workoutStartDate: Date = .now
    @State private var restEndsAt: Date?
    @State private var now: Date = .now
    @State private var workoutSessionId: UUID = UUID()
    @State private var setResultsByExercise: [Int: [SessionSetResult]] = [:]
    @State private var finalizedExerciseIndices: Set<Int> = []
    @State private var plankTimerStartDate: Date?
    @State private var plankEncouragementText: String = ""
    @State private var lastEncouragementTime: Date?
    @State private var isGeneratingEncouragement: Bool = false
    @ScaledMetric(relativeTo: .largeTitle) private var restClockSize: CGFloat = 52
    private let restDuration: TimeInterval = 180
    private let restNotificationID = "workout-rest-complete"
    
    var currentExercise: Exercise? {
        guard currentExerciseIndex < workout.exercises.count else { return nil }
        return workout.exercises[currentExerciseIndex]
    }
    
    var totalExercises: Int {
        workout.exercises.count
    }
    
    var currentWarmupSets: [WarmupSet] {
        guard let exercise = currentExercise else { return [] }
        return warmupSetsPerExercise[exercise.name] ?? []
    }
    
    var totalSetsIncludingWarmup: Int {
        guard let exercise = currentExercise else { return 0 }
        return currentWarmupSets.count + exercise.sets
    }
    
    var isWarmupSet: Bool {
        currentSetIndex < currentWarmupSets.count
    }

    private func targetWorkWeight(for exercise: Exercise) -> Double {
        healthStore.getNextWorkWeight(for: exercise)
    }

    private func workSetWeight(for exercise: Exercise, workSetNumber: Int) -> Double {
        let topSetWeight = targetWorkWeight(for: exercise)
        if workSetNumber <= 1 {
            return topSetWeight
        }
        return max(exercise.baseWeight, topSetWeight - 2.5)
    }
    
    var currentSetWeight: Double {
        guard let exercise = currentExercise else { return 20.0 }
        
        if isWarmupSet {
            return currentWarmupSets[currentSetIndex].weight
        } else {
            let workSetIndex = currentSetIndex - currentWarmupSets.count
            return workSetWeight(for: exercise, workSetNumber: workSetIndex + 1)
        }
    }
    
    var currentSetReps: Int {
        if isWarmupSet {
            return currentWarmupSets[currentSetIndex].reps
        } else {
            guard let exercise = currentExercise else { return 0 }
            return Int(exercise.reps) ?? 0
        }
    }

    private var isCurrentExerciseTimed: Bool {
        currentExercise?.isTimedExercise ?? false
    }

    private var plankElapsedSeconds: Int {
        guard let start = plankTimerStartDate else { return 0 }
        return max(0, Int(now.timeIntervalSince(start)))
    }

    private var plankTimerString: String {
        let minutes = plankElapsedSeconds / 60
        let seconds = plankElapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var isPlankTimerRunning: Bool {
        plankTimerStartDate != nil
    }
    
    var timeString: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var currentSetLabel: String {
        "Set \(currentSetIndex + 1)/\(totalSetsIncludingWarmup)"
    }
    
    var restTimeString: String {
        let roundedSeconds = max(0, Int(restTimeRemaining.rounded(.up)))
        let minutes = roundedSeconds / 60
        let seconds = roundedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var restTimeRemaining: TimeInterval {
        guard onRestTimer, let restEndsAt else { return 0 }
        return max(0, restEndsAt.timeIntervalSince(now))
    }

    private var exerciseProgress: Double {
        guard totalExercises > 0 else { return 0 }
        return Double(currentExerciseIndex + 1) / Double(totalExercises)
    }

    @ViewBuilder
    private func metricTile(title: String, value: String, subtitle: String? = nil, accent: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    
    @ViewBuilder
    var exerciseDetailView: some View {
        if let exercise = currentExercise {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(exercise.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }

                let plates = exercise.getPlatesForWeight(currentSetWeight)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    metricTile(
                        title: "Total Sets",
                        value: "\(exercise.sets)",
                        subtitle: currentWarmupSets.isEmpty ? nil : "+ \(currentWarmupSets.count) warmup"
                    )

                    metricTile(
                        title: "Current Set",
                        value: "\(currentSetIndex + 1) of \(totalSetsIncludingWarmup)",
                        subtitle: isWarmupSet ? "Warmup" : nil,
                        accent: isWarmupSet ? .orange : .primary
                    )

                    metricTile(title: "Reps", value: "\(currentSetReps)")

                    metricTile(
                        title: "Weight",
                        value: String(format: "%.1f kg", currentSetWeight),
                        subtitle: plates.isEmpty ? nil : formatPlates(plates)
                    )
                }
                
                upcomingExercisesView
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    @ViewBuilder
    var timedExerciseDetailView: some View {
        if let exercise = currentExercise {
            VStack(alignment: .leading, spacing: 16) {
                Text(exercise.name)
                    .font(.title3)
                    .fontWeight(.semibold)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    metricTile(title: "Total Sets", value: "\(exercise.sets)")
                    metricTile(
                        title: "Current Set",
                        value: "\(currentSetIndex + 1) of \(exercise.sets)"
                    )
                }

                VStack(spacing: 8) {
                    Text(plankTimerString)
                        .font(.system(size: 64, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundColor(isPlankTimerRunning ? .primary : .secondary)

                    if let target = exercise.targetDurationSeconds {
                        Text("Target: \(target) seconds")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)

                if !plankEncouragementText.isEmpty {
                    Text(plankEncouragementText)
                        .font(.body)
                        .italic()
                        .foregroundColor(.accentColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: plankEncouragementText)
                }

                upcomingExercisesView
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
    
    @ViewBuilder
    var upcomingExercisesView: some View {
        if currentExerciseIndex < workout.exercises.count - 1 {
            VStack(alignment: .leading, spacing: 12) {
                Text("Up Next")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .bold()
                
                VStack(spacing: 12) {
                    ForEach(Array(workout.exercises.dropFirst(currentExerciseIndex + 1)).prefix(2).indices, id: \.self) { index in
                        let nextExercise = workout.exercises[currentExerciseIndex + 1 + index]
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(nextExercise.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                Text("\(nextExercise.sets) × \(nextExercise.reps)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    var actionButtonView: some View {
        if onRestTimer {
            VStack(spacing: 12) {
                VStack(spacing: 12) {
                    Text("Rest Time")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(restTimeString)
                        .font(.system(size: restClockSize, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    ProgressView(value: 1.0 - (restTimeRemaining / restDuration))
                        .tint(.accentColor)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                nextSetPreviewView
                
                Button(action: {
                    completeRest()
                }) {
                    Text("Skip Rest")
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .foregroundColor(.primary)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .font(.headline)
                }
            }
        } else if isCurrentExerciseTimed {
            if !isPlankTimerRunning {
                Button(action: {
                    startPlankTimer()
                }) {
                    Text("Start \(currentExercise?.name ?? "Exercise")")
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .foregroundColor(.white)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .font(.headline)
                }
            } else {
                Button(action: {
                    completePlankSet()
                }) {
                    Text("Done - Stop Timer")
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .foregroundColor(.white)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .font(.headline)
                }
            }
        } else if currentSetIndex < totalSetsIncludingWarmup - 1 {
            if isWarmupSet {
                Button(action: {
                    recordCurrentSetAndStartRest(didFail: false)
                }) {
                    Text("Set Complete - Start Rest")
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .foregroundColor(.white)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .font(.headline)
                }
            } else {
                VStack(spacing: 10) {
                    Button(action: {
                        recordCurrentSetAndStartRest(didFail: false)
                    }) {
                        Text("Set Complete - Start Rest")
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .foregroundColor(.white)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .font(.headline)
                    }

                    Button(action: {
                        recordCurrentSetAndStartRest(didFail: true)
                    }) {
                        Text("Mark Set Failed - Start Rest")
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .foregroundColor(.white)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .font(.headline)
                    }
                }
            }
        } else if currentExerciseIndex < totalExercises - 1 {
            if isWarmupSet {
                Button(action: {
                    recordCurrentSetAndStartRest(didFail: false)
                }) {
                    Text("Exercise Complete - Start Rest")
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .foregroundColor(.white)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .font(.headline)
                }
            } else {
                VStack(spacing: 10) {
                    Button(action: {
                        recordCurrentSetAndStartRest(didFail: false)
                    }) {
                        Text("Exercise Complete - Start Rest")
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .foregroundColor(.white)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .font(.headline)
                    }

                    Button(action: {
                        recordCurrentSetAndStartRest(didFail: true)
                    }) {
                        Text("Mark Set Failed - Start Rest")
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .foregroundColor(.white)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .font(.headline)
                    }
                }
            }
        } else {
            VStack(spacing: 10) {
                Button(action: {
                    recordCurrentSetIfNeeded(didFail: false)
                    showingCompleteAlert = true
                }) {
                    Text("Finish Workout")
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .foregroundColor(.white)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .font(.headline)
                }

                if !isWarmupSet {
                    Button(action: {
                        recordCurrentSetIfNeeded(didFail: true)
                        showingCompleteAlert = true
                    }) {
                        Text("Mark Final Set Failed & Finish")
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .foregroundColor(.white)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .font(.headline)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    var nextSetPreviewView: some View {
        // Calculate next set info
        if currentSetIndex < totalSetsIncludingWarmup - 1, let exercise = currentExercise {
            // More sets in this exercise
            let nextSetIndex = currentSetIndex + 1
            
            let currentWarmups = currentWarmupSets
            let nextSetInfo: (weight: Double, reps: Int, isWarmup: Bool) = {
                if nextSetIndex < currentWarmups.count {
                    // Next is a warmup
                    return (currentWarmups[nextSetIndex].weight, currentWarmups[nextSetIndex].reps, true)
                }

                // Next is a work set
                let workSetIndex = nextSetIndex - currentWarmups.count
                return (workSetWeight(for: exercise, workSetNumber: workSetIndex + 1), Int(exercise.reps) ?? 0, false)
            }()
            let nextWeight = nextSetInfo.weight
            let nextReps = nextSetInfo.reps
            let nextIsWarmup = nextSetInfo.isWarmup
            
            let plates = exercise.getPlatesForWeight(nextWeight)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Next Set")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .bold()
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Set \(nextSetIndex + 1) of \(totalSetsIncludingWarmup)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            if nextIsWarmup {
                                Text("Warmup")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .cornerRadius(4)
                            }
                            if exercise.isTimedExercise, let target = exercise.targetDurationSeconds {
                                Text("\(target)s hold")
                                    .font(.headline)
                                    .bold()
                                    .lineLimit(1)
                            } else {
                                Text("\(nextReps) reps")
                                    .font(.headline)
                                    .bold()
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()

                    if !exercise.isTimedExercise {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weight")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f kg", nextWeight))
                                .font(.headline)
                                .bold()
                                .lineLimit(1)
                            if !plates.isEmpty {
                                Text(formatPlates(plates))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else if currentExerciseIndex < totalExercises - 1 {
            // Next exercise
            let nextExercise = workout.exercises[currentExerciseIndex + 1]
            let workWeight = targetWorkWeight(for: nextExercise)
            let nextWarmups = warmupSetsPerExercise[nextExercise.name] ?? []
            
            let firstSetWeight = nextWarmups.isEmpty ? workWeight : nextWarmups[0].weight
            let firstSetReps = nextWarmups.isEmpty ? (Int(nextExercise.reps) ?? 0) : nextWarmups[0].reps
            let firstSetIsWarmup = !nextWarmups.isEmpty
            let plates = nextExercise.getPlatesForWeight(firstSetWeight)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Next Exercise")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .bold()
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(nextExercise.name)
                            .font(.headline)
                            .bold()
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        HStack(spacing: 8) {
                            if firstSetIsWarmup {
                                Text("Warmup")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .cornerRadius(4)
                            }
                            if nextExercise.isTimedExercise, let target = nextExercise.targetDurationSeconds {
                                Text("\(target)s hold")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(firstSetReps) reps")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    if !nextExercise.isTimedExercise {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weight")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f kg", firstSetWeight))
                                .font(.headline)
                                .bold()
                                .lineLimit(1)
                            if !plates.isEmpty {
                                Text(formatPlates(plates))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    var heartRateOverview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: healthStore.currentHeartRate != nil ? "waveform.path.ecg" : "heart")
                    .font(.title3)
                    .foregroundColor(healthStore.currentHeartRate != nil ? .red : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    if let heartRate = healthStore.currentHeartRate {
                        Text("\(Int(heartRate.rounded())) bpm")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    } else {
                        Text("No heart rate yet")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Text(healthStore.heartRateStatusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
                if healthStore.isReceivingHeartRate {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .shadow(radius: 1)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    showingEndSessionConfirmation = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                }
                .disabled(isSessionEnding)
                Spacer()
                HStack {
                    Image(systemName: "timer")
                        .font(.subheadline)
                    Text(timeString)
                        .font(.subheadline)
                        .monospacedDigit()
                }
                .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    showingEndSessionConfirmation = true
                }) {
                    Text("End Session")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .disabled(isSessionEnding)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 16) {
                    heartRateOverview

                    VStack(alignment: .leading, spacing: 8) {
                        Text(workout.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)

                        ProgressView(value: exerciseProgress)
                            .tint(.accentColor)

                        Text("Exercise \(currentExerciseIndex + 1) of \(totalExercises)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    if isCurrentExerciseTimed {
                        timedExerciseDetailView
                    } else {
                        exerciseDetailView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            VStack(spacing: 12) {
                actionButtonView
            }
            .padding(16)
            .disabled(isSessionEnding)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            workoutSessionId = UUID()
            setResultsByExercise = [:]
            finalizedExerciseIndices = []
            // Generate warmup sets for all exercises
            for exercise in workout.exercises {
                let workWeight = targetWorkWeight(for: exercise)
                let warmups = exercise.generateWarmupSets(workWeight)
                warmupSetsPerExercise[exercise.name] = warmups
            }
            
            // Start the timer
            workoutStartDate = .now
            now = .now
            UIApplication.shared.isIdleTimerDisabled = true
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                handleTimerTick()
            }
            Task {
                await startLiveActivity()
            }
            // Start HealthKit workout
            Task {
                await healthStore.startWorkoutSession(workoutName: workout.name)
            }
            // Announce the first exercise after a short delay to ensure audio session is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                announceExerciseInfo()
                hasAnnouncedFirstExercise = true
                // Send initial workout update to watch after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    sendWorkoutUpdateToWatch()
                }
            }
            
            // Listen for watch messages
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("WatchSetComplete"),
                object: nil,
                queue: .main
            ) { notification in
                if let didFail = notification.userInfo?["didFail"] as? Bool {
                    recordCurrentSetAndStartRest(didFail: didFail)
                }
            }
            
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("WatchSkipRest"),
                object: nil,
                queue: .main
            ) { _ in
                completeRest()
            }
            
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("WatchEndWorkout"),
                object: nil,
                queue: .main
            ) { _ in
                showingEndSessionConfirmation = true
            }
        }
        .onDisappear {
            timer?.invalidate()
            UIApplication.shared.isIdleTimerDisabled = false
            healthStore.stopHeartRateUpdates()
            clearScheduledRestNotification()
            plankTimerStartDate = nil
            speechSynthesizer.stopAndClearQueue()
            Task {
                await endLiveActivity()
            }
            NotificationCenter.default.removeObserver(self)
        }
        .onChange(of: currentExerciseIndex) {
            // Announce when moving to a new exercise
            if hasAnnouncedFirstExercise {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    announceExerciseInfo()
                }
            }
            Task {
                await updateLiveActivity()
            }
            sendWorkoutUpdateToWatch()
        }
        .onChange(of: currentSetIndex) {
            Task {
                await updateLiveActivity()
            }
            sendWorkoutUpdateToWatch()
        }
        .onChange(of: onRestTimer) {
            Task {
                await updateLiveActivity()
            }
            sendWorkoutUpdateToWatch()
        }
        .onChange(of: restEndsAt) {
            Task {
                await updateLiveActivity()
            }
            sendWorkoutUpdateToWatch()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                now = .now
                handleRestCountdown()
            }
        }
        .alert("Finish Workout?", isPresented: $showingCompleteAlert) {
            Button("Save & Finish") {
                if currentSetIndex == totalSetsIncludingWarmup - 1 {
                    recordCurrentSetIfNeeded(didFail: false)
                }
                finalizeExerciseAttemptIfNeeded(at: currentExerciseIndex)
                
                Task {
                    guard !isSessionEnding else { return }
                    isSessionEnding = true
                    timer?.invalidate()
                    clearRestStateForSessionEnd()
                    healthStore.stopHeartRateUpdates()
                    let endDate = Date()
                    let duration = max(0, endDate.timeIntervalSince(workoutStartDate))
                    await healthStore.endWorkoutSession(duration: duration)
                    healthStore.completeWorkout(workout.name)
                    healthStore.recordWorkoutSession(
                        workoutName: workout.name,
                        startDate: workoutStartDate,
                        endDate: endDate,
                        duration: duration,
                        status: .completed
                    )
                    await MainActor.run {
                        returnToHome()
                    }
                    Task {
                        await endLiveActivity()
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Mark this workout as complete and save it to Health?")
        }
        .confirmationDialog("End session early?", isPresented: $showingEndSessionConfirmation) {
            Button("Save Progress & End", role: .destructive) {
                Task {
                    await endSessionEarly()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Completed sets will be saved. Unfinished exercises will not be marked complete.")
        }
    }

    private func recordCurrentSetAndStartRest(didFail: Bool) {
        recordCurrentSetIfNeeded(didFail: didFail)
        startRestTimer()
    }

    private func startPlankTimer() {
        plankTimerStartDate = now
        plankEncouragementText = ""
        lastEncouragementTime = nil
        announceExerciseInfo()
    }

    private func completePlankSet() {
        let duration = plankElapsedSeconds
        plankTimerStartDate = nil
        plankEncouragementText = ""
        lastEncouragementTime = nil
        isGeneratingEncouragement = false

        recordTimedSetResult(durationSeconds: duration)

        let isLastSetOfExercise = currentSetIndex >= (currentExercise?.sets ?? 1) - 1
        let isLastExercise = currentExerciseIndex >= totalExercises - 1

        if isLastSetOfExercise && isLastExercise {
            finalizeExerciseAttemptIfNeeded(at: currentExerciseIndex)
            showingCompleteAlert = true
        } else {
            startRestTimer()
        }
    }

    private func recordTimedSetResult(durationSeconds: Int) {
        guard let exercise = currentExercise else { return }
        let targetDuration = exercise.targetDurationSeconds ?? 0
        let result = SessionSetResult(
            setIndex: currentSetIndex,
            targetReps: targetDuration,
            actualReps: durationSeconds,
            weight: 0.0,
            isWarmup: false,
            didFail: durationSeconds < targetDuration
        )
        var setResults = setResultsByExercise[currentExerciseIndex] ?? []
        if let existingIndex = setResults.firstIndex(where: { $0.setIndex == currentSetIndex }) {
            setResults[existingIndex] = result
        } else {
            setResults.append(result)
        }
        setResultsByExercise[currentExerciseIndex] = setResults.sorted(by: { $0.setIndex < $1.setIndex })
    }

    private func recordCurrentSetIfNeeded(didFail: Bool) {
        guard currentExerciseIndex < workout.exercises.count else { return }

        let targetReps = currentSetReps
        let actualReps = didFail ? max(0, targetReps - 1) : targetReps
        let currentResult = SessionSetResult(
            setIndex: currentSetIndex,
            targetReps: targetReps,
            actualReps: actualReps,
            weight: currentSetWeight,
            isWarmup: isWarmupSet,
            didFail: didFail
        )

        var setResults = setResultsByExercise[currentExerciseIndex] ?? []
        if let existingIndex = setResults.firstIndex(where: { $0.setIndex == currentSetIndex }) {
            setResults[existingIndex] = currentResult
        } else {
            setResults.append(currentResult)
        }
        setResultsByExercise[currentExerciseIndex] = setResults.sorted(by: { $0.setIndex < $1.setIndex })
    }

    private func finalizeExerciseAttemptIfNeeded(at exerciseIndex: Int, markExerciseCompleted: Bool = true) {
        guard !finalizedExerciseIndices.contains(exerciseIndex) else { return }
        guard exerciseIndex < workout.exercises.count else { return }

        let exercise = workout.exercises[exerciseIndex]
        let results = setResultsByExercise[exerciseIndex] ?? []

        if !results.isEmpty {
            let mappedResults = results.map { result in
                (
                    setIndex: result.setIndex,
                    targetReps: result.targetReps,
                    actualReps: result.actualReps,
                    weight: result.weight,
                    isWarmup: result.isWarmup,
                    didFail: result.didFail
                )
            }
            healthStore.recordExerciseAttempt(
                workoutId: workoutSessionId,
                workoutName: workout.name,
                exercise: exercise,
                setRecords: mappedResults
            )
        }

        if markExerciseCompleted {
            healthStore.completeExercise(exercise.name, inWorkout: workout.name)
        }
        finalizedExerciseIndices.insert(exerciseIndex)
    }

    private func expectedSetCount(for exerciseIndex: Int) -> Int {
        guard exerciseIndex < workout.exercises.count else { return 0 }
        let exercise = workout.exercises[exerciseIndex]
        let warmupCount = warmupSetsPerExercise[exercise.name]?.count ?? 0
        return warmupCount + exercise.sets
    }

    private func hasCompletedAllSets(for exerciseIndex: Int) -> Bool {
        let expected = expectedSetCount(for: exerciseIndex)
        guard expected > 0 else { return false }
        let completedSetIndices = Set((setResultsByExercise[exerciseIndex] ?? []).map { $0.setIndex })
        return completedSetIndices.count >= expected
    }

    private func finalizeRemainingExerciseAttemptsForEarlyEnd() {
        let candidateIndices = Set(setResultsByExercise.keys).subtracting(finalizedExerciseIndices)
        for exerciseIndex in candidateIndices.sorted() {
            finalizeExerciseAttemptIfNeeded(
                at: exerciseIndex,
                markExerciseCompleted: hasCompletedAllSets(for: exerciseIndex)
            )
        }
    }

    private func clearRestStateForSessionEnd() {
        onRestTimer = false
        restEndsAt = nil
        restEndingAnnounced = false
        restCompletedAnnounced = false
        clearScheduledRestNotification()
        plankTimerStartDate = nil
        plankEncouragementText = ""
        lastEncouragementTime = nil
        isGeneratingEncouragement = false
        speechSynthesizer.stopAndClearQueue()
    }

    private func endSessionEarly() async {
        guard !isSessionEnding else { return }
        isSessionEnding = true

        timer?.invalidate()
        clearRestStateForSessionEnd()
        healthStore.stopHeartRateUpdates()
        finalizeRemainingExerciseAttemptsForEarlyEnd()

        let endDate = Date()
        let duration = max(0, endDate.timeIntervalSince(workoutStartDate))
        await healthStore.endWorkoutSession(duration: duration)
        healthStore.completeWorkout(workout.name)
        healthStore.recordWorkoutSession(
            workoutName: workout.name,
            startDate: workoutStartDate,
            endDate: endDate,
            duration: duration,
            status: .endedEarly
        )
        await MainActor.run {
            returnToHome()
        }
        Task {
            await endLiveActivity()
        }
    }

    @MainActor
    private func returnToHome() {
        onBack()
        dismiss()
    }

    private func handleTimerTick() {
        now = .now
        elapsedTime = now.timeIntervalSince(workoutStartDate)
        handleRestCountdown()
        handlePlankEncouragement()
    }

    private func handlePlankEncouragement() {
        guard isPlankTimerRunning, !isGeneratingEncouragement else { return }

        let elapsed = plankElapsedSeconds
        guard elapsed >= 10 else { return }

        if let lastTime = lastEncouragementTime {
            guard now.timeIntervalSince(lastTime) >= 15 else { return }
        }

        lastEncouragementTime = now
        isGeneratingEncouragement = true

        Task {
            await generatePlankEncouragement(elapsedSeconds: elapsed)
        }
    }

    private func generatePlankEncouragement(elapsedSeconds: Int) async {
        let targetSeconds = currentExercise?.targetDurationSeconds ?? 60
        let setNumber = currentSetIndex + 1
        let totalSets = currentExercise?.sets ?? 3

        do {
            let model = SystemLanguageModel.default
            guard model.isAvailable else {
                await MainActor.run { isGeneratingEncouragement = false }
                return
            }

            let session = LanguageModelSession()

            let prompt = """
            You are an energetic fitness coach encouraging someone holding a plank. \
            They have been holding for \(elapsedSeconds) seconds (target: \(targetSeconds)s). \
            This is set \(setNumber) of \(totalSets). \
            Give ONE short encouraging sentence (under 15 words). \
            Be specific to the time elapsed. No emojis. Vary your encouragement.
            """

            var fullResponse = ""
            for try await partial in session.streamResponse(to: prompt) {
                fullResponse = partial.content
            }

            let encouragement = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)

            await MainActor.run {
                plankEncouragementText = encouragement
                isGeneratingEncouragement = false
                speechSynthesizer.speakPlankEncouragement(encouragement)
            }
        } catch {
            await MainActor.run {
                isGeneratingEncouragement = false
            }
        }
    }

    private func handleRestCountdown() {
        guard onRestTimer else { return }

        if restTimeRemaining <= 10, !restEndingAnnounced {
            restEndingAnnounced = true
            announceRestEnding()
        }

        if restTimeRemaining <= 0 {
            if !restCompletedAnnounced {
                restCompletedAnnounced = true
                announceRestComplete()
            }
            completeRest()
        }
    }
    
    private func startRestTimer() {
        // Announce the next set (before we move to it, so it uses current indices)
        announceNextSet()
        
        // Start rest (don't increment currentSetIndex here - that happens in completeRest)
        onRestTimer = true
        restEndsAt = Date().addingTimeInterval(restDuration)
        restEndingAnnounced = false
        restCompletedAnnounced = false
        scheduleRestCompleteNotification()
        handleRestCountdown()
    }
    
    private func completeRest() {
        onRestTimer = false
        restEndsAt = nil
        restEndingAnnounced = false
        restCompletedAnnounced = false
        clearScheduledRestNotification()
        plankTimerStartDate = nil
        plankEncouragementText = ""
        lastEncouragementTime = nil
        isGeneratingEncouragement = false
        
        if currentSetIndex == totalSetsIncludingWarmup - 1 {
            finalizeExerciseAttemptIfNeeded(at: currentExerciseIndex)
        }
        
        // Move to next set or exercise
        if currentSetIndex < totalSetsIncludingWarmup - 1 {
            currentSetIndex += 1
        } else if currentExerciseIndex < totalExercises - 1 {
            currentExerciseIndex += 1
            currentSetIndex = 0
        }
    }

    private func startLiveActivity() async {
        await WorkoutLiveActivityManager.shared.start(
            workoutName: workout.name,
            exerciseName: currentExercise?.name ?? "Workout",
            setLabel: currentSetLabel,
            startedAt: workoutStartDate,
            isResting: onRestTimer,
            restEndDate: restEndsAt
        )
    }

    private func updateLiveActivity() async {
        await WorkoutLiveActivityManager.shared.update(
            workoutName: workout.name,
            exerciseName: currentExercise?.name ?? "Workout",
            setLabel: currentSetLabel,
            isResting: onRestTimer,
            restEndDate: restEndsAt
        )
    }

    private func endLiveActivity() async {
        await WorkoutLiveActivityManager.shared.end()
    }
}

extension WorkoutSessionView {
    private func announceRestEnding() {
        healthStore.sendWatchRestCue(.tMinus10)
        speechSynthesizer.speakRestEnding()
    }

    private func announceRestComplete() {
        healthStore.sendWatchRestCue(.restComplete)
        speechSynthesizer.speakRestComplete()
    }

    private func sendWorkoutUpdateToWatch() {
        guard !isSessionEnding else { return }
        guard let exercise = currentExercise else { return }
        let plates = exercise.getPlatesForWeight(currentSetWeight)
        let platesDescription = formatPlatesForSpeech(plates)

        // Compute next set info for the watch to display during rest
        var nextSetWeight: Double?
        var nextSetReps: Int?
        var nextSetPlatesDescription: String?
        var nextSetLabel: String?
        var nextSetIsWarmup: Bool?
        var nextExerciseName: String?

        if currentSetIndex < totalSetsIncludingWarmup - 1 {
            let nextIdx = currentSetIndex + 1
            if nextIdx < currentWarmupSets.count {
                nextSetWeight = currentWarmupSets[nextIdx].weight
                nextSetReps = currentWarmupSets[nextIdx].reps
                nextSetIsWarmup = true
            } else {
                let workSetIndex = nextIdx - currentWarmupSets.count
                nextSetWeight = workSetWeight(for: exercise, workSetNumber: workSetIndex + 1)
                nextSetReps = Int(exercise.reps) ?? 0
                nextSetIsWarmup = false
            }
            if let w = nextSetWeight {
                nextSetPlatesDescription = formatPlatesForSpeech(exercise.getPlatesForWeight(w))
            }
            nextSetLabel = "Set \(nextIdx + 1)/\(totalSetsIncludingWarmup)"
            nextExerciseName = exercise.name
        } else if currentExerciseIndex < totalExercises - 1 {
            let nextExercise = workout.exercises[currentExerciseIndex + 1]
            let nextWarmups = warmupSetsPerExercise[nextExercise.name] ?? []
            let nextTotalSets = nextWarmups.count + nextExercise.sets
            if nextWarmups.isEmpty {
                nextSetWeight = targetWorkWeight(for: nextExercise)
                nextSetReps = Int(nextExercise.reps) ?? 0
                nextSetIsWarmup = false
            } else {
                nextSetWeight = nextWarmups[0].weight
                nextSetReps = nextWarmups[0].reps
                nextSetIsWarmup = true
            }
            if let w = nextSetWeight {
                nextSetPlatesDescription = formatPlatesForSpeech(nextExercise.getPlatesForWeight(w))
            }
            nextSetLabel = "Set 1/\(nextTotalSets)"
            nextExerciseName = nextExercise.name
        }

        healthStore.sendWorkoutUpdate(
            workoutName: workout.name,
            exerciseName: exercise.name,
            currentExerciseIndex: currentExerciseIndex,
            totalExercises: totalExercises,
            currentSetIndex: currentSetIndex,
            totalSetsIncludingWarmup: totalSetsIncludingWarmup,
            currentSetWeight: currentSetWeight,
            currentSetReps: currentSetReps,
            isWarmupSet: isWarmupSet,
            isResting: onRestTimer,
            restEndDate: restEndsAt,
            platesDescription: platesDescription,
            workoutStartDate: workoutStartDate,
            nextSetWeight: nextSetWeight,
            nextSetReps: nextSetReps,
            nextSetPlatesDescription: nextSetPlatesDescription,
            nextSetLabel: nextSetLabel,
            nextExerciseName: nextExerciseName,
            nextSetIsWarmup: nextSetIsWarmup
        )
    }

    private func scheduleRestCompleteNotification() {
        guard let restEndsAt else { return }

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Time for your next set."
        content.sound = .default

        let triggerInterval = max(1, restEndsAt.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval, repeats: false)
        let request = UNNotificationRequest(identifier: restNotificationID, content: content, trigger: trigger)
        center.add(request)
    }

    private func clearScheduledRestNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restNotificationID])
    }

    private var avAustralianVoice: AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice(language: "en-AU")
    }
    
    private func announceExerciseInfo() {
        guard let exercise = currentExercise else { return }
        if exercise.isTimedExercise {
            let target = exercise.targetDurationSeconds ?? 60
            speechSynthesizer.speakTimedExerciseStart(
                name: exercise.name,
                setNumber: currentSetIndex + 1,
                totalSets: exercise.sets,
                targetSeconds: target
            )
        } else {
            let plates = exercise.getPlatesForWeight(currentSetWeight)
            let setType = isWarmupSet ? "Warmup" : "Work"
            speechSynthesizer.speakExerciseInfo(name: exercise.name, weight: currentSetWeight, plates: plates, setType: setType, reps: currentSetReps)
        }
    }
    
    private func announceNextSet() {
        // Check if there's a next set or exercise
        if currentSetIndex < totalSetsIncludingWarmup - 1 {
            // More sets in this exercise
            let nextSetIndex = currentSetIndex + 1
            guard let exercise = currentExercise else { return }

            if exercise.isTimedExercise {
                let target = exercise.targetDurationSeconds ?? 60
                speechSynthesizer.speakTimedExerciseStart(
                    name: exercise.name,
                    setNumber: nextSetIndex + 1,
                    totalSets: exercise.sets,
                    targetSeconds: target
                )
                return
            }

            let nextWeight: Double
            let nextReps: Int

            if nextSetIndex < currentWarmupSets.count {
                // Next set is a warmup
                nextWeight = currentWarmupSets[nextSetIndex].weight
                nextReps = currentWarmupSets[nextSetIndex].reps
            } else {
                // Next set is a work set
                let workSetIndex = nextSetIndex - currentWarmupSets.count
                nextWeight = workSetWeight(for: exercise, workSetNumber: workSetIndex + 1)
                nextReps = Int(exercise.reps) ?? 0
            }

            let plates = exercise.getPlatesForWeight(nextWeight)
            let setType = nextSetIndex < currentWarmupSets.count ? "Warmup" : "Work"

            speechSynthesizer.speakNextSetInfo(
                exerciseName: exercise.name,
                setNumber: nextSetIndex + 1,
                totalSets: totalSetsIncludingWarmup,
                weight: nextWeight,
                plates: plates,
                setType: setType,
                reps: nextReps
            )
        } else if currentExerciseIndex < totalExercises - 1 {
            // Next exercise
            let nextExercise = workout.exercises[currentExerciseIndex + 1]

            if nextExercise.isTimedExercise {
                let target = nextExercise.targetDurationSeconds ?? 60
                speechSynthesizer.speakTimedExerciseStart(
                    name: nextExercise.name,
                    setNumber: 1,
                    totalSets: nextExercise.sets,
                    targetSeconds: target
                )
                return
            }

            let workWeight = targetWorkWeight(for: nextExercise)
            let nextWarmups = warmupSetsPerExercise[nextExercise.name] ?? []

            let firstSetWeight = nextWarmups.isEmpty ? workWeight : nextWarmups[0].weight
            let firstSetReps = nextWarmups.isEmpty ? (Int(nextExercise.reps) ?? 0) : nextWarmups[0].reps
            let plates = nextExercise.getPlatesForWeight(firstSetWeight)
            let setType = nextWarmups.isEmpty ? "Work" : "Warmup"

            speechSynthesizer.speakNextSetInfo(
                exerciseName: nextExercise.name,
                setNumber: 1,
                totalSets: nextWarmups.count + nextExercise.sets,
                weight: firstSetWeight,
                plates: plates,
                setType: setType,
                reps: firstSetReps
            )
        }
    }
}

// MARK: - Speech Synthesizer Delegate Helper
@MainActor
final class SpeechSynthesizerDelegate: NSObject, @preconcurrency AVSpeechSynthesizerDelegate {
    private enum CueKind {
        case exerciseInfo
        case nextSetInfo
        case restEnding
        case restComplete
        case plankEncouragement
        case runSplit
    }

    private struct SpeechCue {
        let kind: CueKind
        let utterance: AVSpeechUtterance
    }

    private let synthesizer = AVSpeechSynthesizer()
    var onSpeechFinished: (() -> Void)?
    private var pendingCues: [SpeechCue] = []
    private var isSpeechFocusHeld = false
    private var isInterrupted = false

    override init() {
        super.init()
        synthesizer.delegate = self
        AudioSessionManager.shared.onInterruptionBegan = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.handleInterruptionBegan()
            }
        }
        AudioSessionManager.shared.onInterruptionEnded = { [weak self] shouldResume in
            guard let self else { return }
            Task { @MainActor in
                self.handleInterruptionEnded(shouldResume: shouldResume)
            }
        }
    }
    
    func speakExerciseInfo(name: String, weight: Double, plates: [Double], setType: String = "Work", reps: Int = 0) {
        let platesDescription = formatPlatesForSpeech(plates)
        let repsText = reps > 0 ? "for \(reps) reps, " : ""
        let message = "\(name). \(setType) set. Set weight to \(String(format: "%.1f", weight)) kilograms, \(repsText)\(platesDescription)"
        enqueueSpeech(message, kind: .exerciseInfo)
    }
    
    func speakNextSetInfo(exerciseName: String, setNumber: Int, totalSets: Int, weight: Double, plates: [Double], setType: String = "Work", reps: Int = 0) {
        let platesDescription = formatPlatesForSpeech(plates)
        let repsText = reps > 0 ? "for \(reps) reps, " : ""
        let message = "Next up: \(exerciseName), \(setType) set \(setNumber) of \(totalSets). Weight: \(String(format: "%.1f", weight)) kilograms, \(repsText)\(platesDescription)"
        enqueueSpeech(message, kind: .nextSetInfo)
    }
    
    func speakRestEnding() {
        let message = "Rest is almost over. Get ready for your next set."
        enqueueSpeech(message, kind: .restEnding)
    }

    func speakRestComplete() {
        let message = "Rest complete. Begin your next set."
        enqueueSpeech(message, kind: .restComplete)
    }

    func speakPlankEncouragement(_ message: String) {
        enqueueSpeech(message, kind: .plankEncouragement)
    }

    func speakTimedExerciseStart(name: String, setNumber: Int, totalSets: Int, targetSeconds: Int) {
        let message = "\(name). Set \(setNumber) of \(totalSets). Hold for as long as you can. Target: \(targetSeconds) seconds."
        enqueueSpeech(message, kind: .exerciseInfo)
    }

    /// Announce a completed kilometre and its pace, then hand audio focus
    /// back so any paused podcast resumes — same flow as the weights cues.
    func speakRunSplit(km: Int, paceSeconds: Int) {
        let minutes = paceSeconds / 60
        let seconds = paceSeconds % 60
        let secondsText = seconds == 1 ? "1 second" : "\(seconds) seconds"
        let minutesText = minutes == 1 ? "1 minute" : "\(minutes) minutes"
        let message = "Kilometer \(km). Pace \(minutesText) \(secondsText) per kilometer."
        enqueueSpeech(message, kind: .runSplit)
    }

    func stopAndClearQueue() {
        pendingCues.removeAll()
        isInterrupted = false
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        releaseSpeechFocusIfNeeded()
    }
    
    private func enqueueSpeech(_ message: String, kind: CueKind) {
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        let cue = SpeechCue(kind: kind, utterance: utterance)

        if isInterrupted || synthesizer.isSpeaking || synthesizer.isPaused {
            enqueueOrCoalesce(cue)
            return
        }

        startSpeaking(cue)
    }

    private func enqueueOrCoalesce(_ cue: SpeechCue) {
        if let index = pendingCues.lastIndex(where: { $0.kind == cue.kind }) {
            pendingCues[index] = cue
        } else {
            pendingCues.append(cue)
        }
    }

    private func startSpeaking(_ cue: SpeechCue) {
        holdSpeechFocusIfNeeded()
        synthesizer.speak(cue.utterance)
    }

    private func holdSpeechFocusIfNeeded() {
        guard !isSpeechFocusHeld else { return }
        AudioSessionManager.shared.requestSpeechFocus()
        isSpeechFocusHeld = true
    }

    private func releaseSpeechFocusIfNeeded() {
        guard isSpeechFocusHeld else { return }
        AudioSessionManager.shared.releaseSpeechFocus()
        isSpeechFocusHeld = false
    }

    private func playNextCueOrReleaseFocus() {
        guard !isInterrupted else { return }

        if !pendingCues.isEmpty {
            let next = pendingCues.removeFirst()
            startSpeaking(next)
            return
        }

        releaseSpeechFocusIfNeeded()
        onSpeechFinished?()
    }

    private func handleInterruptionBegan() {
        isInterrupted = true
        if synthesizer.isSpeaking {
            _ = synthesizer.pauseSpeaking(at: .word)
        }
    }

    private func handleInterruptionEnded(shouldResume: Bool) {
        isInterrupted = false

        guard shouldResume else {
            pendingCues.removeAll()
            if synthesizer.isSpeaking || synthesizer.isPaused {
                synthesizer.stopSpeaking(at: .immediate)
            }
            releaseSpeechFocusIfNeeded()
            return
        }

        if synthesizer.isPaused {
            _ = synthesizer.continueSpeaking()
            return
        }

        playNextCueOrReleaseFocus()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        playNextCueOrReleaseFocus()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        playNextCueOrReleaseFocus()
    }
}

#Preview {
    WorkoutSessionView(
        healthStore: HealthStore(),
        workout: ProgramWorkout(
            name: "Workout A",
            exercises: [
                Exercise(name: "Squats", sets: 5, reps: "5"),
                Exercise(name: "Bench Press", sets: 5, reps: "5")
            ]
        )
    )
}
