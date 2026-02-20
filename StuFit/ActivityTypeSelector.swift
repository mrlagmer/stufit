//
//  ActivityTypeSelector.swift
//  FullFitness
//
//  Created by Copilot on 30/1/2026.
//

import SwiftUI

struct ActivityTypeSelector: View {
    @ObservedObject var healthStore: HealthStore
    var onBack: () -> Void = {}
    @GestureState private var swipeOffset: CGFloat = 0
    
    private var timeOfDayText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "this morning"
        case 12..<17:
            return "this afternoon"
        case 17..<21:
            return "this evening"
        default:
            return "tonight"
        }
    }
    
    var availableActivities: [ActivityType] {
        guard let workoutType = healthStore.selectedWorkoutType else {
            return []
        }
        return healthStore.getActivitiesForWorkoutType(workoutType)
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header with back button
                    HStack {
                        Button(action: onBack) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundColor(.blue)
                        }
                        Spacer()
                        Text(healthStore.selectedWorkoutType?.rawValue ?? "")
                            .font(.headline)
                            .bold()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(16)
                    
                    // AI Activity suggestion (shown first)
                    if healthStore.isGeneratingAdvice || healthStore.suggestion != nil {
                        VStack(alignment: .leading, spacing: 12) {
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
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    
                    // Activity selection prompt
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What type of \(healthStore.selectedWorkoutType?.rawValue.lowercased() ?? "workout") would you like to do \(timeOfDayText)?")
                            .font(.headline)
                            .bold()
                            .lineLimit(3)
                            .minimumScaleFactor(0.85)
                        
                        // Activity buttons
                        VStack(spacing: 12) {
                            ForEach(availableActivities) { activity in
                                let isSelected = healthStore.selectedActivityType == activity
                                Button(action: {
                                    healthStore.setActivityPreference(activity)
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: activity.icon)
                                            .font(.title2)
                                            .foregroundColor(isSelected ? .white : .primary)
                                            .frame(width: 30)
                                        
                                        Text(activity.rawValue)
                                            .font(.headline)
                                            .foregroundColor(isSelected ? .white : .primary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.85)
                                        
                                        Spacer()
                                        
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
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
                    
                    Spacer()
                }
                .padding(16)
            }
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
    }
}

#Preview {
    NavigationView {
        ActivityTypeSelector(healthStore: HealthStore(), onBack: {})
    }
}
