//
//  WorkoutHistoryView.swift
//  FullFitness
//
//  Created by Copilot on 25/2/2026.
//

import SwiftUI

struct WorkoutHistoryView: View {
    @ObservedObject var healthStore: HealthStore

    private var sortedSessions: [WorkoutSessionRecord] {
        healthStore.workoutSessionRecords.sorted { $0.startDate > $1.startDate }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    var body: some View {
        Group {
            if sortedSessions.isEmpty {
                ContentUnavailableView(
                    "No Workouts Yet",
                    systemImage: "figure.strengthtraining.traditional",
                    description: Text("Your completed sessions will show up here after you finish a workout.")
                )
            } else {
                List {
                    ForEach(sortedSessions) { session in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.workoutName)
                                        .font(.headline)
                                    Text(Self.dateFormatter.string(from: session.startDate))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(statusLabel(for: session.status))
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(statusColor(for: session.status).opacity(0.18))
                                    .foregroundColor(statusColor(for: session.status))
                                    .clipShape(Capsule())
                            }

                            HStack(spacing: 14) {
                                Label(formattedDuration(session.duration), systemImage: "timer")
                                Label(formattedEndDate(session.endDate), systemImage: "calendar")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Workout History")
    }

    private func statusLabel(for status: WorkoutSessionStatus) -> String {
        switch status {
        case .completed:
            return "Completed"
        case .endedEarly:
            return "Ended Early"
        }
    }

    private func statusColor(for status: WorkoutSessionStatus) -> Color {
        switch status {
        case .completed:
            return .green
        case .endedEarly:
            return .orange
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        Self.durationFormatter.string(from: max(0, duration)) ?? "0s"
    }

    private func formattedEndDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

#Preview {
    NavigationView {
        WorkoutHistoryView(healthStore: HealthStore())
    }
}
