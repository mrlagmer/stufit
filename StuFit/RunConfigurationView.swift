//
//  RunConfigurationView.swift
//  FullFitness
//
//  Created by Copilot on 31/3/2026.
//  Distance / Time / Open chips, a single grouped card of preset goals with
//  an inline custom stepper, a pace estimate, and a dynamic CTA.
//

import SwiftUI

struct RunConfigurationView: View {
    @ObservedObject var healthStore: HealthStore
    var onBack: () -> Void = {}
    var onStart: () -> Void = {}
    @GestureState private var swipeOffset: CGFloat = 0

    // Custom-row values, kept locally so they persist while toggling presets.
    @State private var customKm: Double = 7
    @State private var customMin: Int = 20

    // MARK: - Design constants

    /// Average pace used for estimates: 5.6 min/km ≈ 5:36 /km.
    private let paceMinPerKm = 5.6
    private let paceLabel = "5:36 /km"

    private let distancePresets: [(km: Double, tag: String)] = [
        (3, "3K"), (5, "5K"), (10, "10K"), (21.1, "Half marathon"),
    ]
    private let timePresets: [(min: Int, tag: String)] = [
        (15, "Quick"), (30, "Standard"), (45, "Long"), (60, "Endurance"),
    ]
    private let personalBests: [Double: String] = [
        3: "14:48", 5: "26:14", 10: "58:31", 21.1: "2:08:42",
    ]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            GLMScreenHeader("New run", subtitle: "Cardio", onBack: onBack) {
                locationChip
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Pick a target and we'll cue you through it. Or just head out.")
                        .glmText(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 14)

                    HStack(spacing: 8) {
                        ForEach(RunGoalType.allCases) { type in
                            GLMChip(title: type.rawValue, selected: healthStore.runGoal.type == type) {
                                healthStore.runGoal.type = type
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, 16)

                    Group {
                        switch healthStore.runGoal.type {
                        case .distance: distanceSection
                        case .time:     timeSection
                        case .open:     openSection
                        }
                    }
                    .padding(.top, 20)

                    startButton
                        .padding(.top, 22)
                }
                .padding(.horizontal, GLM.Space.gutter)
                .padding(.bottom, 36)
            }
        }
        .offset(x: swipeOffset)
        .gesture(
            DragGesture()
                .updating($swipeOffset) { value, state, _ in
                    if value.startLocation.x < 50 && value.translation.width > 0 {
                        state = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.startLocation.x < 50 && value.translation.width > 50 {
                        onBack()
                    }
                }
        )
        .animation(.easeInOut(duration: 0.15), value: healthStore.runGoal.type)
    }

    // MARK: - Header

