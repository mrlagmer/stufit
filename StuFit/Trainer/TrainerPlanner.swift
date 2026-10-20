//
//  TrainerPlanner.swift
//  StuFit
//
//  Turns check-in answers + history into today's session. The model picks
//  exercises, volume and cues; deterministic rules then set the loads (via
//  the existing progression), validate the plan, and trim it to fit the
//  time available. If no model is reachable, a rule-based plan stands in.
//

import Foundation
import FoundationModels
import HealthKit

// MARK: - Generated drafts

@Generable
nonisolated struct PlannedLift {
    @Guide(description: "Exercise name, exactly as written in the allowed list", .anyOf([
        "Squats", "Deadlift", "Romanian Deadlift", "Bench Press", "Overhead Press",
        "Barbell Rows", "Pull Ups", "Dumbbell Lunges", "Roman Sit Ups", "Plank"
    ]))
    var name: String

    @Guide(description: "Number of work sets", .range(1...5))
    var sets: Int

    @Guide(description: "Reps per work set. For Plank, the seconds to hold.", .range(1...90))
    var reps: Int

    @Guide(description: "One short form cue for this exercise, spoken before the first set. Under 20 words.")
    var cue: String
}

@Generable
nonisolated struct WeightsPlanDraft {
    @Guide(description: "Short session title, e.g. 'Lower body strength'")
    var title: String

    @Guide(description: "What you say to introduce today's session, referencing their recent training. Two or three sentences, read aloud.")
    var intro: String

    @Guide(description: "Exercises in the order they'll be done", .count(1...6))
    var exercises: [PlannedLift]

    @Guide(description: "Rest between work sets in seconds", .range(60...180))
    var restSeconds: Int
}

@Generable
nonisolated struct CardioPlanDraft {
    @Guide(description: "Short session title, e.g. 'Easy 5k'")
    var title: String

    @Guide(description: "What you say to introduce today's session, referencing their recent cardio. Two or three sentences, read aloud.")
    var intro: String

    @Guide(description: "'distance' for a distance target, or 'time' for a time target", .anyOf(["distance", "time"]))
    var goalType: String

    @Guide(description: "Target distance in kilometres, used when goalType is distance", .range(0.5...42.0))
    var distanceKm: Double

    @Guide(description: "Target minutes, used when goalType is time", .range(5...180))
    var minutes: Int

    @Guide(description: "Short coaching cues to speak during the session, one after each kilometre. Under 15 words each.", .count(2...4))
    var cues: [String]
}

// MARK: - Plan

struct CardioPlan {
    let activity: CardioActivity
    let outdoor: Bool
    let goal: RunGoal
    let cues: [String]
}

struct TrainerPlan {
    enum Content {
        case weights(ProgramWorkout, restSeconds: Int, cues: [String: String])
        case cardio(CardioPlan)
    }

    let title: String
    let intro: String
    let content: Content
    let estimatedMinutes: Int
    /// Changes the rules made to the model's draft, shown under the plan.
    let adjustments: [String]
    /// Nil when the plan is rule-based because no model was reachable.
    let provider: TrainerModelProvider?

    /// One line per item, so the model can revise a plan it proposed.
    var summaryForModel: String {
        switch content {
        case .weights(let workout, let rest, _):
            let lifts = workout.exercises.map { "\($0.name) \($0.sets)×\($0.reps)" }.joined(separator: ", ")
            return "\(title): \(lifts); \(rest)s rest."
        case .cardio(let plan):
            return "\(title): \(plan.goal.type == .time ? "\(plan.goal.timeMinutes) min" : String(format: "%.1f km", plan.goal.distanceKm)) \(plan.activity.noun), \(plan.outdoor ? "outdoor" : "treadmill")."
        }
    }
}

struct TrainerAnswers {
    var minutes: Int = 45
    var focus: TrainingFocus = .weights
    var cardioActivity: CardioActivity = .run
    var outdoor: Bool = true
    var feeling: String = "Normal"
    /// Free-text requests, in order ("no deadlifts, back is sore").
    var notes: [String] = []
}

// MARK: - Planner

@MainActor
final class TrainerPlanner {
    private let ai = TrainerAI()
    private let warmupRestSeconds = 60
    /// Arrival, general warm-up and cool-down outside the planned work.
    private let bufferMinutes = 5
    /// Weights warm up with ramp sets inside the plan, so only setup sits outside it.
    private let weightsBufferMinutes = 2
    /// A weights plan this far under the time available gets filled out.
    private let fillToleranceMinutes = 3

