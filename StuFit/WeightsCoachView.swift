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
    @State private var workoutOverride: ProgramWorkout? = nil
    @State private var showingEditMenu = false
    @State private var editMode: EditMode = .selectAction
    @State private var editedWeights: [String: Double] = [:]

    var selectedProgram: WorkoutProgramTemplate? {
        guard let days = selectedDays else { return nil }
        return WorkoutProgramTemplate.getProgram(for: days)
    }

    var availableWorkouts: [ProgramWorkout] {
        guard let program = healthStore.activeWeightProgram,
              let template = WorkoutProgramTemplate.getProgram(for: program.daysPerWeek) else { return [] }
        return template.workouts
    }

    var displayedWorkout: ProgramWorkout? {
        workoutOverride ?? nextWorkout
    }

    private var hasActiveProgram: Bool {
        healthStore.activeWeightProgram?.isActive == true && displayedWorkout != nil
    }

    private var headerTitle: String {
        if hasActiveProgram { return "Today's workout" }
        if selectedProgram != nil { return "\(selectedDays ?? 3)-day program" }
        return "Weights"
    }

    var body: some View {
        VStack(spacing: 0) {
            GLMScreenHeader(headerTitle, subtitle: "Weights coach", onBack: {
                if selectedDays != nil {
                    // If days are selected, go back to day selection
                    selectedDays = nil
                } else {
                    // If on initial screen, exit the view
                    onBack()
                }
            }) {
                if hasActiveProgram {
                    Button("Edit") {
                        showingEditMenu = true
                        editMode = .selectAction
                    }
                    .buttonStyle(GLMButtonStyle(variant: .outline, size: .sm, block: false, pill: true))
                }
            }

            ScrollView {
                VStack(spacing: GLM.Space.cardGap) {
                    if let activeProgram = healthStore.activeWeightProgram, activeProgram.isActive, let workout = displayedWorkout {
                        activeWorkoutSection(workout)
                    } else if let program = selectedProgram {
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
                        if healthStore.isGeneratingAdvice || healthStore.weightsSuggestion != nil {
                            recommendationCard
                        }
                        daysPerWeekCard
                    }
                }
                .padding(.horizontal, GLM.Space.gutter)
                .padding(.top, GLM.Space.cardGap)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showingEditMenu) {
            EditWeightsProgramView(
                isPresented: $showingEditMenu,
                healthStore: healthStore,
                currentProgram: healthStore.activeWeightProgram,
                nextWorkout: displayedWorkout,
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

    // MARK: - Active program

    @ViewBuilder
    private func activeWorkoutSection(_ workout: ProgramWorkout) -> some View {
        // Workout picker
        HStack(spacing: 12) {
            GLMIconTile(glyph: "🏋️")
            VStack(alignment: .leading, spacing: 2) {
                if availableWorkouts.count > 1 {
                    Menu {
                        ForEach(availableWorkouts, id: \.name) { option in
                            Button(action: {
                                workoutOverride = option
                                Task { await healthStore.generateWorkoutTip(for: option) }
                            }) {
                                if option.name == workout.name {
                                    Label(option.name, systemImage: "checkmark")
                                } else {
                                    Text(option.name)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(workout.name).glmText(.rowTitle)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(GLM.inkMuted)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    }
                } else {
                    Text(workout.name).glmText(.rowTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Text("Next in rotation · \(workout.exercises.count) exercises").glmText(.caption)
            }
            Spacer()
        }
        .glmCard(padding: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))

        if healthStore.isGeneratingAdvice || healthStore.workoutTip != nil {
            VStack(alignment: .leading, spacing: 10) {
                GLMSectionHeader("Tip for today") {
                    if healthStore.isGeneratingAdvice {
                        ProgressView().controlSize(.small).tint(GLM.inkMuted)
                    }
                }

                if let tip = healthStore.workoutTip {
                    Text(tip)
                        .glmText(.body, color: GLM.inkBody)
                        .fixedSize(horizontal: false, vertical: true)
                        .animation(.easeInOut(duration: 0.15), value: tip)
                } else {
                    HStack(spacing: 6) {
                        Text("Reading your recent sessions").glmText(.body)
                        TypingIndicator()
                    }
                }
            }
            .glmCard()
        }

        VStack(alignment: .leading, spacing: 14) {
            GLMSectionHeader("Exercises")

            VStack(spacing: 12) {
                ForEach(workout.exercises.indices, id: \.self) { index in
                    let exercise = workout.exercises[index]
                    let setWeight = healthStore.getNextWorkWeight(for: exercise)
                    let plates = exercise.getPlatesForWeight(setWeight)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(exercise.name).glmText(.cardTitle)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(plates.isEmpty
                                 ? "\(exercise.sets) × \(exercise.reps)"
                                 : "\(exercise.sets) × \(exercise.reps) · \(formatPlates(plates))")
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

            NavigationLink(destination: WorkoutSessionView(healthStore: healthStore, workout: workout, onBack: {
                onBack()
            })) {
                Text("Start workout")
            }
            .buttonStyle(.glmPrimary)
            .padding(.top, 4)
        }
        .glmCard()
    }

    // MARK: - Program setup

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            GLMSectionHeader("Recommendation") {
                if healthStore.isGeneratingAdvice {
                    ProgressView().controlSize(.small).tint(GLM.inkMuted)
                }
            }

            if let suggestion = healthStore.weightsSuggestion {
                VStack(alignment: .leading, spacing: 8) {
                    Text(suggestion.recommendation)
                        .glmText(.body, color: GLM.inkBody)
                        .fixedSize(horizontal: false, vertical: true)
                        .animation(.easeInOut(duration: 0.15), value: suggestion.recommendation)

                    if let reasoning = suggestion.reasoning {
                        Text(reasoning)
                            .glmText(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Text("Looking at your fitness data").glmText(.body)
                    TypingIndicator()
                }
            }
        }
        .glmCard()
    }

    private var daysPerWeekCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("How many days a week can you lift?")
                    .glmText(.rowTitle)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Text("This sets the program you'll rotate through.")
                    .glmText(.caption)
            }

            VStack(spacing: GLM.Space.listGap) {
                ForEach(1...5, id: \.self) { days in
                    let isSelected = selectedDays == days
                    Button(action: {
                        selectedDays = days
                        healthStore.setWeightsProgramDays(days)
                    }) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(days) \(days == 1 ? "day" : "days")").glmText(.rowTitle)
                                if days == 3 {
                                    Text("Most popular").glmText(.caption)
                                } else if days == 4 {
                                    Text("Advanced lifters").glmText(.caption)
                                }
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(GLM.purple)
                            }
                        }
                        .glmRow(.inset)
                        .overlay {
                            if isSelected {
                                RoundedRectangle(cornerRadius: GLM.Radius.cardSm, style: .continuous)
                                    .strokeBorder(GLM.purple, lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(.glmPress)
                }
            }
        }
        .glmCard()
    }
}

// Program view to display the selected workout program
struct ProgramView: View {
    let program: WorkoutProgramTemplate
    let selectedDays: Int
    var onActivate: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: GLM.Space.cardGap) {
            HStack(spacing: 12) {
                GLMIconTile(glyph: "🏋️")
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedDays)-day program").glmText(.rowTitle)
                    Text("Rotate through these sessions in order.").glmText(.caption)
                }
                Spacer()
            }
            .glmCard(.featured, padding: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))

            ForEach(program.workouts.indices, id: \.self) { index in
                let workout = program.workouts[index]
                VStack(alignment: .leading, spacing: 12) {
                    GLMSectionHeader(workout.name)

                    VStack(spacing: 10) {
                        ForEach(workout.exercises.indices, id: \.self) { exerciseIndex in
                            let exercise = workout.exercises[exerciseIndex]
                            HStack(spacing: 12) {
                                Text(exercise.name).glmText(.cardTitle)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Spacer()
                                Text("\(exercise.sets) × \(exercise.reps)").glmText(.readout)
                            }
                        }
                    }
                }
                .glmCard()
            }

            Button("Activate program", action: onActivate)
                .buttonStyle(.glmPrimary)
                .padding(.top, 6)
        }
    }
}

#Preview {
    WeightsCoachView(healthStore: HealthStore()).glmScreen()
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
    @State private var showDeloadOptions = false

    var body: some View {
        VStack(spacing: 0) {
            GLMScreenHeader("Edit program", subtitle: "Weights")

            VStack(spacing: GLM.Space.listGap) {
                optionRow(glyph: "🔁", title: "Change program", subtitle: "Pick a different number of days per week") {
                    // Clear the active program and reset to day selection
                    healthStore.activeWeightProgram = nil
                    selectedDays = nil
                    isPresented = false
                }

                optionRow(glyph: "⚖️", title: "Edit weights", subtitle: "Set the working weight for each exercise") {
                    // Initialize editedWeights with current weights before opening
                    if let exercises = nextWorkout?.exercises {
                        for exercise in exercises {
                            let currentWeight = healthStore.getNextWorkWeight(for: exercise)
                            editedWeights[exercise.name] = currentWeight
                        }
                    }
                    showEditWeights = true
                }

                optionRow(glyph: "🌅", title: "Deload weights", subtitle: "Reduce every weight after a break") {
                    showDeloadOptions = true
                }
            }
            .padding(.horizontal, GLM.Space.gutterTight)
            .padding(.top, 16)

            Spacer()

            Button("Done") { isPresented = false }
                .buttonStyle(.glmOutline)
                .padding(.horizontal, GLM.Space.gutter)
                .padding(.bottom, 16)
        }
        .glmScreen()
        .presentationBackground(GLM.appBg)
        .sheet(isPresented: $showEditWeights) {
            EditWeightsDetailView(
                isPresented: $isPresented,
                healthStore: healthStore,
                workout: nextWorkout,
                editedWeights: $editedWeights,
                parentIsPresented: $showEditWeights
            )
        }
        .sheet(isPresented: $showDeloadOptions) {
            DeloadOptionsView(isPresented: $showDeloadOptions, healthStore: healthStore)
        }
    }

    private func optionRow(glyph: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                GLMIconTile(glyph: glyph)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).glmText(.rowTitle)
                    Text(subtitle).glmText(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GLM.inkMuted)
            }
            .glmRow()
        }
        .buttonStyle(.glmPress)
    }
}