    private var locationChip: some View {
        Button(action: toggleLocation) {
            HStack(spacing: 6) {
                Text(location == .outdoor ? "🌤️" : "🏠")
                    .font(.system(size: 12))
                Text(location.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GLM.ink)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .overlay { Capsule().strokeBorder(GLM.border, lineWidth: 1) }
            .clipShape(Capsule())
        }
        .buttonStyle(.glmPress)
    }

    private var location: RunLocationType {
        healthStore.selectedRunLocation ?? .outdoor
    }

    private func toggleLocation() {
        healthStore.setRunLocation(location == .outdoor ? .treadmill : .outdoor)
    }

    // MARK: - Distance section

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("How far")

            groupedCard {
                ForEach(Array(distancePresets.enumerated()), id: \.offset) { index, preset in
                    goalRow(
                        title: preset.tag,
                        detail: "\(formatKm(preset.km)) km",
                        estimate: distanceEstimate(preset.km),
                        personalBest: personalBests[preset.km],
                        isActive: !isCustomDistance && healthStore.runGoal.distanceKm == preset.km,
                        showSeparator: true
                    ) {
                        healthStore.runGoal.distanceKm = preset.km
                    }
                }

                stepperRow(
                    isActive: isCustomDistance,
                    valueText: "\(formatKm(customKm)) km",
                    onSelect: { healthStore.runGoal.distanceKm = customKm },
                    onDecrement: {
                        customKm = max(1, customKm - 1)
                        healthStore.runGoal.distanceKm = customKm
                    },
                    onIncrement: {
                        customKm += 1
                        healthStore.runGoal.distanceKm = customKm
                    }
                )
            }

            estimateCard(
                label: "At your average pace",
                value: "\(distanceEstimate(healthStore.runGoal.distanceKm)) · \(paceLabel)"
            )
        }
    }

    private var isCustomDistance: Bool {
        !distancePresets.contains { $0.km == healthStore.runGoal.distanceKm }
    }

    // MARK: - Time section

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("How long")

            groupedCard {
                ForEach(Array(timePresets.enumerated()), id: \.offset) { index, preset in
                    goalRow(
                        title: preset.tag,
                        detail: "\(preset.min) min",
                        estimate: "~\(formatKm(Double(preset.min) / paceMinPerKm)) km",
                        personalBest: nil,
                        isActive: !isCustomTime && healthStore.runGoal.timeMinutes == preset.min,
                        showSeparator: true
                    ) {
                        healthStore.runGoal.timeMinutes = preset.min
                    }
                }

                stepperRow(
                    isActive: isCustomTime,
                    valueText: "\(customMin) min",
                    onSelect: { healthStore.runGoal.timeMinutes = customMin },
                    onDecrement: {
                        customMin = max(1, customMin - 1)
                        healthStore.runGoal.timeMinutes = customMin
                    },
                    onIncrement: {
                        customMin += 1
                        healthStore.runGoal.timeMinutes = customMin
                    }
                )
            }

            estimateCard(
                label: "Estimated distance",
                value: "~\(formatKm(Double(healthStore.runGoal.timeMinutes) / paceMinPerKm)) km · \(paceLabel)"
            )
        }
    }

    private var isCustomTime: Bool {
        !timePresets.contains { $0.min == healthStore.runGoal.timeMinutes }
    }

    // MARK: - Open section

    private var openSection: some View {
        VStack(alignment: .leading, spacing: GLM.Space.cardGap) {
            VStack(alignment: .leading, spacing: 0) {
                GLMIconTile(glyph: "🏃", size: 44)
                    .padding(.bottom, 14)

                Text("Run without a goal")
                    .glmText(.rowTitle)
                    .padding(.bottom, 4)

                Text("Just head out. Distance, time and pace are tracked, and you'll still hear your splits. No cues or targets.")
                    .glmText(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .glmCard(.featured)

            Text("Finish whenever you tap End. It's logged the same way as a goal run.")
                .glmText(.caption)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)
        }
    }

    // MARK: - Reusable pieces

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .glmEyebrow()
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
    }

    private func groupedCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(GLM.surface)
            .clipShape(RoundedRectangle(cornerRadius: GLM.Radius.card, style: .continuous))
    }

    private func goalRow(
        title: String,
        detail: String,
        estimate: String,
        personalBest: String?,
        isActive: Bool,
        showSeparator: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                radioDot(isActive: isActive)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).glmText(.rowTitle)

                    HStack(spacing: 6) {
                        Text(estimate)
                        if let pb = personalBest {
                            Text("·")
                            Text("PB \(pb)")
                        }
                    }
                    .glmText(.readout)
                }

                Spacer(minLength: 8)

                Text(detail).glmText(.rowValue, color: isActive ? GLM.cyan : GLM.inkMuted)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if showSeparator {
                    GLMHairline().padding(.horizontal, 18)
                }
            }
        }
        .buttonStyle(.glmPress)
    }

    private func stepperRow(
        isActive: Bool,
        valueText: String,
        onSelect: @escaping () -> Void,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    radioDot(isActive: isActive)
                    Text("Custom").glmText(.rowTitle)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.glmPress)

            Button(action: onDecrement) { stepperGlyph("−") }
                .buttonStyle(.glmPress)

            Text(valueText)
                .glmText(.rowValue, color: isActive ? GLM.cyan : GLM.ink)
                .frame(minWidth: 60)

            Button(action: onIncrement) { stepperGlyph("+") }
                .buttonStyle(.glmPress)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func stepperGlyph(_ glyph: String) -> some View {
        Text(glyph)
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(GLM.ink)
            .frame(width: 32, height: 32)
            .overlay { Circle().strokeBorder(GLM.border, lineWidth: 1) }
            .contentShape(Circle())
    }

    private func radioDot(isActive: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isActive ? GLM.purple : Color.clear)
            Circle()
                .strokeBorder(isActive ? GLM.purple : GLM.border, lineWidth: 1.5)
            if isActive {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(GLM.onAccent)
            }
        }
        .frame(width: 22, height: 22)
    }

    private func estimateCard(label: String, value: String) -> some View {
        HStack(spacing: 12) {
            GLMIconTile(glyph: "⏱️", size: 38)

            VStack(alignment: .leading, spacing: 1) {
                Text(label).glmText(.caption)
                Text(value).glmText(.rowValue)
            }
            Spacer(minLength: 0)
        }
        .glmRow(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .padding(.top, GLM.Space.cardGap)
    }

    private var startButton: some View {
        Button(action: onStart) {
            Text(ctaLabel)
        }
        .buttonStyle(.glmPrimary)
    }

    private var ctaLabel: String {
        switch healthStore.runGoal.type {
        case .open:     return "Start open run"
        case .distance: return "Start \(formatKm(healthStore.runGoal.distanceKm)) km run"
        case .time:     return "Start \(healthStore.runGoal.timeMinutes) min run"
        }
    }

    // MARK: - Estimates & formatting

    /// Predicted finish time for a distance, e.g. "~28:00" or "~1h 58m".
    private func distanceEstimate(_ km: Double) -> String {
        let totalMinutes = km * paceMinPerKm
        let hh = Int(totalMinutes) / 60
        let mm = Int(totalMinutes) % 60
        if hh > 0 {
            return String(format: "~%dh %02dm", hh, mm)
        }
        let seconds = Int((totalMinutes - totalMinutes.rounded(.down)) * 60)
        return String(format: "~%d:%02d", mm, seconds)
    }

    /// Whole numbers render without a decimal; halves keep one place (21.1).
    private func formatKm(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}

#Preview {
    let store = HealthStore()
    store.selectedRunLocation = .outdoor
    return RunConfigurationView(healthStore: store).glmScreen()
}