    func buildPlan(
        answers: TrainerAnswers,
        previous: TrainerPlan?,
        healthStore: HealthStore
    ) async -> TrainerPlan {
        let workouts = await healthStore.fetchRecentWorkouts()
        let steps = await healthStore.fetchStepCountToday()
        let context = TrainerContext.summary(healthStore, externalWorkouts: workouts, stepsToday: steps)
        let timing = answers.focus == .weights ? timingGuide(minutes: answers.minutes, healthStore: healthStore) : nil
        let prompt = Self.prompt(answers: answers, previous: previous, context: context, timing: timing)

        do {
            switch answers.focus {
            case .weights:
                let (draft, provider) = try await ai.generate(WeightsPlanDraft.self, instructions: Self.instructions, prompt: prompt)
                if let plan = weightsPlan(from: draft, answers: answers, provider: provider, healthStore: healthStore) {
                    return await filledWeightsPlan(plan, answers: answers, context: context, timing: timing, healthStore: healthStore)
                }
            case .cardio:
                let (draft, provider) = try await ai.generate(CardioPlanDraft.self, instructions: Self.instructions, prompt: prompt)
                return cardioPlan(from: draft, answers: answers, provider: provider, healthStore: healthStore)
            }
        } catch {
            print("Trainer plan generation failed: \(error.localizedDescription)")
        }
        return fallbackPlan(answers: answers, healthStore: healthStore)
    }

    // MARK: Prompting

    private static var instructions: String {
        let catalogue = ExerciseCatalog.entries
            .map { "- \($0.name) (\($0.pattern))" }
            .joined(separator: "\n")
        return """
        You are Coach, a personal trainer working one-on-one with the user at the gym. \
        You know their training history. Plan today's session to fit the time they have, \
        how they feel, and what they did recently.

        Weights rules:
        - Only use these exercises:
        \(catalogue)
        - Put the heaviest compound lifts first and core work last.
        - Don't repeat the main movement pattern from a session in the last 48 hours if you can avoid it. \
        Balance push, pull, legs and core across the week.
        - Don't choose weights. The app sets every load from the user's progression; you may mention their recent numbers.
        - Strength work is usually 5 sets of 5 (Deadlift is often 1 set of 5). Use fewer sets when time is short.
        - Use the timing guide in the check-in to fill the time they have. Aim to finish within a few \
        minutes of it: not over, and not well under. Add another lift or more sets rather than finishing early.

        Cardio rules:
        - Choose a distance or time target that fits inside their time with 5 minutes spare for warm-up.
        - Base distance on their recent pace. Build gradually; never jump more than about 10% past their recent longest.

        Everyone:
        - If they're tired or sore, or it's been more than a week since their last session, reduce volume and say so.
        - Honour any specific requests they make.
        - Talk like a real trainer: warm, direct and concise. Intros and cues are read aloud, \
        so write plain spoken English with no emojis, lists or markdown.
        """
    }

    private static func prompt(answers: TrainerAnswers, previous: TrainerPlan?, context: String, timing: String?) -> String {
        var lines = [
            "Training history:",
            context,
            "",
            "Today's check-in:",
            "- Time available: \(answers.minutes) minutes"
        ]
        switch answers.focus {
        case .weights:
            lines.append("- They want to lift weights.")
        case .cardio:
            lines.append("- They want cardio: a \(answers.cardioActivity.noun), \(answers.outdoor ? "outdoors" : "on the treadmill").")
        }
        lines.append("- How they feel: \(answers.feeling)")
        if let timing {
            lines.append("")
            lines.append(timing)
        }
        if let previous {
            lines.append("")
            lines.append("You proposed: \(previous.summaryForModel)")
        }
        if !answers.notes.isEmpty {
            lines.append("")
            lines.append("What they've told you:")
            lines.append(contentsOf: answers.notes.map { "- \($0)" })
        }
        lines.append("")
        lines.append("Plan today's session.")
        return lines.joined(separator: "\n")
    }

    // MARK: Weights

