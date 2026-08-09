//
//  WorkoutPrograms.swift
//  FullFitness
//
//  Created by Copilot on 30/1/2026.
//

import Foundation

struct WarmupSet {
    let weight: Double
    let reps: Int
}

struct Exercise {
    let name: String
    let sets: Int
    let reps: String
    
    /// Only these lifts are treated as barbell-loaded for weight/plate calculations.
    private var barbellExerciseNames: Set<String> {
        ["squats", "bench press", "deadlift", "overhead press", "barbell rows", "romanian deadlift"]
    }

    var usesBarbellLoading: Bool {
        barbellExerciseNames.contains(name.lowercased())
    }

    /// Exercises performed with body weight only — no bar or external load,
    /// so no weight is tracked, progressed, or announced for them.
    private var bodyweightExerciseNames: Set<String> {
        ["pull ups", "roman sit ups", "plank"]
    }

    var isBodyweightExercise: Bool {
        bodyweightExerciseNames.contains(name.lowercased())
    }

    private var timedExerciseNames: Set<String> {
        ["plank"]
    }

    var isTimedExercise: Bool {
        timedExerciseNames.contains(name.lowercased())
    }

    /// For timed exercises, parse the target duration in seconds from the reps string (e.g. "60 Seconds" -> 60)
    var targetDurationSeconds: Int? {
        guard isTimedExercise else { return nil }
        let digits = reps.prefix(while: { $0.isNumber })
        return Int(digits)
    }

    /// Numeric rep target parsed from the reps string ("8 Each Leg" -> 8).
    /// Nil for non-numeric targets like "Max Reps".
    var repsPerSet: Int? {
        let digits = reps.prefix(while: { $0.isNumber })
        return Int(digits)
    }

    var baseWeight: Double {
        usesBarbellLoading ? 20.0 : 0.0
    }

    var availablePlates: [Double] {
        usesBarbellLoading ? [20, 10, 5, 2.5, 1.25] : []
    }
    
    /// Calculate weight for a specific set given how many times this exercise has been done
    /// - Parameters:
    ///   - setNumber: The current set (1-indexed)
    ///   - completionCount: How many times this exercise has been completed (0 = first time)
    /// - Returns: Weight in kg for this set
    func getWeightForSet(_ setNumber: Int, completionCount: Int) -> Double {
        guard usesBarbellLoading else { return 0.0 }

        // Progression: top set increases by 2.5kg each cycle
        let topSetWeight = baseWeight + (Double(completionCount) * 2.5)
        
        // Set 1 is at top weight, Set 2+ is 5kg less but never below the bar (20kg)
        if setNumber == 1 {
            return topSetWeight
        } else {
            // All other sets are 5kg less than Set 1, but minimum is the bar weight (20kg)
            return max(baseWeight, topSetWeight - 5.0)
        }
    }
    
    /// Calculate which plates are needed on each side for a given weight
    /// - Parameter weight: The target weight in kg
    /// - Returns: Array of plate weights needed on each side
    func getPlatesForWeight(_ weight: Double) -> [Double] {
        guard usesBarbellLoading else { return [] }

        let weightPerSide = (weight - baseWeight) / 2.0
        var remainingWeight = weightPerSide
        var plates: [Double] = []
        
        for plate in availablePlates {
            while remainingWeight >= plate - 0.001 { // small tolerance for floating point
                plates.append(plate)
                remainingWeight -= plate
            }
        }
        
        return plates.sorted(by: >)
    }

    /// Round a target total weight to the nearest loadable barbell weight.
    /// The step is based on the smallest available plate pair.
    func roundToNearestLoadableWeight(_ weight: Double) -> Double {
        guard usesBarbellLoading else {
            let step = 2.5
            return max(0, (weight / step).rounded() * step)
        }

        let minPlate = availablePlates.min() ?? 1.25
        let totalStep = max(0.5, minPlate * 2.0)
        let clamped = max(baseWeight, weight)
        let increments = ((clamped - baseWeight) / totalStep).rounded()
        let rounded = baseWeight + (increments * totalStep)
        return max(baseWeight, rounded)
    }

