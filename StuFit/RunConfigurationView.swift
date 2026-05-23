//
//  RunConfigurationView.swift
//  FullFitness
//
//  Created by Copilot on 31/3/2026.
//  Redesigned 20/5/2026 from the "StuFit — New Run" design (Variant A, refined):
//  Distance / Time / Open segmented control, a single grouped card of preset
//  goals with an inline custom stepper, a pace estimate, and a dynamic CTA.
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

    private var accent: Color { .accentColor }
    private var cardBackground: Color { Color(.secondarySystemGroupedBackground) }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                Picker("Goal Type", selection: $healthStore.runGoal.type) {
                    ForEach(RunGoalType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 8)

                Group {
                    switch healthStore.runGoal.type {
                    case .distance: distanceSection
                    case .time:     timeSection
                    case .open:     openSection
                    }
                }
                .padding(.top, 18)

                startButton
                    .padding(.top, 22)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
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
        .animation(.easeInOut(duration: 0.2), value: healthStore.runGoal.type)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Cardio")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(accent)
                }

                Spacer()

                Button(action: toggleLocation) {
                    HStack(spacing: 6) {
                        Image(systemName: location.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(location.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(accent)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 11)
                    .background(accent.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .frame(minHeight: 32)
            .padding(.top, 8)

            Text("New run")
                .font(.system(size: 34, weight: .bold))
                .padding(.top, 6)

            Text("Pick a target and we'll cue you through it. Or just head out.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .padding(.top, 2)
                .padding(.bottom, 14)
        }
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
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Circle().fill(accent.opacity(0.1))
                    Image(systemName: "figure.run")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(accent)
                }
                .frame(width: 44, height: 44)
                .padding(.bottom, 14)

                Text("Run without a goal")
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.bottom, 6)

                Text("Just head out — we'll track distance, time and pace. No cues or targets, but you'll still see your splits.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                Text("Tip — you can finish whenever you tap End. We'll log it the same way as a goal run.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Reusable pieces

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
    }

    private func groupedCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: isActive ? .semibold : .medium))
                        .foregroundColor(.primary)

                    HStack(spacing: 6) {
                        Text(estimate)
                        if let pb = personalBest {
                            Text("·").opacity(0.4)
                            Text("PB \(pb)")
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                }

                Spacer(minLength: 8)

                Text(detail)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if showSeparator {
                    Rectangle()
                        .fill(Color(.separator).opacity(0.6))
                        .frame(height: 0.5)
                }
            }
        }
        .buttonStyle(.plain)
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
                    Text("Custom")
                        .font(.system(size: 17, weight: isActive ? .semibold : .medium))
                        .foregroundColor(.primary)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onDecrement) { stepperGlyph("minus") }
                .buttonStyle(.plain)

            Text(valueText)
                .font(.system(size: 17, weight: .semibold))
                .monospacedDigit()
                .frame(minWidth: 60)

            Button(action: onIncrement) { stepperGlyph("plus") }
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func stepperGlyph(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.primary)
            .frame(width: 30, height: 30)
            .background(Color(.tertiarySystemFill))
            .clipShape(Circle())
    }

    private func radioDot(isActive: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isActive ? accent : Color.clear)
            Circle()
                .strokeBorder(isActive ? accent : Color(.tertiaryLabel), lineWidth: 2)
            if isActive {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 22, height: 22)
    }

    private func estimateCard(label: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(accent.opacity(0.1))
                Image(systemName: "stopwatch")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(accent)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.top, 14)
    }

    private var startButton: some View {
        Button(action: onStart) {
            HStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .font(.system(size: 16, weight: .semibold))
                Text(ctaLabel)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(accent)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: accent.opacity(0.32), radius: 7, x: 0, y: 4)
        }
        .buttonStyle(.plain)
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
    return RunConfigurationView(healthStore: store)
}