    private func weightsPlan(
        from draft: WeightsPlanDraft,
        answers: TrainerAnswers,
        provider: TrainerModelProvider,
        healthStore: HealthStore
    ) -> TrainerPlan? {
        var seen = Set<String>()
        var exercises: [Exercise] = []
        var cues: [String: String] = [:]
        for lift in draft.exercises {
            guard let base = ExerciseCatalog.exercise(named: lift.name), seen.insert(base.name).inserted else { continue }
            let sets = min(max(lift.sets, 1), 5)
            let reps = base.isTimedExercise ? "\(min(max(lift.reps, 15), 90)) Seconds" : "\(min(max(lift.reps, 1), 20))"
            exercises.append(Exercise(name: base.name, sets: sets, reps: reps))
            cues[base.name] = lift.cue
        }
        guard !exercises.isEmpty else { return nil }

        let rest = min(max(draft.restSeconds, 60), 180)
        return fittedWeightsPlan(
            title: draft.title,
            intro: draft.intro,
            exercises: exercises,
            rest: rest,
            cues: cues,
            minutes: answers.minutes,
            lowEnergy: Self.isLowEnergy(answers),
            provider: provider,
            healthStore: healthStore
        )
    }

    /// When the model's plan still falls well short after filling out rest
    /// and sets, ask it once to add work. It picks what to add so requests
    /// like "no deadlifts" are still honoured; the revision is only kept if
    /// it lands closer to the time available.
    private func filledWeightsPlan(
        _ plan: TrainerPlan,
        answers: TrainerAnswers,
        context: String,
        timing: String?,
        healthStore: HealthStore
    ) async -> TrainerPlan {
        let target = weightsBudgetSeconds(minutes: answers.minutes) / 60
        guard target - plan.estimatedMinutes > fillToleranceMinutes + 2, !Self.isLowEnergy(answers) else { return plan }

        var revisionAnswers = answers
        revisionAnswers.notes.append("That plan only fills about \(plan.estimatedMinutes) of the \(target) minutes. Add another lift or more sets so it fills the time.")
        let prompt = Self.prompt(answers: revisionAnswers, previous: plan, context: context, timing: timing)
        do {
            let (draft, provider) = try await ai.generate(WeightsPlanDraft.self, instructions: Self.instructions, prompt: prompt)
            if let revised = weightsPlan(from: draft, answers: answers, provider: provider, healthStore: healthStore),
               revised.estimatedMinutes > plan.estimatedMinutes {
                return revised
            }
        } catch {
            print("Trainer plan revision failed: \(error.localizedDescription)")
        }
        return plan
    }

    /// Per-lift timings for today's weights, so the model can size the
    /// session instead of guessing.
    private func timingGuide(minutes: Int, healthStore: HealthStore) -> String {
        let target = weightsBudgetSeconds(minutes: minutes) / 60
        let rows = ExerciseCatalog.entries.compactMap { entry -> String? in
            guard let base = ExerciseCatalog.exercise(named: entry.name) else { return nil }
            let exercise = base.isTimedExercise ? Exercise(name: base.name, sets: 3, reps: "60 Seconds") : base
            let full = exerciseSeconds(exercise, rest: 180, healthStore: healthStore)
            let short = exerciseSeconds(withSets(exercise, 3), rest: 120, healthStore: healthStore)
            let setCost = exercise.isTimedExercise ? 60 + 120 : 40 + 180
            let label = exercise.isTimedExercise ? "3×60s" : "5×5"
            return "- \(entry.name): \(label) at 3 min rest ≈ \(Self.minutes(full)) min; 3 sets at 2 min rest ≈ \(Self.minutes(short)) min; each extra set ≈ \(Self.minutes(setCost)) min"
        }
        return (["Timing guide (includes warmup sets and setup). Plan about \(target) minutes in total:"] + rows)
            .joined(separator: "\n")
    }

    private func weightsBudgetSeconds(minutes: Int) -> Int {
        max(10, minutes - weightsBufferMinutes) * 60
    }

    private func maxSets(for exercise: Exercise, lowEnergy: Bool) -> Int {
        // Deadlift stays at what was planned: one heavy set is the norm.
        if exercise.name == "Deadlift" {
            return exercise.sets
        }
        let cap = exercise.usesBarbellLoading ? 5 : 3
        return lowEnergy ? min(cap, max(exercise.sets, 3)) : cap
    }

