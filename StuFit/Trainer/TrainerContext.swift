//
//  TrainerContext.swift
//  StuFit
//
//  Everything the trainer "remembers" about you, condensed into plain text
//  for the model: recent sessions, where each lift is at, runs and walks,
//  and workouts other apps saved to Health.
//

import Foundation
import HealthKit

enum TrainingFocus: String {
    case weights
    case cardio
}

@MainActor
enum TrainerContext {

    // MARK: - Facts

    static func lastSession(_ healthStore: HealthStore) -> WorkoutSessionRecord? {
        healthStore.workoutSessionRecords.max { $0.endDate < $1.endDate }
    }

    /// Recent average pace for this activity, falling back to an easy
    /// default when there's no history.
    static func typicalPaceSeconds(for activity: CardioActivity, _ healthStore: HealthStore) -> Int {
        let kind = activity.sessionKind
        let sessions: [WorkoutSessionRecord] = healthStore.workoutSessionRecords
            .filter { $0.kind == kind }
            .sorted { $0.startDate > $1.startDate }
        let paces: [Int] = Array(sessions.compactMap { $0.paceSecondsPerKm }.prefix(3))
        guard !paces.isEmpty else { return activity == .walk ? 660 : 360 }
        return paces.reduce(0, +) / paces.count
    }

    /// The trainer's lean for today: alternate with whatever was done last,
    /// and lift if it's been a while since the last weights session.
    static func recommendedFocus(_ healthStore: HealthStore) -> (focus: TrainingFocus, reason: String) {
        guard let last = lastSession(healthStore) else {
            return (.weights, "Let's get a baseline on your lifts.")
        }
        let days = daysAgo(last.endDate)
        if last.kind.isCardio {
            return (.weights, "You did cardio last time, so I'd lean weights.")
        }
        if days <= 1 {
            return (.cardio, "You lifted \(days == 0 ? "today" : "yesterday"), so I'd lean cardio to let your legs recover.")
        }
        return (.weights, "Your lifts are ready to move up, so I'd lean weights.")
    }

    static func greeting(_ healthStore: HealthStore) -> String {
        let hello = GLMFormat.greeting
        guard let last = lastSession(healthStore) else {
            return "\(hello)! I'm your coach. This is our first session, so I'll start you off easy. How long have you got at the gym today?"
        }
        return "\(hello)! Last time was \(relativeDay(last.endDate)): \(describe(last)). How long have you got today?"
    }

    // MARK: - Model context

    static func summary(
        _ healthStore: HealthStore,
        externalWorkouts: [HKWorkout],
        stepsToday: Double?
    ) -> String {
        var lines: [String] = []
        let now = Date()
        lines.append("Today: \(dayFormatter.string(from: now)), \(GLMFormat.timeOfDay).")
        if let steps = stepsToday {
            lines.append("Steps so far today: \(Int(steps)).")
        }
        if let last = lastSession(healthStore) {
            lines.append("Days since last session: \(daysAgo(last.endDate)).")
        } else {
            lines.append("No sessions logged yet — this is their first.")
        }
        lines.append("Weekly target: \(healthStore.weeklySessionTarget) sessions. Done this week: \(healthStore.sessionsThisWeek). Weekly streak: \(healthStore.weeklyStreak).")

        let recent = healthStore.workoutSessionRecords
            .sorted { $0.startDate > $1.startDate }
            .prefix(8)
        if !recent.isEmpty {
            lines.append("")
            lines.append("Recent sessions in this app (newest first):")
            for record in recent {
                lines.append("- \(dayFormatter.string(from: record.startDate)): \(describe(record))")
            }
        }

        lines.append("")
        lines.append("Lifts:")
        for entry in ExerciseCatalog.entries {
            lines.append("- \(liftStatus(entry.name, healthStore))")
        }

        let ownBundle = Bundle.main.bundleIdentifier
        let others = externalWorkouts.filter { $0.sourceRevision.source.bundleIdentifier != ownBundle }
        if !others.isEmpty {
            lines.append("")
            lines.append("Other workouts saved to Apple Health in the last 7 days:")
            for workout in others.prefix(6) {
                var line = "- \(dayFormatter.string(from: workout.startDate)): \(activityName(workout.workoutActivityType)), \(Int(workout.duration / 60)) min"
                if let meters = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meter()), meters > 0 {
                    line += ", \(String(format: "%.1f", meters / 1000)) km"
                }
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func liftStatus(_ name: String, _ healthStore: HealthStore) -> String {
        let sets = healthStore.completedSetRecords.filter { $0.exerciseName == name && !$0.isWarmup }
        guard let latest = sets.max(by: { $0.completedDate < $1.completedDate }) else {
            return "\(name): never logged."
        }
        let lastSets = sets.filter { $0.workoutId == latest.workoutId }
        let missed = lastSets.contains { $0.didFail }
        var parts = ["\(name): last done \(relativeDay(latest.completedDate))"]

        if let exercise = ExerciseCatalog.exercise(named: name) {
            if exercise.isTimedExercise {
                let best = lastSets.map(\.actualReps).max() ?? 0
                parts.append("\(lastSets.count) holds, best \(best)s")
            } else if exercise.isBodyweightExercise || latest.weight <= 0 {
                parts.append("\(lastSets.count) sets of up to \(lastSets.map(\.actualReps).max() ?? 0) reps")
            } else {
                parts.append("\(lastSets.count)×\(latest.targetReps) at \(GLMFormat.kg(lastSets.map(\.weight).max() ?? latest.weight))")
                parts.append("next working weight \(GLMFormat.kg(healthStore.getNextWorkWeight(for: exercise)))")
                if let record = healthStore.personalRecord(for: name) {
                    parts.append("best \(GLMFormat.kg(record.bestWeight))")
                }
            }
        }
        parts.append(missed ? "missed reps last time" : "all reps hit")
        let streak = healthStore.liftSuccessStreak(for: name)
        if streak >= 2 { parts.append("\(streak) successful sessions in a row") }
        return parts.joined(separator: ", ") + "."
    }

    // MARK: - Formatting

    static func describe(_ record: WorkoutSessionRecord) -> String {
        var text = record.kind.isCardio ? record.workoutName : "\(record.workoutName) (weights)"
        text += ", \(max(1, Int(record.duration / 60))) min"
        if let km = record.distanceKm {
            text += ", \(String(format: "%.1f", km)) km"
        }
        if let pace = record.paceSecondsPerKm {
            text += " at \(pace / 60):\(String(format: "%02d", pace % 60))/km"
        }
        if record.status == .endedEarly {
            text += ", ended early"
        }
        return text
    }

    static func daysAgo(_ date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
    }

    static func relativeDay(_ date: Date) -> String {
        switch daysAgo(date) {
        case 0: return "earlier today"
        case 1: return "yesterday"
        case let days: return "\(days) days ago"
        }
    }

    private static func activityName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Ride"
        case .swimming: return "Swim"
        case .hiking: return "Hike"
        case .rowing: return "Row"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        default: return "Workout"
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter
    }()
}
