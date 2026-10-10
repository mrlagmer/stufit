//
//  ActivityTypeSelector.swift
//  FullFitness
//
//  Created by Copilot on 30/1/2026.
//

import SwiftUI

extension ActivityType {
    /// Emoji glyph for the activity tile — the product's icon system.
    var glyph: String {
        switch self {
        case .run: return "🏃"
        case .walk: return "🚶"
        case .ride: return "🚴"
        case .bench, .squat, .deadlift: return "🏋️"
        }
    }
}

struct ActivityTypeSelector: View {
    @ObservedObject var healthStore: HealthStore
    var onBack: () -> Void = {}
    var onRunLocationSelected: () -> Void = {}
    @GestureState private var swipeOffset: CGFloat = 0

    var availableActivities: [ActivityType] {
        guard let workoutType = healthStore.selectedWorkoutType else {
            return []
        }
        return healthStore.getActivitiesForWorkoutType(workoutType)
    }

    private var typeName: String {
        healthStore.selectedWorkoutType?.rawValue.lowercased() ?? "workout"
    }

    var body: some View {
        VStack(spacing: 0) {
            GLMScreenHeader(healthStore.selectedWorkoutType?.rawValue ?? "", onBack: onBack)

            ScrollView {
                VStack(spacing: GLM.Space.cardGap) {
                    if healthStore.isGeneratingAdvice || healthStore.suggestion != nil {
                        suggestionCard
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("What type of \(typeName) would you like to do \(GLMFormat.timeOfDay)?")
                            .glmText(.rowTitle)
                            .lineLimit(3)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: GLM.Space.listGap) {
                            ForEach(availableActivities) { activity in
                                let isSelected = healthStore.selectedActivityType == activity
                                activityRow(activity, isSelected: isSelected)

                                if activity == .run && isSelected {
                                    HStack(spacing: 8) {
                                        ForEach(RunLocationType.allCases) { location in
                                            GLMChip(
                                                title: location.rawValue,
                                                selected: healthStore.selectedRunLocation == location,
                                                small: true
                                            ) {
                                                healthStore.setRunLocation(location)
                                                onRunLocationSelected()
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.leading, 55)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                        .animation(.easeInOut(duration: 0.15), value: healthStore.selectedActivityType)
                        .animation(.easeInOut(duration: 0.15), value: healthStore.selectedRunLocation)
                    }
                    .glmCard()
                }
                .padding(.horizontal, GLM.Space.gutter)
                .padding(.top, GLM.Space.cardGap)
                .padding(.bottom, 32)
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
    }

    private var suggestionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            GLMSectionHeader("Suggestion") {
                if healthStore.isGeneratingAdvice {
                    ProgressView().controlSize(.small).tint(GLM.inkMuted)
                }
            }

            if let suggestion = healthStore.suggestion {
                Text(suggestion)
                    .glmText(.body, color: GLM.inkBody)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.easeInOut(duration: 0.15), value: suggestion)
            } else {
                HStack(spacing: 6) {
                    Text("Thinking about your week").glmText(.body)
                    TypingIndicator()
                }
            }
        }
        .glmCard()
    }

    private func activityRow(_ activity: ActivityType, isSelected: Bool) -> some View {
        Button(action: {
            healthStore.selectedRunLocation = nil
            healthStore.setActivityPreference(activity)
        }) {
            HStack(spacing: 13) {
                GLMIconTile(glyph: activity.glyph, fill: isSelected ? GLM.surfaceRaised : GLM.surface)
                Text(activity.rawValue).glmText(.rowTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(GLM.purple)
                }
            }
            .glmRow(isSelected ? .outline : .inset)
            .background(
                RoundedRectangle(cornerRadius: GLM.Radius.cardSm, style: .continuous)
                    .fill(isSelected ? GLM.appBg : Color.clear)
            )
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

#Preview {
    NavigationStack {
        ActivityTypeSelector(healthStore: HealthStore(), onBack: {})
    }
    .glmScreen()
}
