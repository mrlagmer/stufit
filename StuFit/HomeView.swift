//
//  HomeView.swift
//  FullFitness
//
//  Created by Copilot on 27/1/2026.
//

import SwiftUI

struct Workout: Identifiable {
    let id = UUID()
    let time: String
    let title: String
    let details: String
    let type: WorkoutType
    let glyph: String
}

struct HomeView: View {
    @StateObject private var healthStore = HealthStore()
    @State private var showingActivitySelector = false
    @State private var showingWeightsCoach = false
    @State private var showingChangeProgram = false
    @State private var showingWorkoutSession = false
    @State private var showingRunConfig = false
    @State private var showingDeloadFromBanner = false
    @State private var runManager: RunSessionManager?
    @State private var showingRunActive = false

    private let todaysWorkouts: [Workout] = [
        Workout(time: "07:00", title: "Morning cardio", details: "10 min warmup · 20 min run", type: .cardio, glyph: "🏃"),
        Workout(time: "12:30", title: "Lunchtime strength", details: "3 sets compound lifts · core", type: .weights, glyph: "🏋️"),
        Workout(time: "18:00", title: "Evening mobility", details: "Stretching and foam rolling", type: .cardio, glyph: "🧘")
    ]

    var nextWeightsWorkout: ProgramWorkout? {
        return healthStore.getNextWorkout()
    }

    private var isOnHome: Bool {
        !showingActivitySelector && !showingWeightsCoach && !showingChangeProgram && !showingRunConfig
    }

    private func dismissActivitySelector() {
        showingActivitySelector = false
        showingRunConfig = false
        healthStore.resetWorkoutPreference()
    }

    private func dismissRunConfig() {
        showingRunConfig = false
        showingActivitySelector = true
    }

    private func startRun() {
        let outdoor = (healthStore.selectedRunLocation ?? .outdoor) == .outdoor
        runManager = RunSessionManager(goal: healthStore.runGoal, outdoor: outdoor, healthStore: healthStore)
        showingRunConfig = false
        showingRunActive = true
    }

    private func finishRun() {
        runManager?.stop()
        runManager = nil
        showingRunActive = false
        healthStore.resetWorkoutPreference()
    }

    private func dismissWeightsCoach() {
        showingWeightsCoach = false
        healthStore.resetWorkoutPreference()
    }

    private func dismissChangeProgram() {
        showingWeightsCoach = false
        showingChangeProgram = false
        healthStore.resetWorkoutPreference()
    }

    var body: some View {
        NavigationStack {
            screenContent
                .glmScreen()
                .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showingDeloadFromBanner) {
            DeloadOptionsView(isPresented: $showingDeloadFromBanner, healthStore: healthStore)
        }
        .fullScreenCover(isPresented: $showingRunActive) {
            if let runManager {
                RunActiveView(
                    manager: runManager,
                    onHide: { showingRunActive = false },
                    onFinish: finishRun
                )
            }
        }
    }

    private var showsWeightsCoach: Bool {
        healthStore.authorized && healthStore.selectedWorkoutType == .weights && (showingWeightsCoach || showingChangeProgram)
    }

    private var showsActivitySelector: Bool {
        healthStore.authorized && healthStore.selectedWorkoutType != nil && showingActivitySelector
    }

    @ViewBuilder
    private var screenContent: some View {
        if showsWeightsCoach {
            // Weights coach owns the whole screen (it has its own header)
            WeightsCoachView(healthStore: healthStore, onBack: {
                if showingChangeProgram {
                    dismissChangeProgram()
                } else {
                    dismissWeightsCoach()
                }
            })
        } else if healthStore.authorized && showingRunConfig {
            RunConfigurationView(healthStore: healthStore, onBack: dismissRunConfig, onStart: startRun)
        } else if showsActivitySelector {
            ActivityTypeSelector(healthStore: healthStore, onBack: dismissActivitySelector, onRunLocationSelected: {
                showingActivitySelector = false
                showingRunConfig = true
            })
        } else {
            homeScreen
        }
    }

    // MARK: - Home

