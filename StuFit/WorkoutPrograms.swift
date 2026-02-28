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
    let baseWeight: Double = 20.0 // kg (barbell starts at 20kg)
    let availablePlates: [Double] = [20, 10, 5, 2.5, 1.25] // sorted descending
    
    /// Calculate weight for a specific set given how many times this exercise has been done
    /// - Parameters:
    ///   - setNumber: The current set (1-indexed)
    ///   - completionCount: How many times this exercise has been completed (0 = first time)
    /// - Returns: Weight in kg for this set
    func getWeightForSet(_ setNumber: Int, completionCount: Int) -> Double {
        // Progression: top set increases by 2.5kg each cycle
        let topSetWeight = baseWeight + (Double(completionCount) * 2.5)
        
        // Set 1 is at top weight, Set 2+ is 2.5kg less but never below the bar (20kg)
        if setNumber == 1 {
            return topSetWeight
        } else {
            // All other sets are 2.5kg less than Set 1, but minimum is the bar weight (20kg)
            return max(baseWeight, topSetWeight - 2.5)
        }
    }
    
    /// Calculate which plates are needed on each side for a given weight
    /// - Parameter weight: The target weight in kg
    /// - Returns: Array of plate weights needed on each side
    func getPlatesForWeight(_ weight: Double) -> [Double] {
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
    
    /// Generate warm-up sets following the step-up method
    /// - Parameters:
    ///   - workWeight: The target work weight in kg
    ///   - completionCount: How many times this exercise has been completed (0 = first time)
    /// - Returns: Array of warm-up sets in order
    func generateWarmupSets(_ workWeight: Double, completionCount: Int = 0) -> [WarmupSet] {
        var warmupSets: [WarmupSet] = []
        
        // Rule 1: The Empty Bar Start
        let startingWeight: Double
        let isDeadliftOrRow = name.lowercased().contains("deadlift") || name.lowercased().contains("barbell row")
        
        if isDeadliftOrRow {
            // Exception: Deadlifts and Barbell Rows start at 60kg
            startingWeight = 60.0
            warmupSets.append(WarmupSet(weight: startingWeight, reps: 5))
            warmupSets.append(WarmupSet(weight: startingWeight, reps: 5))
        } else {
            // All other exercises: 2 sets of 5 with empty bar (20kg)
            warmupSets.append(WarmupSet(weight: baseWeight, reps: 5))
            warmupSets.append(WarmupSet(weight: baseWeight, reps: 5))
            startingWeight = baseWeight
        }
        
        // Rule 2: The Step-Up Method
        // Add weight in 10-20kg increments until reaching work weight
        // Fewer reps as you get closer to work weight
        
        var currentWeight = startingWeight
        
        while currentWeight < workWeight {
            // Determine increment size: use 20kg initially, but use smaller increments when closer to target
            let remainingWeight = workWeight - currentWeight
            let increment = remainingWeight > 40 ? 20.0 : (remainingWeight > 20 ? 15.0 : 10.0)
            
            currentWeight += increment
            
            // Don't add a set at or beyond work weight (that's the actual work set)
            if currentWeight >= workWeight {
                break
            }
            
            // Determine reps: The closer to work weight, the fewer reps
            let repsForSet: Int
            if currentWeight < workWeight - 30 {
                repsForSet = 3
            } else if currentWeight < workWeight - 10 {
                repsForSet = 2
            } else {
                repsForSet = 2
            }
            
            warmupSets.append(WarmupSet(weight: currentWeight, reps: repsForSet))
        }
        
        return warmupSets
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
        1: WorkoutProgramTemplate(
            daysPerWeek: 1,
            workouts: [
                ProgramWorkout(name: "Day 1", exercises: [
                    Exercise(name: "Squats", sets: 5, reps: "5"),
                    Exercise(name: "Bench Press", sets: 5, reps: "5"),
                    Exercise(name: "Deadlift", sets: 1, reps: "5"),
                    Exercise(name: "Overhead Press", sets: 2, reps: "5")
                ])
            ]
        ),
        2: WorkoutProgramTemplate(
            daysPerWeek: 2,
            workouts: [
                ProgramWorkout(name: "Workout A", exercises: [
                    Exercise(name: "Squats", sets: 5, reps: "5"),
                    Exercise(name: "Bench Press", sets: 5, reps: "5")
                ]),
                ProgramWorkout(name: "Workout B", exercises: [
                    Exercise(name: "Deadlift", sets: 5, reps: "5"),
                    Exercise(name: "Overhead Press", sets: 5, reps: "5")
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
