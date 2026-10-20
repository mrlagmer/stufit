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

    /// Sessions (weights or cardio) completed in the current calendar week.
    var sessionsThisWeek: Int {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return sessionCountsByWeekStart[weekStart] ?? 0
    }

    /// Consecutive weeks hitting the weekly session target. The current
    /// week counts once the target is met, but an in-progress week never
    /// breaks the streak.
    var weeklyStreak: Int {
        let target = max(1, weeklySessionTarget)
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

    // MARK: - Tracked Lifts

    /// Barbell lifts that have been logged at least once, in catalogue order
    /// — the lifts worth surfacing records and streaks for.
    var trackedLifts: [Exercise] {
        let logged = Set(completedSetRecords.map(\.exerciseName))
        return ExerciseCatalog.barbellLifts.filter { logged.contains($0.name) }
    }
}

// MARK: - Progress Summary Card

/// Home-screen card showing the weekly streak, progress toward this week's
/// target, and per-lift records with success streaks.
struct ProgressSummaryCard: View {
    @ObservedObject var healthStore: HealthStore

    private var weeklyTarget: Int {
        max(1, healthStore.weeklySessionTarget)
    }

    private var liftsWithRecords: [(name: String, record: LiftRecord, streak: Int)] {
        healthStore.trackedLifts.compactMap { exercise in
            guard let record = healthStore.personalRecord(for: exercise.name) else { return nil }
            return (exercise.name, record, healthStore.liftSuccessStreak(for: exercise.name))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GLMSectionHeader("Your progress")

            weeklyStreakRow

            if !liftsWithRecords.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: GLM.Space.listGap) {
                    ForEach(liftsWithRecords, id: \.name) { lift in
                        liftTile(lift)
                    }
                }
            }
        }
        .glmCard()
    }

    @ViewBuilder
    private var weeklyStreakRow: some View {
        let streak = healthStore.weeklyStreak
        let thisWeek = min(healthStore.sessionsThisWeek, weeklyTarget)
        let targetHit = thisWeek >= weeklyTarget

        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if streak > 0 {
                    GLMBadgeTile(glyph: "🔥")
                } else {
                    GLMIconTile(glyph: "🔥")
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Weekly streak").glmText(.cardTitle)
                    Text(targetHit
                         ? "Target hit this week"
                         : "\(thisWeek) of \(weeklyTarget) sessions this week")
                        .glmText(.caption)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(streak)").glmText(.statValue, color: GLM.purple)
                    Text(streak == 1 ? "week" : "weeks").glmText(.unit)
                }
            }

            // One segment per targeted session this week
            HStack(spacing: 6) {
                ForEach(0..<weeklyTarget, id: \.self) { index in
                    RoundedRectangle(cornerRadius: GLM.Radius.bar, style: .continuous)
                        .fill(index < thisWeek ? GLM.purple : GLM.borderQuiet)
                        .frame(height: 6)
                }
            }
        }
    }

    private func liftTile(_ lift: (name: String, record: LiftRecord, streak: Int)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(lift.name).glmText(.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                if lift.streak >= 2 {
                    Text("×\(lift.streak)").glmText(.label, color: GLM.caution)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.1f", lift.record.bestWeight))
                    .glmText(.statValue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("kg").glmText(.unit)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(GLM.appBg)
        .clipShape(RoundedRectangle(cornerRadius: GLM.Radius.cardSm, style: .continuous))
    }
}