    private var homeScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GLM.Space.cardGap) {
                greetingHeader

                if !healthStore.authorized {
                    connectHealthCard
                }

                if healthStore.authorized && healthStore.selectedWorkoutType == nil {
                    WorkoutTypeSelector(healthStore: healthStore, onActivitySelected: {
                        if healthStore.selectedWorkoutType == .weights {
                            showingWeightsCoach = true
                        } else {
                            showingActivitySelector = true
                        }
                    })
                }

                if let runManager, runManager.isActive, !showingRunActive {
                    resumeRunCard(runManager)
                }

                if healthStore.authorized && healthStore.shouldShowDeloadBanner {
                    deloadCard
                }

                if healthStore.authorized && healthStore.activeWeightProgram?.isActive == true {
                    activePlanCard
                    ProgressSummaryCard(healthStore: healthStore)
                }

                todaysPlan
                    .padding(.top, 6)
            }
            .padding(.horizontal, GLM.Space.gutter)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
    }

    private var greetingHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text(GLMFormat.greeting).glmText(.greeting)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 7) {
                    Circle().fill(GLM.purple).frame(width: 6, height: 6)
                    Text(streakLine).glmText(.body)
                }
            }
            Spacer()
            NavigationLink(destination: WorkoutHistoryView(healthStore: healthStore)) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GLM.inkMuted)
                    .frame(width: 40, height: 40)
                    .background(GLM.surface)
                    .overlay { Circle().strokeBorder(GLM.border, lineWidth: 1) }
                    .clipShape(Circle())
            }
            .buttonStyle(.glmPress)
        }
        .padding(.bottom, 2)
    }

    private var streakLine: String {
        guard healthStore.authorized, healthStore.activeWeightProgram?.isActive == true else {
            return "Ready when you are"
        }
        let streak = healthStore.weeklyStreak
        switch streak {
        case 0: return "No streak yet · start one this week"
        case 1: return "1-week streak"
        default: return "\(streak)-week streak"
        }
    }

    private var connectHealthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                GLMIconTile(glyph: "❤️")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect Health").glmText(.rowTitle)
                    Text("Reads workouts and heart rate. Nothing about you leaves the phone.")
                        .glmText(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button("Allow Health access") { healthStore.requestAuthorization() }
                .buttonStyle(.glmPrimary)
                .padding(.top, 4)
        }
        .glmCard(.featured)
    }

    private var deloadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                GLMIconTile(glyph: "🌅")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome back").glmText(.rowTitle)
                    Text("Over a week since your last session. Dropping the weights eases you back in safely.")
                        .glmText(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button("Deload weights") { showingDeloadFromBanner = true }
                .buttonStyle(.glmSoft)
                .padding(.top, 4)
        }
        .glmCard()
    }

    private var activePlanCard: some View {
        HStack(spacing: 14) {
            GLMIconTile(glyph: "🏋️", size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Weights plan").glmText(.cardTitle)
                Text("\(healthStore.activeWeightProgram?.daysPerWeek ?? 0) days per week").glmText(.caption)
            }
            Spacer()
            Button("Edit") {
                healthStore.selectedWorkoutType = .weights
                showingActivitySelector = false
                showingWeightsCoach = false
                showingChangeProgram = true
            }
            .buttonStyle(GLMButtonStyle(variant: .outline, size: .sm, block: false, pill: true))
        }
        .glmCard(padding: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
    }

    private func resumeRunCard(_ manager: RunSessionManager) -> some View {
        Button(action: { showingRunActive = true }) {
            HStack(spacing: 14) {
                GLMIconTile(glyph: "🏃", size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Run in progress").glmText(.cardTitle)
                    Text(RunFormat.time(manager.elapsed)).glmText(.readout)
                }
                Spacer()
                Text("Resume").glmText(.rowValue, color: GLM.purple)
            }
            .glmCard(.featured, padding: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
        }
        .buttonStyle(.glmPress)
    }

    // MARK: - Today's plan

    private var todaysPlan: some View {
        VStack(alignment: .leading, spacing: GLM.Space.cardGap) {
            GLMSectionHeader("Today's plan") {
                if healthStore.selectedWorkoutType != nil {
                    Button("Clear") { healthStore.resetWorkoutPreference() }
                        .buttonStyle(.glmQuiet)
                        .font(.system(size: 12))
                }
            }

            if let nextWorkout = nextWeightsWorkout, healthStore.activeWeightProgram?.isActive == true {
                nextWorkoutCard(nextWorkout)
            } else {
                VStack(spacing: GLM.Space.listGap) {
                    ForEach(todaysWorkouts) { workout in
                        HStack(spacing: 13) {
                            GLMIconTile(glyph: workout.glyph)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workout.title).glmText(.rowTitle)
                                Text("\(workout.time) · \(workout.details)").glmText(.readout)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(GLM.inkMuted)
                        }
                        .glmRow()
                    }
                }
            }
        }
    }

    private func nextWorkoutCard(_ nextWorkout: ProgramWorkout) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                GLMIconTile(glyph: "🏋️")
                VStack(alignment: .leading, spacing: 2) {
                    Text(nextWorkout.name).glmText(.rowTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text("Next in rotation").glmText(.caption)
                }
                Spacer()
            }

            VStack(spacing: 12) {
                ForEach(nextWorkout.exercises.indices, id: \.self) { index in
                    let exercise = nextWorkout.exercises[index]
                    let setWeight = healthStore.getNextWorkWeight(for: exercise)
                    let warmups = exercise.generateWarmupSets(setWeight)
                    let plates = exercise.getPlatesForWeight(setWeight)

                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(exercise.name).glmText(.cardTitle)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(exerciseMeta(exercise, warmups: warmups.count, plates: plates))
                                .glmText(.readout)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        Spacer()
                        Text(setWeight > 0 ? GLMFormat.kg(setWeight) : "Bodyweight")
                            .glmText(.rowValue, color: GLM.cyan)
                            .lineLimit(1)
                    }
                }
            }

            NavigationLink(destination: WorkoutSessionView(healthStore: healthStore, workout: nextWorkout, onBack: {
                showingWorkoutSession = false
            })) {
                Text("Start workout")
            }
            .buttonStyle(.glmPrimary)
            .padding(.top, 4)
        }
        .glmCard()
    }

    private func exerciseMeta(_ exercise: Exercise, warmups: Int, plates: [Double]) -> String {
        var parts: [String] = []
        parts.append(warmups > 0 ? "\(warmups)w + \(exercise.sets) × \(exercise.reps)" : "\(exercise.sets) × \(exercise.reps)")
        if !plates.isEmpty {
            parts.append(formatPlates(plates))
        }
        return parts.joined(separator: " · ")
    }
}

/// Animated typing indicator dots
struct TypingIndicator: View {
    @State private var animationPhase = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(GLM.inkMuted)
                    .frame(width: 5, height: 5)
                    .opacity(animationPhase == index ? 1.0 : 0.3)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    animationPhase = (animationPhase + 1) % 3
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