    /// Returns the default first work-set weight for this exercise.
    func defaultWorkWeight(completionCount: Int = 0) -> Double {
        roundToNearestLoadableWeight(getWeightForSet(1, completionCount: completionCount))
    }
    
    /// Generate up to 3 warm-up sets ramping to the work weight.
    ///
    /// The ramp halves the remaining gap to the work weight each step
    /// (e.g. 20 → 30 → 35 before a 40kg work set). Every step must climb at
    /// least 5kg and finish at least 5kg under the work weight; when the work
    /// weight is too low for three distinct steps, the starting weight is
    /// repeated once instead (e.g. 20, 20, 25 before a 30kg work set).
    /// - Parameters:
    ///   - workWeight: The target work weight in kg
    ///   - completionCount: How many times this exercise has been completed (0 = first time)
    /// - Returns: Array of warm-up sets in order
    func generateWarmupSets(_ workWeight: Double, completionCount: Int = 0) -> [WarmupSet] {
        guard usesBarbellLoading else { return [] }

        // Starting weight: deadlift variations start at 30kg (an empty bar
        // sits too low to pull from the floor); everything else starts with
        // the empty 20kg bar. Stay at least 5kg under the work weight so the
        // ramp has somewhere to go — unless the work weight is the bar itself.
        let isDeadlift = name.lowercased().contains("deadlift")
        let preferredStart = isDeadlift ? 30.0 : baseWeight
        let startingWeight = max(baseWeight, min(preferredStart, workWeight - 5.0))

        var stepWeights: [Double] = [startingWeight]
        var currentWeight = startingWeight
        while stepWeights.count < 3 {
            let next = roundToNearestLoadableWeight(currentWeight + (workWeight - currentWeight) / 2.0)
            guard next - currentWeight >= 4.999, workWeight - next >= 4.999 else { break }
            stepWeights.append(next)
            currentWeight = next
        }

        // Too light for 3 distinct steps: repeat the starting weight once so
        // there are still enough sets to groove the movement.
        if stepWeights.count < 3, stepWeights.filter({ $0 == startingWeight }).count < 2 {
            stepWeights.insert(startingWeight, at: 0)
        }

        // Fewer reps as the bar approaches the work weight
        let repsByPosition = [5, 3, 2]
        return stepWeights.enumerated().map { index, weight in
            WarmupSet(weight: weight, reps: repsByPosition[min(index, repsByPosition.count - 1)])
        }
    }
}

struct ProgramWorkout {
    let name: String
    let exercises: [Exercise]
}

struct WorkoutProgramTemplate {
    let daysPerWeek: Int
    let workouts: [ProgramWorkout]
    
