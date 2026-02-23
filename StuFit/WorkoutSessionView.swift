//
//  WorkoutSessionView.swift
//  FullFitness
//
//  Created by Copilot on 31/1/2026.
//

import AVFoundation
import SwiftUI

struct WorkoutSessionView: View {
    @ObservedObject var healthStore: HealthStore
    var workout: ProgramWorkout
    var onBack: () -> Void = {}
    
    @State private var currentExerciseIndex: Int = 0
    @State private var currentSetIndex: Int = 0
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showingCompleteAlert = false
    @State private var onRestTimer: Bool = false
    @State private var restTimeRemaining: TimeInterval = 180 // 3 minutes
    @State private var restTimer: Timer?
    @State private var restEndingAnnounced = false
    @State private var speechSynthesizer = SpeechSynthesizerDelegate()
    @State private var hasAnnouncedFirstExercise = false
    @State private var warmupSetsPerExercise: [String: [WarmupSet]] = [:]
    @State private var workoutStartDate: Date = .now
    @State private var restEndsAt: Date?
    @ScaledMetric(relativeTo: .largeTitle) private var restClockSize: CGFloat = 52
    private let restDuration: TimeInterval = 180
    
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
        let completionCount = healthStore.getExerciseCompletionCount(exercise.name)
        return healthStore.getCustomWeight(for: exercise.name) ?? exercise.getWeightForSet(1, completionCount: completionCount)
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
    
    var timeString: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var currentSetLabel: String {
        "Set \(currentSetIndex + 1)/\(totalSetsIncludingWarmup)"
    }
    