    private static func isLowEnergy(_ answers: TrainerAnswers) -> Bool {
        ["tired", "sore"].contains { answers.feeling.lowercased().contains($0) }
    }

    private static func minutes(_ seconds: Int) -> Int {
        Int((Double(seconds) / 60).rounded())
    }

    private static func restLabel(_ seconds: Int) -> String {
        seconds % 60 == 0 ? "\(seconds / 60) min" : String(format: "%.1f min", Double(seconds) / 60)
    }

    private func fittedWeightsPlan(
        title: String,
        intro: String,
        exercises initial: [Exercise],
        rest initialRest: Int,
        cues: [String: String],
        minutes: Int,
        lowEnergy: Bool,
        provider: TrainerModelProvider?,
        healthStore: HealthStore
    ) -> TrainerPlan {
        var exercises = initial
        var rest = initialRest
        var adjustments: [String] = []
        let budget = weightsBudgetSeconds(minutes: minutes)

        func estimate() -> Int { estimatedSeconds(exercises, rest: rest, healthStore: healthStore) }

        // Fill a short plan: longer rest first (up to the 3 min strength
        // lifting wants), then more sets. Low energy only gets the rest and
        // sets up to 3, so a deliberately light session stays light.
        let fillTarget = budget - fillToleranceMinutes * 60
        if estimate() < fillTarget {
            let startRest = rest
            while rest < 180, estimatedSeconds(exercises, rest: rest + 15, healthStore: healthStore) <= budget {
                rest += 15
            }
            if rest > startRest {
                adjustments.append("Rest set to \(Self.restLabel(rest)) to fill your time")
            }
            var addedSets = false
            var grew = true
            while grew, estimate() < fillTarget {
                grew = false
                for index in exercises.indices where exercises[index].sets < maxSets(for: exercises[index], lowEnergy: lowEnergy) {
                    var trial = exercises
                    trial[index] = withSets(exercises[index], exercises[index].sets + 1)
                    guard estimatedSeconds(trial, rest: rest, healthStore: healthStore) <= budget else { continue }
                    exercises = trial
                    addedSets = true
                    grew = true
                    if estimate() >= fillTarget { break }
                }
            }
            if addedSets { adjustments.append("Sets added to fill your time") }
        }

        if estimate() > budget, rest > 120 {
            rest = 120
            adjustments.append("Rest cut to 2 min to fit your time")
        }
        var trimmedSets = false
        while estimate() > budget,
              let index = exercises.indices.max(by: { exercises[$0].sets < exercises[$1].sets }),
              exercises[index].sets > 3 {
            exercises[index] = withSets(exercises[index], exercises[index].sets - 1)
            trimmedSets = true
        }
        if trimmedSets { adjustments.append("Sets trimmed to fit your time") }
        while estimate() > budget, exercises.count > 1 {
            let dropped = exercises.removeLast()
            adjustments.append("Dropped \(dropped.name) to fit \(minutes) min")
        }
        while estimate() > budget, let index = exercises.indices.first(where: { exercises[$0].sets > 1 }) {
            exercises[index] = withSets(exercises[index], exercises[index].sets - 1)
        }
        if estimate() > budget, rest > 90 {
            rest = 90
        }

        let workout = ProgramWorkout(name: title, exercises: exercises)
        return TrainerPlan(
            title: title,
            intro: intro,
            content: .weights(workout, restSeconds: rest, cues: cues),
            estimatedMinutes: Int((Double(estimate()) / 60).rounded(.up)),
            adjustments: adjustments,
            provider: provider
        )
    }

    /// Rough session length: each set's work plus the rest after it (the
    /// session view rests after every set, warmups included), plus setup.
    /// The session ends on the last set, so its rest isn't counted.
    func estimatedSeconds(_ exercises: [Exercise], rest: Int, healthStore: HealthStore) -> Int {
        let total = exercises.reduce(0) { $0 + exerciseSeconds($1, rest: rest, healthStore: healthStore) }
        return exercises.isEmpty ? 0 : total - rest
    }

    private func exerciseSeconds(_ exercise: Exercise, rest: Int, healthStore: HealthStore) -> Int {
        let warmups = exercise.generateWarmupSets(healthStore.getNextWorkWeight(for: exercise)).count
        let workSeconds = exercise.isTimedExercise ? (exercise.targetDurationSeconds ?? 60) : 40
        let sets = warmups + exercise.sets
        return sets * workSeconds + warmups * warmupRestSeconds + exercise.sets * rest + 60
    }