    static let programs: [Int: WorkoutProgramTemplate] = [
        // One session a week has to cover every target area each time —
        // alternating A/B here would leave two weeks between bench sessions.
        // Volume is trimmed to keep the session under an hour with warmups.
        1: WorkoutProgramTemplate(
            daysPerWeek: 1,
            workouts: [
                ProgramWorkout(name: "Full Body", exercises: [
                    Exercise(name: "Squats", sets: 3, reps: "5"),
                    Exercise(name: "Bench Press", sets: 3, reps: "5"),
                    Exercise(name: "Barbell Rows", sets: 3, reps: "5"),
                    Exercise(name: "Overhead Press", sets: 2, reps: "5"),
                    Exercise(name: "Deadlift", sets: 1, reps: "5")
                ])
            ]
        ),
        // Classic StrongLifts A/B alternation. Each session is full body:
        // squat every workout, push + pull in A, press + hinge in B.
        2: WorkoutProgramTemplate(
            daysPerWeek: 2,
            workouts: [
                ProgramWorkout(name: "Workout A", exercises: [
                    Exercise(name: "Squats", sets: 5, reps: "5"),
                    Exercise(name: "Bench Press", sets: 5, reps: "5"),
                    Exercise(name: "Barbell Rows", sets: 5, reps: "5")
                ]),
                ProgramWorkout(name: "Workout B", exercises: [
                    Exercise(name: "Squats", sets: 5, reps: "5"),
                    Exercise(name: "Overhead Press", sets: 5, reps: "5"),
                    Exercise(name: "Deadlift", sets: 1, reps: "5")
                ])
            ]
        ),
        3: WorkoutProgramTemplate(
            daysPerWeek: 3,
            workouts: [
                ProgramWorkout(name: "Workout A", exercises: [
                    Exercise(name: "Squats", sets: 5, reps: "5"),
                    Exercise(name: "Bench Press", sets: 5, reps: "5"),
                    Exercise(name: "Barbell Rows", sets: 5, reps: "5")
                ]),
                ProgramWorkout(name: "Workout B", exercises: [
                    Exercise(name: "Squats", sets: 5, reps: "5"),
                    Exercise(name: "Overhead Press", sets: 5, reps: "5"),
                    Exercise(name: "Deadlift", sets: 1, reps: "5")
                ])
            ]
        ),
        4: WorkoutProgramTemplate(
            daysPerWeek: 4,
            workouts: [
                ProgramWorkout(name: "Workout A", exercises: [
                    Exercise(name: "Squats", sets: 5, reps: "5"),
                    Exercise(name: "Deadlift", sets: 1, reps: "5"),
                    Exercise(name: "Romanian Deadlift", sets: 3, reps: "8")
                ]),
                ProgramWorkout(name: "Workout B", exercises: [
                    Exercise(name: "Bench Press", sets: 5, reps: "5"),
                    Exercise(name: "Barbell Rows", sets: 5, reps: "5"),
                    Exercise(name: "Pull Ups", sets: 3, reps: "Max Reps")
                ]),
                ProgramWorkout(name: "Workout C", exercises: [
                    Exercise(name: "Deadlift", sets: 5, reps: "5"),
                    Exercise(name: "Squats", sets: 1, reps: "5"),
                    Exercise(name: "Roman Sit Ups", sets: 3, reps: "15")
                ]),
                ProgramWorkout(name: "Workout D", exercises: [
                    Exercise(name: "Overhead Press", sets: 5, reps: "5"),
                    Exercise(name: "Dumbbell Lunges", sets: 3, reps: "8 Each Leg"),
                    Exercise(name: "Plank", sets: 3, reps: "60 Seconds")
                ])
            ]
        ),
        5: WorkoutProgramTemplate(
            daysPerWeek: 5,
            workouts: [
                ProgramWorkout(name: "Workout A", exercises: [
                    Exercise(name: "Squats", sets: 5, reps: "5"),
                    Exercise(name: "Deadlift", sets: 1, reps: "5")
                ]),
                ProgramWorkout(name: "Workout B", exercises: [
                    Exercise(name: "Bench Press", sets: 5, reps: "5"),
                    Exercise(name: "Barbell Rows", sets: 5, reps: "5")
                ]),
                ProgramWorkout(name: "Workout C", exercises: [
                    Exercise(name: "Deadlift", sets: 5, reps: "5"),
                    Exercise(name: "Squats", sets: 1, reps: "5")
                ]),
                ProgramWorkout(name: "Workout D", exercises: [
                    Exercise(name: "Overhead Press", sets: 5, reps: "5"),
                    Exercise(name: "Dumbbell Lunges", sets: 3, reps: "8 Each Leg")
                ]),
                ProgramWorkout(name: "Workout E", exercises: [
                    Exercise(name: "Bench Press", sets: 3, reps: "5"),
                    Exercise(name: "Pull Ups", sets: 3, reps: "Max Reps"),
                    Exercise(name: "Roman Sit Ups", sets: 3, reps: "15")
                ])
            ]
        )
    ]
    
    static func getProgram(for days: Int) -> WorkoutProgramTemplate? {
        return programs[days]
    }
}