    var restTimeString: String {
        let minutes = Int(restTimeRemaining) / 60
        let seconds = Int(restTimeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
        } else if currentSetIndex < totalSetsIncludingWarmup - 1 {
            Button(action: {
                startRestTimer()
            }) {
                Text("Set Complete - Start Rest")
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .foregroundColor(.white)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .font(.headline)
            }
        } else if currentExerciseIndex < totalExercises - 1 {
            Button(action: {
                startRestTimer()
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
            Button(action: {
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
                            Text("\(nextReps) reps")
                                .font(.headline)
                                .bold()
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
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
                            Text("\(firstSetReps) reps")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
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
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                }
                Spacer()
                HStack {
                    Image(systemName: "timer")
                        .font(.subheadline)
                    Text(timeString)
                        .font(.subheadline)
                        .monospacedDigit()
                }
                .foregroundColor(.secondary)
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

                    exerciseDetailView
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            VStack(spacing: 12) {
                actionButtonView
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            // Generate warmup sets for all exercises
            for exercise in workout.exercises {
                let workWeight = targetWorkWeight(for: exercise)
                let warmups = exercise.generateWarmupSets(workWeight)
                warmupSetsPerExercise[exercise.name] = warmups
            }
            
            // Start the timer
            workoutStartDate = .now
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                elapsedTime += 1
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
            }
        }
        .onDisappear {
            timer?.invalidate()
            restTimer?.invalidate()
            healthStore.stopHeartRateUpdates()
            Task {
                await endLiveActivity()
            }
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
        }
        .onChange(of: currentSetIndex) {
            Task {
                await updateLiveActivity()
            }
        }
        .onChange(of: onRestTimer) {
            Task {
                await updateLiveActivity()
            }
        }
        .onChange(of: restEndsAt) {
            Task {
                await updateLiveActivity()
            }
        }
        .alert("Finish Workout?", isPresented: $showingCompleteAlert) {
            Button("Save & Finish") {
                // Track the final exercise if on the last one
                if currentExerciseIndex == totalExercises - 1 {
                    if let exerciseName = currentExercise?.name, currentSetIndex == totalSetsIncludingWarmup - 1 {
                        healthStore.completeExercise(exerciseName, inWorkout: workout.name)
                    }
                }
                
                Task {
                    healthStore.stopHeartRateUpdates()
                    await healthStore.endWorkoutSession(duration: elapsedTime)
                    healthStore.completeWorkout(workout.name)
                    await endLiveActivity()
                    onBack()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Mark this workout as complete and save it to Health?")
        }
    }
    
    private func startRestTimer() {
        // Mark current exercise as completed only if we're on the last WORK set (not warmup)
        if currentSetIndex == totalSetsIncludingWarmup - 1 && !isWarmupSet {
            if let exerciseName = currentExercise?.name {
                healthStore.completeExercise(exerciseName, inWorkout: workout.name)
            }
        } else if currentSetIndex == totalSetsIncludingWarmup - 1 {
            // Last set overall, mark as completed
            if let exerciseName = currentExercise?.name {
                healthStore.completeExercise(exerciseName, inWorkout: workout.name)
            }
        }
        
        // Announce the next set (before we move to it, so it uses current indices)
        announceNextSet()
        
        // Start rest (don't increment currentSetIndex here - that happens in completeRest)
        onRestTimer = true
        restTimeRemaining = restDuration
        restEndsAt = Date().addingTimeInterval(restDuration)
        restEndingAnnounced = false
        restTimer?.invalidate()
        
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            restTimeRemaining -= 1
            if restTimeRemaining <= 0 {
                completeRest()
            } else if restTimeRemaining == 10 && !restEndingAnnounced {
                restEndingAnnounced = true
                announceRestEnding()
            }
        }
    }
    
    private func completeRest() {
        restTimer?.invalidate()
        onRestTimer = false
        restEndsAt = nil
        restEndingAnnounced = false
        
        // If we're completing the last set of an exercise, mark it as completed
        if currentSetIndex == totalSetsIncludingWarmup - 1 {
            if let exerciseName = currentExercise?.name {
                healthStore.completeExercise(exerciseName, inWorkout: workout.name)
            }
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
        speechSynthesizer.speakRestEnding()
    }

    private var avAustralianVoice: AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice(language: "en-AU")
    }
    
    private func announceExerciseInfo() {
        guard let exercise = currentExercise else { return }
        let plates = exercise.getPlatesForWeight(currentSetWeight)
        
        let setType = isWarmupSet ? "Warmup" : "Work"
        speechSynthesizer.speakExerciseInfo(name: exercise.name, weight: currentSetWeight, plates: plates, setType: setType, reps: currentSetReps)
    }
    
    private func announceNextSet() {
        // Check if there's a next set or exercise
        if currentSetIndex < totalSetsIncludingWarmup - 1 {
            // More sets in this exercise
            let nextSetIndex = currentSetIndex + 1
            guard let exercise = currentExercise else { return }
            
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
    let synthesizer = AVSpeechSynthesizer()
    var onSpeechFinished: (() -> Void)?
    
    func speakExerciseInfo(name: String, weight: Double, plates: [Double], setType: String = "Work", reps: Int = 0) {
        let platesDescription = formatPlatesForSpeech(plates)
        let repsText = reps > 0 ? "for \(reps) reps, " : ""
        let message = "\(name). \(setType) set. Set weight to \(String(format: "%.1f", weight)) kilograms, \(repsText)\(platesDescription)"
        speak(message)
    }
    
    func speakNextSetInfo(exerciseName: String, setNumber: Int, totalSets: Int, weight: Double, plates: [Double], setType: String = "Work", reps: Int = 0) {
        let platesDescription = formatPlatesForSpeech(plates)
        let repsText = reps > 0 ? "for \(reps) reps, " : ""
        let message = "Next up: \(exerciseName), \(setType) set \(setNumber) of \(totalSets). Weight: \(String(format: "%.1f", weight)) kilograms, \(repsText)\(platesDescription)"
        speak(message)
    }
    
    func speakRestEnding() {
        let message = "Rest is almost over. Get ready for your next set."
        speak(message)
    }
    
    private func speak(_ message: String) {
        AudioSessionManager.shared.activateAudioSession()
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        synthesizer.delegate = self
        synthesizer.speak(utterance)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Deactivate audio session after speech finishes so podcasts can resume
        AudioSessionManager.shared.deactivateAudioSession()
        onSpeechFinished?()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // Also deactivate if speech is cancelled
        AudioSessionManager.shared.deactivateAudioSession()
        onSpeechFinished?()
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
