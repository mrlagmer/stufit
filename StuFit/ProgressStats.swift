//
//  ProgressStats.swift
//  StuFit
//
//  Derived stats for streaks and personal records. Everything here is
//  computed from `completedSetRecords` and `workoutSessionRecords`, so no
//  new persistence is required and history from before this feature counts.
//

import Foundation
import SwiftUI

/// Best successful top set for a lift.
struct LiftRecord {
    let exerciseName: String
    let bestWeight: Double
    let achievedDate: Date
}

/// One logged attempt at a lift (all work sets from a single workout).
private struct LiftAttempt {
    let date: Date
    let succeeded: Bool
}

extension HealthStore {

    // MARK: - Personal Records

    /// Heaviest work-set weight lifted for the full target reps (warmups and
    /// failed sets excluded). Nil if the lift has never been logged.
    func personalRecord(for exerciseName: String) -> LiftRecord? {
        let successfulWorkSets = completedSetRecords.filter {
            $0.exerciseName == exerciseName && !$0.isWarmup && !$0.didFail && $0.weight > 0
        }
        guard let bestWeight = successfulWorkSets.map({ $0.weight }).max() else { return nil }
        let achievedDate = successfulWorkSets
            .filter { abs($0.weight - bestWeight) < 0.001 }
            .map { $0.completedDate }
            .min() ?? Date()
        return LiftRecord(exerciseName: exerciseName, bestWeight: bestWeight, achievedDate: achievedDate)
    }

    /// If completing these work sets would beat the lift's existing record,
    /// returns the new record weight. First-ever sessions don't celebrate —
    /// there's no previous best to beat.
    func newRecordWeight(exerciseName: String, successfulWorkSetWeights: [Double]) -> Double? {
        guard let attemptBest = successfulWorkSetWeights.max(), attemptBest > 0 else { return nil }
        guard let previous = personalRecord(for: exerciseName) else { return nil }
        return attemptBest > previous.bestWeight ? attemptBest : nil
    }

    // MARK: - Per-Lift Streaks

    /// Consecutive sessions (counting back from the most recent) where every
    /// work set of this lift hit its target reps.
    func liftSuccessStreak(for exerciseName: String) -> Int {
        let workSets = completedSetRecords.filter {
            $0.exerciseName == exerciseName && !$0.isWarmup
        }
        guard !workSets.isEmpty else { return 0 }

        let attempts = Dictionary(grouping: workSets, by: { $0.workoutId })
            .values
            .map { sets in
                LiftAttempt(
                    date: sets.map { $0.completedDate }.min() ?? Date(),
                    succeeded: !sets.contains { $0.didFail }
                )
            }
            .sorted { $0.date > $1.date }

        var streak = 0
        for attempt in attempts {
            guard attempt.succeeded else { break }
            streak += 1
        }
        return streak
    }

    // MARK: - Weekly Streak

    private var sessionCountsByWeekStart: [Date: Int] {
        let calendar = Calendar.current
        return workoutSessionRecords.reduce(into: [:]) { counts, record in
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: record.startDate)?.start
                ?? calendar.startOfDay(for: record.startDate)
            counts[weekStart, default: 0] += 1
        }
    }

    /// Weights sessions completed in the current calendar week.
    var sessionsThisWeek: Int {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return sessionCountsByWeekStart[weekStart] ?? 0
    }

    /// Consecutive weeks hitting the active program's days-per-week target.
    /// The current week counts once the target is met, but an in-progress
    /// week never breaks the streak.
    var weeklyStreak: Int {
        guard let program = activeWeightProgram, program.isActive else { return 0 }
        let target = max(1, program.daysPerWeek)
        let calendar = Calendar.current
        let counts = sessionCountsByWeekStart

        guard var weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }

        var streak = (counts[weekStart] ?? 0) >= target ? 1 : 0
        while let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) {
            weekStart = previous
            if (counts[weekStart] ?? 0) >= target {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Program Lifts

    /// The unique barbell lifts in the active program, in program order —
    /// the lifts worth surfacing records and streaks for.
    var activeProgramLifts: [Exercise] {
        guard let program = activeWeightProgram, program.isActive,
              let template = WorkoutProgramTemplate.getProgram(for: program.daysPerWeek) else { return [] }

        var seen = Set<String>()
        var lifts: [Exercise] = []
        for workout in template.workouts {
            for exercise in workout.exercises where exercise.usesBarbellLoading {
                if seen.insert(exercise.name).inserted {
                    lifts.append(exercise)
                }
            }
        }
        return lifts
    }
}

// MARK: - Progress Summary Card

/// Home-screen card showing the weekly streak, progress toward this week's
/// target, and per-lift records with success streaks.
struct ProgressSummaryCard: View {
    @ObservedObject var healthStore: HealthStore

    private var weeklyTarget: Int {
        max(1, healthStore.activeWeightProgram?.daysPerWeek ?? 1)
    }

    private var liftsWithRecords: [(name: String, record: LiftRecord, streak: Int)] {
        healthStore.activeProgramLifts.compactMap { exercise in
            guard let record = healthStore.personalRecord(for: exercise.name) else { return nil }
            return (exercise.name, record, healthStore.liftSuccessStreak(for: exercise.name))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your Progress")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }

            weeklyStreakRow

            if !liftsWithRecords.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(liftsWithRecords, id: \.name) { lift in
                        liftChip(lift)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var weeklyStreakRow: some View {
        let streak = healthStore.weeklyStreak
        let thisWeek = min(healthStore.sessionsThisWeek, weeklyTarget)

        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundColor(streak > 0 ? .orange : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(streak == 1 ? "1 week streak" : "\(streak) week streak")
                    .font(.headline)
                Text(thisWeek >= weeklyTarget
                     ? "Target hit this week — streak safe!"
                     : "\(thisWeek) of \(weeklyTarget) workouts this week")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // One dot per program day this week
            HStack(spacing: 5) {
                ForEach(0..<weeklyTarget, id: \.self) { index in
                    Circle()
                        .fill(index < thisWeek ? Color.orange : Color(.tertiarySystemBackground))
                        .frame(width: 10, height: 10)
                }
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func liftChip(_ lift: (name: String, record: LiftRecord, streak: Int)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(lift.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                if lift.streak >= 2 {
                    HStack(spacing: 1) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                        Text("\(lift.streak)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.orange)
                }
            }
            HStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
                Text(String(format: "%.1f kg", lift.record.bestWeight))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
