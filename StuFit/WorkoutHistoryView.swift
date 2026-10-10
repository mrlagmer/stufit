//
//  WorkoutHistoryView.swift
//  FullFitness
//
//  Created by Copilot on 25/2/2026.
//

import SwiftUI

struct WorkoutHistoryView: View {
    @ObservedObject var healthStore: HealthStore
    @Environment(\.dismiss) private var dismiss

    private var sortedSessions: [WorkoutSessionRecord] {
        healthStore.workoutSessionRecords.sorted { $0.startDate > $1.startDate }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var sessionsThisWeek: Int { healthStore.sessionsThisWeek }

    private var activeTimeThisWeek: TimeInterval {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return healthStore.workoutSessionRecords
            .filter { $0.startDate >= weekStart }
            .reduce(0) { $0 + max(0, $1.duration) }
    }

    /// Sessions grouped by calendar day, newest first.
    private var groupedSessions: [(label: String, sessions: [WorkoutSessionRecord])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: sortedSessions) { calendar.startOfDay(for: $0.startDate) }
        return groups.keys.sorted(by: >).map { day in
            (label: dayLabel(day), sessions: groups[day] ?? [])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            GLMScreenHeader("Workouts", onBack: { dismiss() })

            if sortedSessions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: GLM.Space.listGap) {
                        HStack(spacing: 10) {
                            GLMStatTile(value: "\(sessionsThisWeek)", label: "this week")
                            GLMStatTile(value: formattedDuration(activeTimeThisWeek), label: "active time")
                            GLMStatTile(value: GLMFormat.count(sortedSessions.count), label: "all time", tone: GLM.cyan)
                        }
                        .padding(.bottom, 6)

                        ForEach(groupedSessions, id: \.label) { group in
                            Text(group.label)
                                .glmEyebrow()
                                .padding(.horizontal, 6)
                                .padding(.top, 8)

                            ForEach(group.sessions) { session in
                                sessionRow(session)
                            }
                        }
                    }
                    .padding(.horizontal, GLM.Space.gutterTight)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .glmScreen()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            GLMIconTile(glyph: "🏋️", size: 56, fill: GLM.surface)
            Text("No workouts yet").glmText(.rowTitle)
            Text("Finished sessions show up here, grouped by day.")
                .glmText(.body)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(GLM.Space.gutter)
    }

    private func sessionRow(_ session: WorkoutSessionRecord) -> some View {
        HStack(spacing: 13) {
            GLMIconTile(glyph: "🏋️")
            VStack(alignment: .leading, spacing: 2) {
                Text(session.workoutName).glmText(.rowTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text("\(Self.timeFormatter.string(from: session.startDate)) · \(formattedDuration(session.duration))")
                    .glmText(.readout)
            }
            Spacer()
            GLMTag(text: statusLabel(for: session.status), color: statusColor(for: session.status), dot: true)
        }
        .glmRow()
    }

    private func dayLabel(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return Self.dayFormatter.string(from: day)
    }

    private func statusLabel(for status: WorkoutSessionStatus) -> String {
        switch status {
        case .completed:
            return "Completed"
        case .endedEarly:
            return "Ended early"
        }
    }

    private func statusColor(for status: WorkoutSessionStatus) -> Color {
        switch status {
        case .completed:
            return GLM.success
        case .endedEarly:
            return GLM.atRisk
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        if duration < 60 { return "\(Int(max(0, duration)))s" }
        return Self.durationFormatter.string(from: max(0, duration)) ?? "0m"
    }
}

#Preview {
    NavigationStack {
        WorkoutHistoryView(healthStore: HealthStore())
    }
}
