//
//  TrainerSettingsView.swift
//  StuFit
//
//  The trainer's model (OpenAI key + model ID, on-device status), the
//  weekly streak target, and manual weight adjustments.
//

import SwiftUI

struct TrainerSettingsView: View {
    @ObservedObject var healthStore: HealthStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage(TrainerAI.modelIDKey) private var modelID = LunaModel.defaultModelID
    @AppStorage("trainerVoiceEnabled") private var voiceEnabled = true
    @State private var keyInput = ""
    @State private var hasKey = OpenAIKeychain.apiKey != nil
    @State private var testStatus: String?
    @State private var isTesting = false
    @State private var showingEditWeights = false
    @State private var showingDeload = false
    @State private var editedWeights: [String: Double] = [:]

    private let ai = TrainerAI()

    /// Every loadable lift, so starting weights can be set before a lift's
    /// first session.
    private var adjustableLifts: ProgramWorkout {
        let exercises = ExerciseCatalog.entries.compactMap { ExerciseCatalog.exercise(named: $0.name) }
            .filter { !$0.isBodyweightExercise && !$0.isTimedExercise }
        return ProgramWorkout(name: "All lifts", exercises: exercises)
    }

    var body: some View {
        VStack(spacing: 0) {
            GLMScreenHeader("Settings", onBack: { dismiss() })

            ScrollView {
                VStack(alignment: .leading, spacing: GLM.Space.cardGap) {
                    modelCard
                    trainingCard
                }
                .padding(.horizontal, GLM.Space.gutterTight)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .glmScreen()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingEditWeights) {
            EditWeightsDetailView(
                isPresented: $showingEditWeights,
                healthStore: healthStore,
                workout: adjustableLifts,
                editedWeights: $editedWeights,
                parentIsPresented: $showingEditWeights
            )
        }
        .sheet(isPresented: $showingDeload) {
            DeloadOptionsView(isPresented: $showingDeload, healthStore: healthStore)
        }
    }

    // MARK: - Model

    private var modelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            GLMSectionHeader("Trainer brain")

            HStack(spacing: 12) {
                GLMIconTile(glyph: "🧠")
                VStack(alignment: .leading, spacing: 2) {
                    Text("GPT-6 Luna").glmText(.rowTitle)
                    Text(hasKey ? "Key saved on this device" : "Add an OpenAI API key to plan with Luna")
                        .glmText(.caption)
                }
                Spacer()
                GLMTag(text: hasKey ? "On" : "Off", color: hasKey ? GLM.success : GLM.inkMuted, dot: true)
            }

            if hasKey {
                HStack(spacing: 10) {
                    Button(isTesting ? "Testing…" : "Test connection") { testConnection() }
                        .buttonStyle(GLMButtonStyle(variant: .outline, size: .sm, block: false, pill: true))
                        .disabled(isTesting)
                    Button("Remove key") {
                        OpenAIKeychain.delete()
                        hasKey = false
                        testStatus = nil
                    }
                    .buttonStyle(GLMButtonStyle(variant: .attention, size: .sm, block: false, pill: true))
                }
            } else {
                HStack(spacing: 10) {
                    SecureField("sk-…", text: $keyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 14, design: .monospaced))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(GLM.appBg)
                        .clipShape(RoundedRectangle(cornerRadius: GLM.Radius.field, style: .continuous))
                    Button("Save") {
                        let key = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !key.isEmpty else { return }
                        hasKey = OpenAIKeychain.save(key)
                        keyInput = ""
                        testConnection()
                    }
                    .buttonStyle(GLMButtonStyle(variant: .primary, size: .sm, block: false, pill: true))
                }
            }

            if let testStatus {
                Text(testStatus)
                    .glmText(.caption, color: testStatus == "Connected" ? GLM.success : GLM.attention)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Model ID").glmText(.label)
                TextField(LunaModel.defaultModelID, text: $modelID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(GLM.ink)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(GLM.appBg)
                    .clipShape(RoundedRectangle(cornerRadius: GLM.Radius.field, style: .continuous))
            }

            GLMHairline()

            HStack(spacing: 12) {
                GLMIconTile(glyph: "📱")
                VStack(alignment: .leading, spacing: 2) {
                    Text("On-device fallback").glmText(.rowTitle)
                    Text(ai.isOnDeviceAvailable
                         ? "Plans offline when Luna can't be reached"
                         : "Apple Intelligence is off or unsupported")
                        .glmText(.caption)
                }
                Spacer()
                GLMTag(text: ai.isOnDeviceAvailable ? "Ready" : "Unavailable",
                       color: ai.isOnDeviceAvailable ? GLM.success : GLM.atRisk, dot: true)
            }
        }
        .glmCard()
    }

    private func testConnection() {
        isTesting = true
        testStatus = nil
        Task {
            let error = await ai.testLuna()
            testStatus = error ?? "Connected"
            isTesting = false
        }
    }

    // MARK: - Training

    private var trainingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            GLMSectionHeader("Training")

            HStack(spacing: 12) {
                GLMIconTile(glyph: "🔥")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly target").glmText(.rowTitle)
                    Text("Sessions per week for your streak").glmText(.caption)
                }
                Spacer()
                Stepper(value: $healthStore.weeklySessionTarget, in: 1...7) {
                    Text("\(healthStore.weeklySessionTarget)").glmText(.statValue, color: GLM.purple)
                }
                .fixedSize()
            }

            Toggle(isOn: $voiceEnabled) {
                HStack(spacing: 12) {
                    GLMIconTile(glyph: "🗣️")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Coach voice").glmText(.rowTitle)
                        Text("Speak check-in questions and plans").glmText(.caption)
                    }
                }
            }
            .tint(GLM.purple)

            GLMHairline()

            settingsRow(glyph: "⚖️", title: "Set working weights", subtitle: "Starting point for each lift") {
                editedWeights = Dictionary(uniqueKeysWithValues: adjustableLifts.exercises.map {
                    ($0.name, healthStore.getNextWorkWeight(for: $0))
                })
                showingEditWeights = true
            }
            settingsRow(glyph: "🌅", title: "Deload weights", subtitle: "Drop every weight after a break") {
                showingDeload = true
            }
        }
        .glmCard()
    }

    private func settingsRow(glyph: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                GLMIconTile(glyph: glyph)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).glmText(.rowTitle)
                    Text(subtitle).glmText(.caption)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GLM.inkMuted)
            }
        }
        .buttonStyle(.glmPress)
    }
}

#Preview {
    NavigationStack {
        TrainerSettingsView(healthStore: HealthStore())
    }
}
