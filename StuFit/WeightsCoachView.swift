//
//  WeightsCoachView.swift
//  FullFitness
//
//  Created by Copilot on 30/1/2026.
//

import SwiftUI

enum EditMode {
    case selectAction
    case editWeights
}

struct WeightsCoachView: View {
    @ObservedObject var healthStore: HealthStore
    var onBack: () -> Void = {}
    @State private var selectedDays: Int? = nil
    @State private var showingProgram = false
    @State private var nextWorkout: ProgramWorkout? = nil
    @State private var showingEditMenu = false
    @State private var editMode: EditMode = .selectAction
    @State private var editedWeights: [String: Double] = [:]
    
    var selectedProgram: WorkoutProgramTemplate? {
        guard let days = selectedDays else { return nil }
        return WorkoutProgramTemplate.getProgram(for: days)
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header with back button
                    HStack {
                        Button(action: {
                            if selectedDays != nil {
                                // If days are selected, go back to day selection
                                selectedDays = nil
                            } else {
                                // If on initial screen, exit the view
                                onBack()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundColor(.blue)
                        }
                        Spacer()
                        Text("Weights Coach")
                            .font(.headline)
                            .bold()
                    }
                    .padding(16)
                    
                    // Show active workout if there's an active program
                    if let activeProgram = healthStore.activeWeightProgram, activeProgram.isActive, let workout = nextWorkout {
                        // Show today's scheduled workout
                        VStack(alignment: .leading, spacing: 16) {
                            // Workout header with edit button
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Today's Workout")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text(workout.name)
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                }
                                Spacer()
                                Button(action: {
                                    showingEditMenu = true
                                    editMode = .selectAction
                                }) {
                                    Image(systemName: "pencil.circle")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(16)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            
                            // AI Workout Tip
                            if healthStore.isGeneratingAdvice || healthStore.workoutTip != nil {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundColor(.yellow)
                                        Text("Tip for Today")
                                            .font(.headline)
                                            .bold()
                                        Spacer()
                                        if healthStore.isGeneratingAdvice {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        }
                                    }
                                    
                                    if let tip = healthStore.workoutTip {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(tip)
                                                .font(.body)
                                                .lineLimit(nil)
                                                .foregroundColor(.primary)
                                                .animation(.easeInOut(duration: 0.15), value: tip)
                                        }
                                    } else {
                                        HStack(spacing: 4) {
                                            Text("Generating personalized tip")
                                                .font(.body)
                                                .foregroundColor(.secondary)
                                            TypingIndicator()
                                        }
                                    }
                                }
                                .padding(16)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            
                            // Exercises for this workout
                            VStack(spacing: 12) {
                                ForEach(workout.exercises.indices, id: \.self) { index in
                                    let exercise = workout.exercises[index]
                                    let completionCount = healthStore.getExerciseCompletionCount(exercise.name)
                                    let calculatedWeight = exercise.getWeightForSet(1, completionCount: completionCount)
                                    let setWeight = healthStore.getCustomWeight(for: exercise.name) ?? calculatedWeight
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
                                                Text("\(exercise.sets) × \(exercise.reps)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
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
                            
                            // Start workout button
                            NavigationLink(destination: WorkoutSessionView(healthStore: healthStore, workout: workout, onBack: {
                                onBack()
                            })) {
                                Text("Start Workout")
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .foregroundColor(.white)
                                    .background(Color.accentColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .font(.headline)
                            }
                        }
                    }
                    // Show program if days are selected
                    else if let program = selectedProgram {
                        ProgramView(program: program, selectedDays: selectedDays ?? 3, onActivate: {
                            healthStore.activeWeightProgram = WeightProgram(
                                id: UUID(),
                                daysPerWeek: selectedDays ?? 3,
                                createdDate: Date(),
                                isActive: true
                            )
                            onBack()
                        })
                    } else {
                        // Show day selection and AI suggestion
                        // AI Suggestion
                        if healthStore.isGeneratingAdvice || healthStore.weightsSuggestion != nil {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.orange)
                                    Text("AI Recommendation")
                                        .font(.headline)
                                        .bold()
                                    Spacer()
                                    if healthStore.isGeneratingAdvice {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                                
                                if let suggestion = healthStore.weightsSuggestion {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(suggestion.recommendation)
                                            .font(.body)
                                            .lineLimit(nil)
                                            .foregroundColor(.primary)
                                            .animation(.easeInOut(duration: 0.15), value: suggestion.recommendation)
                                        
                                        if let reasoning = suggestion.reasoning {
                                            Text(reasoning)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(nil)
                                        }
                                    }
                                } else {
                                    HStack(spacing: 4) {
                                        Text("Analyzing your fitness data")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                        TypingIndicator()
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        
                        // Days per week selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How many days per week can you commit to lifting?")
                                .font(.headline)
                                .bold()
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                            
                            Text("This helps us build a personalized program that fits your schedule.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 12) {
                                ForEach(1...5, id: \.self) { days in
                                    let isSelected = selectedDays == days
                                    Button(action: {
                                        selectedDays = days
                                        healthStore.setWeightsProgramDays(days)
                                    }) {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("\(days) \(days == 1 ? "Day" : "Days")")
                                                    .font(.headline)
                                                    .foregroundColor(isSelected ? .white : .primary)
                                                
                                                if days == 3 {
                                                    Text("Most popular")
                                                        .font(.caption)
                                                        .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                                                } else if days == 4 {
                                                    Text("Advanced lifters")
                                                        .font(.caption)
                                                        .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(12)
                                        .background(
                                            isSelected ?
                                            Color.accentColor :
                                            Color(.tertiarySystemBackground)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    
                    Spacer()
                }
                .padding(16)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEditMenu) {
            EditWeightsProgramView(
                isPresented: $showingEditMenu,
                healthStore: healthStore,
                currentProgram: healthStore.activeWeightProgram,
                nextWorkout: nextWorkout,
                selectedDays: $selectedDays,
                editedWeights: $editedWeights
            )
        }
        .onAppear {
            Task {
                // If there's an active program, get the next workout and generate a tip
                if let activeProgram = healthStore.activeWeightProgram, activeProgram.isActive {
                    nextWorkout = healthStore.getNextWorkout()
                    if let workout = nextWorkout {
                        await healthStore.generateWorkoutTip(for: workout)
                    }
                } else {
                    // Clear the workout tip and generate a program suggestion instead
                    healthStore.workoutTip = nil
                    await healthStore.generateWeightsProgramSuggestion()
                }
            }
        }
    }
}

// Program view to display the selected workout program
struct ProgramView: View {
    let program: WorkoutProgramTemplate
    let selectedDays: Int
    var onActivate: () -> Void = {}
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Program header
            VStack(alignment: .leading, spacing: 8) {
                Text("\(selectedDays) Day Program")
                    .font(.title2)
                    .bold()
                Text("Here's your personalized workout program")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            // Workouts
            VStack(spacing: 12) {
                ForEach(program.workouts.indices, id: \.self) { index in
                    let workout = program.workouts[index]
                    VStack(alignment: .leading, spacing: 12) {
                        Text(workout.name)
                            .font(.headline)
                            .bold()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(workout.exercises.indices, id: \.self) { exerciseIndex in
                                let exercise = workout.exercises[exerciseIndex]
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exercise.name)
                                            .font(.body)
                                            .bold()
                                        Text("\(exercise.sets) × \(exercise.reps)")
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
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            
            // Activate button
            Button(action: onActivate) {
                Text("Activate Program")
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .foregroundColor(.white)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .font(.headline.weight(.semibold))
            }
        }
    }
}

#Preview {
    WeightsCoachView(healthStore: HealthStore())
}

// MARK: - Edit Weights Program View

struct EditWeightsProgramView: View {
    @Binding var isPresented: Bool
    @ObservedObject var healthStore: HealthStore
    let currentProgram: WeightProgram?
    let nextWorkout: ProgramWorkout?
    @Binding var selectedDays: Int?
    @Binding var editedWeights: [String: Double]
    @State private var showEditWeights = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Program")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            
            VStack(spacing: 12) {
                // Change Program Option
                Button(action: {
                    // Clear the active program and reset to day selection
                    healthStore.activeWeightProgram = nil
                    selectedDays = nil
                    isPresented = false
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.headline)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Change Program")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Select a different number of days per week")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
                
                // Edit Weights Option
                Button(action: {
                    // Initialize editedWeights with current weights before opening
                    if let exercises = nextWorkout?.exercises {
                        for exercise in exercises {
                            let completionCount = healthStore.getExerciseCompletionCount(exercise.name)
                            let calculatedWeight = exercise.getWeightForSet(1, completionCount: completionCount)
                            let currentWeight = healthStore.getCustomWeight(for: exercise.name) ?? calculatedWeight
                            editedWeights[exercise.name] = currentWeight
                        }
                    }
                    showEditWeights = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "scalemass")
                            .font(.headline)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Edit Weights")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Adjust the weight for each exercise")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
            }
            .padding(16)
            
            Spacer()
            
            Button(action: {
                isPresented = false
            }) {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .foregroundColor(.white)
                    .background(Color(red: 0.25, green: 0.50, blue: 0.82))
                    .cornerRadius(10)
                    .font(.headline)
            }
            .padding(16)
        }
        .sheet(isPresented: $showEditWeights) {
            EditWeightsDetailView(
                isPresented: $isPresented,
                healthStore: healthStore,
                workout: nextWorkout,
                editedWeights: $editedWeights,
                parentIsPresented: $showEditWeights
            )
        }
    }
}

struct EditWeightsDetailView: View {
    @Binding var isPresented: Bool
    @ObservedObject var healthStore: HealthStore
    let workout: ProgramWorkout?
    @Binding var editedWeights: [String: Double]
    @Binding var parentIsPresented: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Header with back button
                HStack {
                    Button(action: {
                        parentIsPresented = false
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.blue)
                    }
                    Spacer()
                    Text("Edit Weights")
                        .font(.title2)
                        .bold()
                    Spacer()
                }
                .padding(16)
                
                if let exercises = workout?.exercises {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(exercises.indices, id: \.self) { index in
                                let exercise = exercises[index]
                                let currentWeight = editedWeights[exercise.name] ?? exercise.baseWeight
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(exercise.name)
                                                .font(.headline)
                                                .bold()
                                            Text("\(exercise.sets) × \(exercise.reps)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text("\(String(format: "%.1f", currentWeight)) kg")
                                                .font(.headline)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    
                                    HStack(spacing: 12) {
                                        Button(action: {
                                            let newWeight = max(20.0, currentWeight - 2.5)
                                            editedWeights[exercise.name] = newWeight
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.blue)
                                        }
                                        
                                        Slider(
                                            value: Binding(
                                                get: { currentWeight },
                                                set: { editedWeights[exercise.name] = $0 }
                                            ),
                                            in: 20...150,
                                            step: 2.5
                                        )
                                        
                                        Button(action: {
                                            let newWeight = min(150.0, currentWeight + 2.5)
                                            editedWeights[exercise.name] = newWeight
                                        }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    
                                    let plates = exercise.getPlatesForWeight(currentWeight)
                                    if !plates.isEmpty {
                                        let platesString = formatPlates(plates)
                                        Text("Plates: \(platesString)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(16)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                            }
                        }
                        .padding(16)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    // Save the edited weights to HealthStore
                    healthStore.setCustomExerciseWeights(editedWeights)
                    parentIsPresented = false
                }) {
                    Text("Save Changes")
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .foregroundColor(.white)
                        .background(Color(red: 0.25, green: 0.50, blue: 0.82))
                        .cornerRadius(10)
                        .font(.headline)
                }
                .padding(16)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