    private func withSets(_ exercise: Exercise, _ sets: Int) -> Exercise {
        Exercise(name: exercise.name, sets: sets, reps: exercise.reps)
    }

    var warmupRest: Int { warmupRestSeconds }

    // MARK: Cardio

    private func cardioPlan(
        from draft: CardioPlanDraft,
        answers: TrainerAnswers,
        provider: TrainerModelProvider?,
        healthStore: HealthStore
    ) -> TrainerPlan {
        let activity = answers.cardioActivity
        let pace = TrainerContext.typicalPaceSeconds(for: activity, healthStore)
        let budgetMinutes = max(10, answers.minutes - bufferMinutes)
        var adjustments: [String] = []
        var goal = RunGoal()
        let estimatedMinutes: Int

        if draft.goalType == "time" {
            goal.type = .time
            goal.timeMinutes = min(max(draft.minutes, 5), budgetMinutes)
            if draft.minutes > budgetMinutes {
                adjustments.append("Shortened to fit \(answers.minutes) min")
            }
            estimatedMinutes = goal.timeMinutes
        } else {
            goal.type = .distance
            let maxKm = Double(budgetMinutes * 60) / Double(pace)
            var km = max(0.5, draft.distanceKm)
            if km > maxKm {
                km = max(0.5, (maxKm * 2).rounded(.down) / 2)
                adjustments.append("Distance cut to fit \(answers.minutes) min at your usual pace")
            }
            goal.distanceKm = (km * 10).rounded() / 10
            estimatedMinutes = Int((goal.distanceKm * Double(pace) / 60).rounded(.up))
        }

        return TrainerPlan(
            title: draft.title,
            intro: draft.intro,
            content: .cardio(CardioPlan(activity: activity, outdoor: answers.outdoor, goal: goal, cues: draft.cues)),
            estimatedMinutes: estimatedMinutes,
            adjustments: adjustments,
            provider: provider
        )
    }

    // MARK: Fallback

    /// Used only when neither Luna nor the on-device model is reachable.
    private func fallbackPlan(answers: TrainerAnswers, healthStore: HealthStore) -> TrainerPlan {
        let lowEnergy = Self.isLowEnergy(answers)
        switch answers.focus {
        case .weights:
            let rotation = WorkoutProgramTemplate.getProgram(for: 3)?.workouts ?? []
            let lastWeights = healthStore.workoutSessionRecords
                .filter { $0.kind == .weights }
                .max { $0.startDate < $1.startDate }
            let lastIndex = rotation.firstIndex { $0.name == lastWeights?.workoutName } ?? -1
            let template = rotation.isEmpty ? nil : rotation[(lastIndex + 1) % rotation.count]
            var exercises = template?.exercises ?? [Exercise(name: "Squats", sets: 5, reps: "5")]
            if lowEnergy {
                exercises = exercises.map { withSets($0, min($0.sets, 3)) }
            }
            let names = exercises.map(\.name).joined(separator: ", ")
            return fittedWeightsPlan(
                title: template?.name ?? "Strength",
                intro: "I can't reach my planning brain right now, so we'll stick to your program: \(names).\(lowEnergy ? " I've cut the volume since you're not feeling a hundred percent." : "")",
                exercises: exercises,
                rest: 180,
                cues: [:],
                minutes: answers.minutes,
                lowEnergy: lowEnergy,
                provider: nil,
                healthStore: healthStore
            )
        case .cardio:
            var goal = RunGoal()
            goal.type = .time
            goal.timeMinutes = min(max(10, answers.minutes - bufferMinutes), lowEnergy ? 25 : 45)
            let noun = answers.cardioActivity.noun
            return TrainerPlan(
                title: "\(goal.timeMinutes) min \(noun)",
                intro: "I can't reach my planning brain right now, so let's keep it simple: a steady \(goal.timeMinutes) minute \(noun) at a pace you can hold a conversation.",
                content: .cardio(CardioPlan(activity: answers.cardioActivity, outdoor: answers.outdoor, goal: goal, cues: [])),
                estimatedMinutes: goal.timeMinutes,
                adjustments: [],
                provider: nil
            )
        }
    }
}
