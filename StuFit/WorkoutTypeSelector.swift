//
//  WorkoutTypeSelector.swift
//  FullFitness
//
//  Created by Copilot on 27/1/2026.
//

import SwiftUI

struct WorkoutTypeSelector: View {
    @ObservedObject var healthStore: HealthStore
    var onActivitySelected: () -> Void = {}
    
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What do you feel like doing \(timeOfDayText)?")
                .font(.headline)
                .bold()
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            
            VStack(spacing: 12) {
                // Cardio Button
                Button(action: {
                    healthStore.setWorkoutPreference(.cardio)
                    onActivitySelected()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Cardio")
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                
                // Weights Button
                Button(action: {
                    healthStore.setWorkoutPreference(.weights)
                    onActivitySelected()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "dumbbell.fill")
                            .font(.title2)
                            .foregroundColor(.primary)
                        
                        Text("Weights")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    WorkoutTypeSelector(healthStore: HealthStore())
        .padding()
}