// MARK: - Deload Options View

struct DeloadOptionsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var healthStore: HealthStore
    @State private var selectedPercent: Int? = nil
    @State private var showConfirm = false

    private let options: [(percent: Int, label: String, subtitle: String)] = [
        (10, "10% deload", "Short break · 1 to 2 weeks off"),
        (15, "15% deload", "Medium break · 2 to 4 weeks off"),
        (20, "20% deload", "Extended break · 4 or more weeks off")
    ]

    var body: some View {
        VStack(spacing: 0) {
            GLMScreenHeader("Deload weights", subtitle: "Weights")

            Text("Dropping your training weights after a break eases you back in and lowers injury risk. Choose by how long you've been away.")
                .glmText(.body)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, GLM.Space.gutter)
                .padding(.top, 16)
                .padding(.bottom, 16)

            VStack(spacing: GLM.Space.listGap) {
                ForEach(options, id: \.percent) { option in
                    Button(action: {
                        selectedPercent = option.percent
                        showConfirm = true
                    }) {
                        HStack(spacing: 13) {
                            GLMIconTile(glyph: "🌅")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label).glmText(.rowTitle)
                                Text(option.subtitle).glmText(.caption)
                            }
                            Spacer()
                            Text("−\(option.percent)%").glmText(.rowValue, color: GLM.caution)
                        }
                        .glmRow()
                    }
                    .buttonStyle(.glmPress)
                }
            }
            .padding(.horizontal, GLM.Space.gutterTight)

            Spacer()

            Button("Cancel") { isPresented = false }
                .buttonStyle(.glmOutline)
                .padding(.horizontal, GLM.Space.gutter)
                .padding(.bottom, 16)
        }
        .glmScreen()
        .presentationBackground(GLM.appBg)
        .alert("Deload by \(selectedPercent ?? 10)%?", isPresented: $showConfirm) {
            Button("Confirm", role: .destructive) {
                if let percent = selectedPercent {
                    healthStore.deloadAllWeights(percent: Double(percent))
                }
                isPresented = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every training weight drops by \(selectedPercent ?? 10)% and failure counts reset. This cannot be undone.")
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
        VStack(spacing: 0) {
            GLMScreenHeader("Edit weights", subtitle: workout?.name, onBack: { parentIsPresented = false })

            if let exercises = workout?.exercises {
                ScrollView {
                    VStack(spacing: GLM.Space.cardGap) {
                        ForEach(exercises.indices, id: \.self) { index in
                            let exercise = exercises[index]
                            let isAdjustable = !exercise.isBodyweightExercise && !exercise.isTimedExercise
                            let currentWeight = editedWeights[exercise.name] ?? exercise.baseWeight

                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exercise.name).glmText(.rowTitle)
                                        Text("\(exercise.sets) × \(exercise.reps)").glmText(.readout)
                                    }
                                    Spacer()
                                    if isAdjustable {
                                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                                            Text(String(format: "%.1f", currentWeight)).glmText(.statValue, color: GLM.cyan)
                                            Text("kg").glmText(.unit)
                                        }
                                    } else {
                                        Text("Bodyweight").glmText(.rowValue, color: GLM.inkMuted)
                                    }
                                }

                                if isAdjustable {
                                    HStack(spacing: 12) {
                                        Button(action: {
                                            let newWeight = max(exercise.baseWeight, currentWeight - 2.5)
                                            editedWeights[exercise.name] = newWeight
                                        }) {
                                            stepperGlyph("−")
                                        }
                                        .buttonStyle(.glmPress)

                                        Slider(
                                            value: Binding(
                                                get: { currentWeight },
                                                set: { editedWeights[exercise.name] = $0 }
                                            ),
                                            in: exercise.baseWeight...150,
                                            step: 2.5
                                        )
                                        .tint(GLM.purple)

                                        Button(action: {
                                            let newWeight = min(150.0, currentWeight + 2.5)
                                            editedWeights[exercise.name] = newWeight
                                        }) {
                                            stepperGlyph("+")
                                        }
                                        .buttonStyle(.glmPress)
                                    }

                                    let plates = exercise.getPlatesForWeight(currentWeight)
                                    if !plates.isEmpty {
                                        Text("Plates · \(formatPlates(plates))").glmText(.caption)
                                    }
                                }
                            }
                            .glmCard()
                        }
                    }
                    .padding(.horizontal, GLM.Space.gutter)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                }
            } else {
                Spacer()
            }

            Button("Save changes") {
                // Save the edited weights to HealthStore
                healthStore.setCustomExerciseWeights(editedWeights)
                parentIsPresented = false
            }
            .buttonStyle(.glmPrimary)
            .padding(.horizontal, GLM.Space.gutter)
            .padding(.bottom, 16)
        }
        .glmScreen()
        .presentationBackground(GLM.appBg)
    }

    private func stepperGlyph(_ glyph: String) -> some View {
        Text(glyph)
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(GLM.ink)
            .frame(width: 32, height: 32)
            .overlay { Circle().strokeBorder(GLM.border, lineWidth: 1) }
            .contentShape(Circle())
    }
}
