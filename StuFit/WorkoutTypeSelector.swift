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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What do you feel like doing \(GLMFormat.timeOfDay)?")
                .glmText(.rowTitle)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: GLM.Space.listGap) {
                optionRow(glyph: "🏃", title: "Cardio", subtitle: "Run, walk or ride") {
                    healthStore.setWorkoutPreference(.cardio)
                    onActivitySelected()
                }
                optionRow(glyph: "🏋️", title: "Weights", subtitle: "Your program's next session") {
                    healthStore.setWorkoutPreference(.weights)
                    onActivitySelected()
                }
            }
        }
        .glmCard()
    }

    private func optionRow(glyph: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                GLMIconTile(glyph: glyph, fill: GLM.surface)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).glmText(.rowTitle)
                    Text(subtitle).glmText(.caption)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(GLM.inkMuted)
            }
            .glmRow(.inset)
        }
        .buttonStyle(.glmPress)
    }
}

#Preview {
    WorkoutTypeSelector(healthStore: HealthStore())
        .padding()
        .glmScreen()
}
