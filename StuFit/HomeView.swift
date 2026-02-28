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
}

struct HomeView: View {
    @StateObject private var healthStore = HealthStore()
    @State private var showingActivitySelector = false
    @State private var showingWeightsCoach = false
    @State private var showingChangeProgram = false
    @State private var showingWorkoutSession = false

    private let todaysWorkouts: [Workout] = [
        Workout(time: "07:00", title: "Morning Cardio", details: "10 min warmup • 20 min run", type: .cardio),
        Workout(time: "12:30", title: "Lunchtime Strength", details: "3 sets compound lifts • core", type: .weights),
        Workout(time: "18:00", title: "Evening Mobility", details: "Stretching and foam rolling", type: .cardio)
    ]
    
    var nextWeightsWorkout: ProgramWorkout? {
        return healthStore.getNextWorkout()
    }
    
    private func dismissActivitySelector() {
        showingActivitySelector = false
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
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Onboarding / Health permissions
                    if !healthStore.authorized {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Welcome back!")
                                .font(.title)
                                .fontWeight(.semibold)
                            Text("Allow access to Health data so we can personalise your plan and track progress.")
                                .foregroundColor(.secondary)

                            Button(action: { healthStore.requestAuthorization() }) {
                                Text("Connect Health")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 6)
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    // Workout type selector (after authorization)
                    if healthStore.authorized && healthStore.selectedWorkoutType == nil && !showingActivitySelector && !showingWeightsCoach {
                        WorkoutTypeSelector(healthStore: healthStore, onActivitySelected: {
                            // Check if weights selected
                            if healthStore.selectedWorkoutType == .weights {
                                showingWeightsCoach = true
                            } else {
                                showingActivitySelector = true
                            }
                        })
                    }
                    
                    // Weights Coach (if selected weights)
                    if healthStore.authorized && healthStore.selectedWorkoutType == .weights && showingWeightsCoach {
                        WeightsCoachView(healthStore: healthStore, onBack: dismissWeightsCoach)
                    }
                    
                    // Active Weights Plan - show on home page
                    if healthStore.authorized && healthStore.activeWeightProgram?.isActive == true && !showingActivitySelector && !showingWeightsCoach {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Active Weights Plan")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text("\(healthStore.activeWeightProgram?.daysPerWeek ?? 0) Days Per Week")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: {
                                    healthStore.selectedWorkoutType = .weights
                                    showingActivitySelector = false
                                    showingWeightsCoach = false
                                    showingChangeProgram = true
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.blue)
                                        .font(.headline)
                                }
                            }
                            .padding(16)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    
                    // Change Weights Program
                    if healthStore.authorized && healthStore.selectedWorkoutType == .weights && showingChangeProgram {
                        WeightsCoachView(healthStore: healthStore, onBack: dismissChangeProgram)
                    }
                    
                    // Activity type selector (after workout type selected)
                    if healthStore.authorized && healthStore.selectedWorkoutType != nil && showingActivitySelector {
                        ActivityTypeSelector(healthStore: healthStore, onBack: dismissActivitySelector)
                    }

                    // Activity suggestion - removed, now shown in ActivityTypeSelector
                    if false {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                Text("Activity Suggestion")
                                    .font(.headline)
                                    .bold()
                                Spacer()
                                if healthStore.isGeneratingAdvice {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                            
                            if let suggestion = healthStore.suggestion {
                                Text(suggestion)
                                    .font(.body)
                                    .lineLimit(nil)
                                    .foregroundColor(.primary)
                                    .animation(.easeInOut(duration: 0.15), value: suggestion)
                            } else {
                                HStack(spacing: 4) {
                                    Text("Generating personalized advice")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    TypingIndicator()
                                }
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Workout plan - only show on homepage, not while selecting activity
                    if !showingActivitySelector && !showingWeightsCoach && !showingChangeProgram {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Today's Plan")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Spacer()
                                NavigationLink(destination: WorkoutHistoryView(healthStore: healthStore)) {
                                    Label("History", systemImage: "clock.arrow.circlepath")
                                        .font(.subheadline)
                                }
                                if healthStore.selectedWorkoutType != nil {
                                    Button(action: {
                                        healthStore.resetWorkoutPreference()
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                            .font(.headline)
                                    }
                                }
                            }

                            // Show next weights workout if there's an active program
                            if let nextWorkout = nextWeightsWorkout, healthStore.activeWeightProgram?.isActive == true {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(nextWorkout.name)
                                                .font(.headline)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.85)
                                            Text("Next in rotation")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    
                                    // Show exercises for this workout
                                    VStack(alignment: .leading, spacing: 12) {
                                        ForEach(nextWorkout.exercises.indices, id: \.self) { index in
                                            let exercise = nextWorkout.exercises[index]
                                            let setWeight = healthStore.getNextWorkWeight(for: exercise)
                                            let warmups = exercise.generateWarmupSets(setWeight)
                                            let plates = exercise.getPlatesForWeight(setWeight)
                                            let platesString = formatPlates(plates)
                                            
                                            HStack(spacing: 12) {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(exercise.name)
                                                        .font(.body)
                                                        .bold()
                                                        .lineLimit(1)
                                                        .minimumScaleFactor(0.8)
                                                    HStack(spacing: 12) {
                                                        if !warmups.isEmpty {
                                                            Text("\(warmups.count)w + \(exercise.sets) × \(exercise.reps)")
                                                                .font(.caption)
                                                                .foregroundColor(.secondary)
                                                        } else {
                                                            Text("\(exercise.sets) × \(exercise.reps)")
                                                                .font(.caption)
                                                                .foregroundColor(.secondary)
                                                        }
                                                        Text("@ \(String(format: "%.1f", setWeight)) kg")
                                                            .font(.caption)
                                                            .foregroundColor(.blue)
                                                            .lineLimit(1)
                                                    }
                                                    if !plates.isEmpty {
                                                        Text(platesString)
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                            .lineLimit(1)
                                                            .minimumScaleFactor(0.75)
                                                    }
                                                }
                                                Spacer()
                                            }
                                            .padding(12)
                                            .background(Color(.tertiarySystemBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                    }
                                    
                                    // Complete button
                                    NavigationLink(destination: WorkoutSessionView(healthStore: healthStore, workout: nextWorkout, onBack: {
                                        showingWorkoutSession = false
                                    })) {
                                        Text("Start Workout")
                                            .frame(maxWidth: .infinity)
                                            .padding(12)
                                            .foregroundColor(.white)
                                            .background(Color.accentColor)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .font(.headline.weight(.semibold))
                                    }
                                }
                                    .padding(16)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            } else {
                                // Show default static workouts
                                ForEach(todaysWorkouts) { workout in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(workout.time)
                                                .font(.headline)
                                            Text(workout.title)
                                                .font(.subheadline)
                                            Text(workout.details)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(12)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }
                        .padding(.top, 16)
                    }
                    Spacer()
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Home")
        }
    }
}

/// Animated typing indicator dots
struct TypingIndicator: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
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
