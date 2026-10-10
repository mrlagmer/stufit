//
//  WorkoutSessionView.swift
//  FullFitness
//
//  Created by Copilot on 31/1/2026.
//

import AVFoundation
import FoundationModels
import KittenTTS
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
    @State private var celebratedRecord: (exerciseName: String, weight: Double)?
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
        // Back-off sets are 5kg below the top set, but never below the empty bar
        return max(exercise.baseWeight, topSetWeight - 5.0)
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
            return exercise.repsPerSet ?? 0
        }
    }

    /// Short label for a work set's rep target, keeping non-numeric targets
    /// like "Max Reps" or "8 Each Leg" readable.
    private func workSetRepsLabel(for exercise: Exercise) -> String {
        Int(exercise.reps) != nil ? "\(exercise.reps) reps" : exercise.reps
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
    private func metricTile(title: String, value: String, subtitle: String? = nil, accent: Color = GLM.ink) -> some View {
        GLMInsetStatTile(value: value, label: title, subtitle: subtitle, tone: accent)
    }

    /// Small "Warmup" pill in the caution accent.
    private var warmupTag: some View {
        GLMTag(text: "Warmup", color: GLM.caution)
    }

    @ViewBuilder
    var exerciseDetailView: some View {
        if let exercise = currentExercise {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    GLMIconTile(glyph: "🏋️")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name).glmText(.screenTitle)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Text(isWarmupSet ? "Warmup set" : "Work set").glmText(.caption)
                    }
                    Spacer()
                }

                let plates = exercise.getPlatesForWeight(currentSetWeight)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: GLM.Space.listGap) {
                    metricTile(
                        title: "Sets",
                        value: "\(exercise.sets)",
                        subtitle: currentWarmupSets.isEmpty ? nil : "+ \(currentWarmupSets.count) warmup"
                    )

                    metricTile(
                        title: "Current set",
                        value: "\(currentSetIndex + 1) of \(totalSetsIncludingWarmup)",
                        subtitle: isWarmupSet ? "Warmup" : nil,
                        accent: isWarmupSet ? GLM.caution : GLM.ink
                    )

                    metricTile(title: "Reps", value: isWarmupSet ? "\(currentSetReps)" : exercise.reps)

                    metricTile(
                        title: "Weight",
                        value: formatSetWeight(currentSetWeight),
                        subtitle: exercise.usesBarbellLoading ? formatPlates(plates) : nil,
                        accent: GLM.cyan
                    )
                }

                upcomingExercisesView
            }
            .glmCard()
        }
    }

    @ViewBuilder
    var timedExerciseDetailView: some View {
        if let exercise = currentExercise {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    GLMIconTile(glyph: "🧘")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name).glmText(.screenTitle)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Text("Timed hold").glmText(.caption)
                    }
                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: GLM.Space.listGap) {
                    metricTile(title: "Sets", value: "\(exercise.sets)")
                    metricTile(
                        title: "Current set",
                        value: "\(currentSetIndex + 1) of \(exercise.sets)"
                    )
                }

                VStack(spacing: 6) {
                    Text(plankTimerString)
                        .font(.system(size: 64, weight: .bold))
                        .tracking(-1.28)
                        .monospacedDigit()
                        .foregroundColor(isPlankTimerRunning ? GLM.ink : GLM.inkMuted)

                    if let target = exercise.targetDurationSeconds {
                        Text("Target \(target) seconds").glmText(.caption)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)

                if !plankEncouragementText.isEmpty {
                    Text(plankEncouragementText)
                        .glmText(.body, color: GLM.purple)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: plankEncouragementText)
                }

                upcomingExercisesView
            }
            .glmCard()
        }
    }

    @ViewBuilder
    var upcomingExercisesView: some View {
        if currentExerciseIndex < workout.exercises.count - 1 {
            VStack(alignment: .leading, spacing: 10) {
                Text("Up next").glmEyebrow()

                VStack(spacing: GLM.Space.listGap) {
                    ForEach(Array(workout.exercises.dropFirst(currentExerciseIndex + 1)).prefix(2).indices, id: \.self) { index in
                        let nextExercise = workout.exercises[currentExerciseIndex + 1 + index]
                        HStack(spacing: 12) {
                            Text(nextExercise.name).glmText(.cardTitle)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Spacer()
                            Text("\(nextExercise.sets) × \(nextExercise.reps)").glmText(.readout)
                        }
                        .glmRow(.inset, padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                    }
                }
            }
        }
    }

    @ViewBuilder
    var actionButtonView: some View {
        if onRestTimer {
            VStack(spacing: GLM.Space.listGap) {
                VStack(spacing: 10) {
                    Text("Rest").glmEyebrow()

                    Text(restTimeString)
                        .font(.system(size: restClockSize, weight: .bold))
                        .tracking(-restClockSize * 0.02)
                        .monospacedDigit()
                        .foregroundColor(GLM.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    GLMMetricBar(fraction: 1.0 - (restTimeRemaining / restDuration), color: GLM.purple, height: 6)
                }
                .glmCard(padding: EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))

                nextSetPreviewView

                Button("Skip rest") { completeRest() }
                    .buttonStyle(.glmOutline)
            }
        } else if isCurrentExerciseTimed {
            if !isPlankTimerRunning {
                Button("Start \(currentExercise?.name ?? "exercise")") { startPlankTimer() }
                    .buttonStyle(.glmPrimary)
            } else {
                Button("Done, stop timer") { completePlankSet() }
                    .buttonStyle(.glmPrimary)
            }
        } else if currentSetIndex < totalSetsIncludingWarmup - 1 {
            if isWarmupSet {
                Button("Set complete, start rest") { recordCurrentSetAndStartRest(didFail: false) }
                    .buttonStyle(.glmPrimary)
            } else {
                VStack(spacing: GLM.Space.listGap) {
                    Button("Set complete, start rest") { recordCurrentSetAndStartRest(didFail: false) }
                        .buttonStyle(.glmPrimary)

                    Button("Set failed, start rest") { recordCurrentSetAndStartRest(didFail: true) }
                        .buttonStyle(.glmAttention)
                }
            }
        } else if currentExerciseIndex < totalExercises - 1 {
            if isWarmupSet {
                Button("Exercise complete, start rest") { recordCurrentSetAndStartRest(didFail: false) }
                    .buttonStyle(.glmPrimary)
            } else {
                VStack(spacing: GLM.Space.listGap) {
                    Button("Exercise complete, start rest") { recordCurrentSetAndStartRest(didFail: false) }
                        .buttonStyle(.glmPrimary)

                    Button("Set failed, start rest") { recordCurrentSetAndStartRest(didFail: true) }
                        .buttonStyle(.glmAttention)
                }
            }
        } else {
            VStack(spacing: GLM.Space.listGap) {
                Button("Finish workout") {
                    recordCurrentSetIfNeeded(didFail: false)
                    showingCompleteAlert = true
                }
                .buttonStyle(.glmPrimary)

                if !isWarmupSet {
                    Button("Final set failed, finish") {
                        recordCurrentSetIfNeeded(didFail: true)
                        showingCompleteAlert = true
                    }
                    .buttonStyle(.glmAttention)
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
                return (workSetWeight(for: exercise, workSetNumber: workSetIndex + 1), exercise.repsPerSet ?? 0, false)
            }()
            let nextWeight = nextSetInfo.weight
            let nextReps = nextSetInfo.reps
            let nextIsWarmup = nextSetInfo.isWarmup

            let plates = exercise.getPlatesForWeight(nextWeight)

            previewCard(
                eyebrow: "Next set",
                title: "Set \(nextSetIndex + 1) of \(totalSetsIncludingWarmup)",
                repsLabel: exercise.isTimedExercise
                    ? "\(exercise.targetDurationSeconds ?? 0)s hold"
                    : (nextIsWarmup ? "\(nextReps) reps" : workSetRepsLabel(for: exercise)),
                isWarmup: nextIsWarmup,
                weight: exercise.isTimedExercise ? nil : nextWeight,
                plates: plates
            )
        } else if currentExerciseIndex < totalExercises - 1 {
            // Next exercise
            let nextExercise = workout.exercises[currentExerciseIndex + 1]
            let workWeight = targetWorkWeight(for: nextExercise)
            let nextWarmups = warmupSetsPerExercise[nextExercise.name] ?? []

            let firstSetWeight = nextWarmups.isEmpty ? workWeight : nextWarmups[0].weight
            let firstSetReps = nextWarmups.isEmpty ? (nextExercise.repsPerSet ?? 0) : nextWarmups[0].reps
            let firstSetIsWarmup = !nextWarmups.isEmpty
            let plates = nextExercise.getPlatesForWeight(firstSetWeight)

            previewCard(
                eyebrow: "Next exercise",
                title: nextExercise.name,
                repsLabel: nextExercise.isTimedExercise
                    ? "\(nextExercise.targetDurationSeconds ?? 0)s hold"
                    : (firstSetIsWarmup ? "\(firstSetReps) reps" : workSetRepsLabel(for: nextExercise)),
                isWarmup: firstSetIsWarmup,
                weight: nextExercise.isTimedExercise ? nil : firstSetWeight,
                plates: plates
            )
        } else {
            EmptyView()
        }
    }

    private func previewCard(eyebrow: String, title: String, repsLabel: String, isWarmup: Bool, weight: Double?, plates: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow).glmEyebrow()

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).glmText(.rowTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    HStack(spacing: 8) {
                        Text(repsLabel).glmText(.readout)
                        if isWarmup { warmupTag }
                    }
                }

                Spacer()

                if let weight {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(formatSetWeight(weight)).glmText(.rowValue, color: GLM.cyan)
                            .lineLimit(1)
                        if !plates.isEmpty {
                            Text(formatPlates(plates)).glmText(.readout)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                }
            }
        }
        .glmCard(padding: EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
    }

    @ViewBuilder
    var heartRateOverview: some View {
        HStack(spacing: 12) {
            GLMIconTile(glyph: "❤️", size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text("Heart rate").glmText(.cardTitle)
                Text(healthStore.currentHeartRate != nil ? "Live from Health" : "Appears once Health has samples")
                    .glmText(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(healthStore.currentHeartRate.map { "\(Int($0.rounded()))" } ?? "--")
                    .glmText(.metric, color: GLM.cyan)
                Text("bpm").glmText(.unit)
            }
        }
        .glmCard(padding: EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 20))
    }

    var body: some View {
        VStack(spacing: 0) {
            GLMScreenHeader(workout.name, subtitle: "Exercise \(currentExerciseIndex + 1) of \(totalExercises) · \(timeString)", onBack: {
                showingEndSessionConfirmation = true
            }) {
                Button("End") { showingEndSessionConfirmation = true }
                    .buttonStyle(GLMButtonStyle(variant: .attention, size: .sm, block: false, pill: true))
                    .disabled(isSessionEnding)
            }

            ScrollView {
                VStack(spacing: GLM.Space.cardGap) {
                    GLMMetricBar(fraction: exerciseProgress, color: GLM.purple, height: 6)
                        .padding(.horizontal, 2)

                    heartRateOverview

                    if isCurrentExerciseTimed {
                        timedExerciseDetailView
                    } else {
                        exerciseDetailView
                    }
                }
                .padding(.horizontal, GLM.Space.gutter)
                .padding(.top, 16)
                .padding(.bottom, 16)
            }

            VStack(spacing: GLM.Space.listGap) {
                actionButtonView
            }
            .padding(.horizontal, GLM.Space.gutter)
            .padding(.vertical, 12)
            .disabled(isSessionEnding)
        }
        .glmScreen()
        .overlay(alignment: .top) {
            recordBannerView
        }
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

    @ViewBuilder
    private var recordBannerView: some View {
        if let record = celebratedRecord {
            HStack(spacing: 12) {
                GLMBadgeTile(glyph: "🏅")
                VStack(alignment: .leading, spacing: 2) {
                    Text("New personal record").glmText(.cardTitle)
                    Text("\(record.exerciseName) · \(GLMFormat.kg(record.weight))").glmText(.readout)
                }
                Spacer()
            }
            .glmCard(.featured, padding: EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
            .shadow(color: GLM.badgeShadow, radius: 17, x: 0, y: 14)
            .padding(.horizontal, GLM.Space.gutter)
            .padding(.top, 44)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func showRecordCelebration(exerciseName: String, weight: Double) {
        withAnimation(.spring(duration: 0.4)) {
            celebratedRecord = (exerciseName, weight)
        }
        speechSynthesizer.speakNewRecord(exerciseName: exerciseName, weight: weight)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.easeOut(duration: 0.3)) {
                if celebratedRecord?.exerciseName == exerciseName {
                    celebratedRecord = nil
                }
            }
        }
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
            // Check for a record before persisting, so the comparison is
            // against history rather than the attempt we're about to save.
            let successfulWeights = results
                .filter { !$0.isWarmup && !$0.didFail }
                .map { $0.weight }
            if let recordWeight = healthStore.newRecordWeight(
                exerciseName: exercise.name,
                successfulWorkSetWeights: successfulWeights
            ) {
                showRecordCelebration(exerciseName: exercise.name, weight: recordWeight)
            }

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
        speechSynthesizer.speakRestEnding()
    }

    private func announceRestComplete() {
        speechSynthesizer.speakRestComplete()
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
                nextReps = exercise.repsPerSet ?? 0
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
            let firstSetReps = nextWarmups.isEmpty ? (nextExercise.repsPerSet ?? 0) : nextWarmups[0].reps
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
/// Speaks workout cues with the on-device KittenTTS neural voice. Apple's
/// AVSpeechSynthesizer remains as a fallback for the window before the Kitten
/// model has downloaded (first launch) or if synthesis ever fails, so cues are
/// never silently dropped. Generated audio plays through our own AVAudioPlayer
/// — unlike KittenTTS's built-in speak(), that gives us pause/resume across
/// audio-session interruptions, matching the old AVSpeech behaviour.
final class SpeechSynthesizerDelegate: NSObject, @preconcurrency AVSpeechSynthesizerDelegate, @preconcurrency AVAudioPlayerDelegate {
    private enum CueKind {
        case exerciseInfo
        case nextSetInfo
        case restEnding
        case restComplete
        case personalRecord
        case plankEncouragement
        case runSplit
    }

    private struct SpeechCue {
        let kind: CueKind
        let message: String
    }

    // nano-int8 (~25 MB) downloads on first use and is cached in
    // Application Support; init falls back to Apple speech until then.
    private static let kittenConfig = KittenTTSConfig(model: .nanoInt8, defaultVoice: .luna)
    private var kitten: KittenTTS?
    private var player: AVAudioPlayer?
    private var synthesisTask: Task<Void, Never>?

    private let fallbackSynthesizer = AVSpeechSynthesizer()
    var onSpeechFinished: (() -> Void)?
    private var pendingCues: [SpeechCue] = []
    private var isSpeechFocusHeld = false
    private var isInterrupted = false
    private var isCueActive = false

    override init() {
        super.init()
        fallbackSynthesizer.delegate = self
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
        Task { [weak self] in
            do {
                let engine = try await KittenTTS(Self.kittenConfig)
                self?.kitten = engine
            } catch {
                // Offline first launch or download failure — Apple voice carries on.
            }
        }
    }
    
    func speakExerciseInfo(name: String, weight: Double, plates: [Double], setType: String = "Work", reps: Int = 0) {
        let repsText = reps > 0 ? "for \(reps) reps, " : ""
        let message: String
        if weight > 0 {
            let platesDescription = formatPlatesForSpeech(plates)
            message = "\(name). \(setType) set. Set weight to \(String(format: "%.1f", weight)) kilograms, \(repsText)\(platesDescription)"
        } else {
            // Bodyweight exercise — there's no bar or load to announce
            message = "\(name). \(setType) set. Body weight\(reps > 0 ? ", for \(reps) reps." : ".")"
        }
        enqueueSpeech(message, kind: .exerciseInfo)
    }

    func speakNextSetInfo(exerciseName: String, setNumber: Int, totalSets: Int, weight: Double, plates: [Double], setType: String = "Work", reps: Int = 0) {
        let repsText = reps > 0 ? "for \(reps) reps, " : ""
        let message: String
        if weight > 0 {
            let platesDescription = formatPlatesForSpeech(plates)
            message = "Next up: \(exerciseName), \(setType) set \(setNumber) of \(totalSets). Weight: \(String(format: "%.1f", weight)) kilograms, \(repsText)\(platesDescription)"
        } else {
            message = "Next up: \(exerciseName), \(setType) set \(setNumber) of \(totalSets). Body weight\(reps > 0 ? ", for \(reps) reps." : ".")"
        }
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

    func speakNewRecord(exerciseName: String, weight: Double) {
        let message = "New personal record! \(exerciseName) at \(String(format: "%.1f", weight)) kilograms. Great work."
        enqueueSpeech(message, kind: .personalRecord)
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
        stopCurrentPlayback()
        isCueActive = false
        releaseSpeechFocusIfNeeded()
    }

    private func enqueueSpeech(_ message: String, kind: CueKind) {
        let cue = SpeechCue(kind: kind, message: message)

        if isInterrupted || isCueActive {
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
        isCueActive = true

        guard let kitten else {
            speakWithAppleVoice(cue.message)
            return
        }

        synthesisTask = Task { [weak self] in
            do {
                let result = try await kitten.generate(cue.message)
                guard let self, !Task.isCancelled else { return }
                self.synthesisTask = nil
                self.playGeneratedAudio(result.wavData(), fallbackMessage: cue.message)
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.synthesisTask = nil
                self.speakWithAppleVoice(cue.message)
            }
        }
    }

    private func playGeneratedAudio(_ wavData: Data, fallbackMessage: String) {
        do {
            let player = try AVAudioPlayer(data: wavData)
            player.delegate = self
            self.player = player
            player.prepareToPlay()
            // If an interruption arrived mid-synthesis, hold the audio here;
            // handleInterruptionEnded starts it once focus returns.
            if !isInterrupted {
                player.play()
            }
        } catch {
            speakWithAppleVoice(fallbackMessage)
        }
    }

    private func speakWithAppleVoice(_ message: String) {
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        fallbackSynthesizer.speak(utterance)
    }

    private func stopCurrentPlayback() {
        synthesisTask?.cancel()
        synthesisTask = nil
        player?.stop()
        player = nil
        if fallbackSynthesizer.isSpeaking || fallbackSynthesizer.isPaused {
            fallbackSynthesizer.stopSpeaking(at: .immediate)
        }
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

        isCueActive = false
        releaseSpeechFocusIfNeeded()
        onSpeechFinished?()
    }

    private func handleInterruptionBegan() {
        isInterrupted = true
        if let player, player.isPlaying {
            player.pause()
        }
        if fallbackSynthesizer.isSpeaking {
            _ = fallbackSynthesizer.pauseSpeaking(at: .word)
        }
    }

    private func handleInterruptionEnded(shouldResume: Bool) {
        isInterrupted = false

        guard shouldResume else {
            pendingCues.removeAll()
            stopCurrentPlayback()
            isCueActive = false
            releaseSpeechFocusIfNeeded()
            return
        }

        if let player {
            player.play()
            return
        }
        if fallbackSynthesizer.isPaused {
            _ = fallbackSynthesizer.continueSpeaking()
            return
        }
        // Synthesis still in flight — playback starts when it lands.
        if synthesisTask != nil { return }

        playNextCueOrReleaseFocus()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
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
