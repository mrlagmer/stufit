//
//  WeightsAdjustViews.swift
//  StuFit
//
//  Sheets for adjusting the progression by hand: set starting weights and
//  deload after a break. Reached from Settings and the home deload banner.
//

import SwiftUI

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
