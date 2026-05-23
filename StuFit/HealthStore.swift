//
//  HealthStore.swift
//  StuFit
//
//  Created by Copilot on 27/1/2026.
//

import Foundation
import Combine
import HealthKit
import FoundationModels
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

enum WorkoutType: String, CaseIterable {
    case cardio = "Cardio"
    case weights = "Weights"
}

struct WeightProgram: Identifiable, Codable {
    let id: UUID
    let daysPerWeek: Int
    let createdDate: Date
    var isActive: Bool

    init(id: UUID, daysPerWeek: Int, createdDate: Date, isActive: Bool) {
        self.id = id
        self.daysPerWeek = daysPerWeek
        self.createdDate = createdDate
        self.isActive = isActive
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case daysPerWeek
        case createdDate
        case isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.daysPerWeek = try container.decodeIfPresent(Int.self, forKey: .daysPerWeek) ?? 3
        self.createdDate = try container.decodeIfPresent(Date.self, forKey: .createdDate) ?? Date()
        self.isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
    }
}

struct CompletedWorkout: Identifiable, Codable {
    let id: UUID
    let workoutName: String
    let completedDate: Date

    init(id: UUID, workoutName: String, completedDate: Date) {
        self.id = id
        self.workoutName = workoutName
        self.completedDate = completedDate
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case workoutName
        case completedDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.workoutName = try container.decodeIfPresent(String.self, forKey: .workoutName) ?? "Workout"
        self.completedDate = try container.decodeIfPresent(Date.self, forKey: .completedDate) ?? Date()
    }
}

struct CompletedExercise: Identifiable, Codable {
    let id: UUID
    let exerciseName: String
    let workoutName: String
    let completedDate: Date

    init(id: UUID, exerciseName: String, workoutName: String, completedDate: Date) {
        self.id = id
        self.exerciseName = exerciseName
        self.workoutName = workoutName
        self.completedDate = completedDate
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case exerciseName
        case workoutName
        case completedDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.exerciseName = try container.decodeIfPresent(String.self, forKey: .exerciseName) ?? "Exercise"
        self.workoutName = try container.decodeIfPresent(String.self, forKey: .workoutName) ?? "Workout"
        self.completedDate = try container.decodeIfPresent(Date.self, forKey: .completedDate) ?? Date()
    }
}

struct CompletedSetRecord: Identifiable, Codable {
    let id: UUID
    let workoutId: UUID
    let workoutName: String
    let exerciseName: String
    let setIndex: Int
    let targetReps: Int
    let actualReps: Int
    let weight: Double
    let isWarmup: Bool
    let didFail: Bool
    let completedDate: Date

    init(
        id: UUID,
        workoutId: UUID,
        workoutName: String,
        exerciseName: String,
        setIndex: Int,
        targetReps: Int,
        actualReps: Int,
        weight: Double,
        isWarmup: Bool,
        didFail: Bool,
        completedDate: Date
    ) {
        self.id = id
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.exerciseName = exerciseName
        self.setIndex = setIndex
        self.targetReps = targetReps
        self.actualReps = actualReps
        self.weight = weight
        self.isWarmup = isWarmup
        self.didFail = didFail
        self.completedDate = completedDate
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case workoutId
        case workoutName
        case exerciseName
        case setIndex
        case targetReps
        case actualReps
        case weight
        case isWarmup
        case didFail
        case completedDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.workoutId = try container.decodeIfPresent(UUID.self, forKey: .workoutId) ?? UUID()
        self.workoutName = try container.decodeIfPresent(String.self, forKey: .workoutName) ?? "Workout"
        self.exerciseName = try container.decodeIfPresent(String.self, forKey: .exerciseName) ?? "Exercise"
        self.setIndex = try container.decodeIfPresent(Int.self, forKey: .setIndex) ?? 0
        self.targetReps = try container.decodeIfPresent(Int.self, forKey: .targetReps) ?? 0
        self.actualReps = try container.decodeIfPresent(Int.self, forKey: .actualReps) ?? 0
        self.weight = try container.decodeIfPresent(Double.self, forKey: .weight) ?? 0
        self.isWarmup = try container.decodeIfPresent(Bool.self, forKey: .isWarmup) ?? false
        self.didFail = try container.decodeIfPresent(Bool.self, forKey: .didFail) ?? false
        self.completedDate = try container.decodeIfPresent(Date.self, forKey: .completedDate) ?? Date()
    }
}

enum WorkoutSessionStatus: String, Codable {
    case completed
    case endedEarly

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self)) ?? WorkoutSessionStatus.completed.rawValue
        self = WorkoutSessionStatus(rawValue: rawValue) ?? .completed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct WorkoutSessionRecord: Identifiable, Codable {
    let id: UUID
    let workoutName: String
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let status: WorkoutSessionStatus

    init(
        id: UUID,
        workoutName: String,
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        status: WorkoutSessionStatus
    ) {
        self.id = id
        self.workoutName = workoutName
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.status = status
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case workoutName
        case startDate
        case endDate
        case duration
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.workoutName = try container.decodeIfPresent(String.self, forKey: .workoutName) ?? "Workout"
        self.startDate = try container.decodeIfPresent(Date.self, forKey: .startDate) ?? Date()
        self.endDate = try container.decodeIfPresent(Date.self, forKey: .endDate) ?? self.startDate
        self.duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
            ?? max(0, self.endDate.timeIntervalSince(self.startDate))
        self.status = try container.decodeIfPresent(WorkoutSessionStatus.self, forKey: .status) ?? .completed
    }
}

struct ExerciseProgressState: Codable {
    let exerciseName: String
    var currentTrainingWeight: Double
    var consecutiveFailuresAtWeight: Int
    var lastAttemptWeight: Double
    var lastAttemptFailed: Bool

    init(
        exerciseName: String,
        currentTrainingWeight: Double,
        consecutiveFailuresAtWeight: Int,
        lastAttemptWeight: Double,
        lastAttemptFailed: Bool
    ) {
        self.exerciseName = exerciseName
        self.currentTrainingWeight = currentTrainingWeight
        self.consecutiveFailuresAtWeight = consecutiveFailuresAtWeight
        self.lastAttemptWeight = lastAttemptWeight
        self.lastAttemptFailed = lastAttemptFailed
    }

    private enum CodingKeys: String, CodingKey {
        case exerciseName
        case currentTrainingWeight
        case consecutiveFailuresAtWeight
        case lastAttemptWeight
        case lastAttemptFailed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.exerciseName = try container.decodeIfPresent(String.self, forKey: .exerciseName) ?? "Exercise"
        self.currentTrainingWeight = try container.decodeIfPresent(Double.self, forKey: .currentTrainingWeight) ?? 0
        self.consecutiveFailuresAtWeight = try container.decodeIfPresent(Int.self, forKey: .consecutiveFailuresAtWeight) ?? 0
        self.lastAttemptWeight = try container.decodeIfPresent(Double.self, forKey: .lastAttemptWeight)
            ?? self.currentTrainingWeight
        self.lastAttemptFailed = try container.decodeIfPresent(Bool.self, forKey: .lastAttemptFailed) ?? false
    }
}

struct WeightsSuggestion {
    let recommendation: String
    let reasoning: String?
    let suggestedDays: Int
}

enum ActivityType: String, Identifiable {
    case run = "Run"
    case walk = "Walk"
    case ride = "Ride"
    case bench = "Bench Press"
    case squat = "Squat"
    case deadlift = "Deadlift"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .run: return "figure.run"
        case .walk: return "figure.walk"
        case .ride: return "bicycle"
        case .bench: return "dumbbell.fill"
        case .squat: return "dumbbell.fill"
        case .deadlift: return "dumbbell.fill"
        }
    }
}

enum RunLocationType: String, Identifiable, CaseIterable {
    case outdoor = "Outdoor"
    case treadmill = "Treadmill"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .outdoor: return "figure.run"
        case .treadmill: return "figure.run.square.stack"
        }
    }
}

enum RunGoalType: String, CaseIterable, Identifiable {
    case distance = "Distance"
    case time = "Time"
    case open = "Open"

    var id: String { self.rawValue }
}

struct RunGoal {
    var type: RunGoalType = .distance
    var distanceKm: Double = 5
    var timeMinutes: Int = 30
}

enum WatchConnectionStatus: String {
    case unsupported
    case notPaired
    case watchAppNotInstalled
    case pairedNotReachable
    case ready

    var helperText: String {
        switch self {
        case .unsupported:
            return "Apple Watch data is not supported on this device."
        case .notPaired:
            return "Pair an Apple Watch to stream live heart rate."
        case .watchAppNotInstalled:
            return "Install StuFit on your Apple Watch to stream heart rate."
        case .pairedNotReachable:
            return "Keep your watch close to this iPhone so it can stream heart rate."
        case .ready:
            return "Awaiting live heart rate from your watch."
        }
    }
}

final class HealthStore: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var authorized: Bool = false
    @Published var currentHeartRate: Double?
    @Published var isReceivingHeartRate: Bool = false
    @Published var isWorkoutActive: Bool = false
    @Published var watchConnectionStatus: WatchConnectionStatus = .unsupported
    @Published var selectedWorkoutType: WorkoutType?
    @Published var selectedActivityType: ActivityType?
    @Published var selectedRunLocation: RunLocationType?
    @Published var runGoal: RunGoal = RunGoal()
    @Published var suggestion: String?
    @Published var isGeneratingAdvice: Bool = false
    @Published var activeWeightProgram: WeightProgram? {
        willSet {
            // Save to UserDefaults whenever the program changes
            if let newValue = newValue {
                do {
                    let encoded = try JSONEncoder().encode(newValue)
                    UserDefaults.standard.set(encoded, forKey: "activeWeightProgram")
                } catch {
                    print("Error encoding weight program: \(error.localizedDescription)")
                }
            } else {
                // Clear the saved program
                UserDefaults.standard.removeObject(forKey: "activeWeightProgram")
            }
        }
    }
    @Published var weightsSuggestion: WeightsSuggestion?
    @Published var workoutTip: String?
    @Published var completedWorkouts: [CompletedWorkout] = [] {
        willSet {
            // Save to UserDefaults whenever completed workouts change
            do {
                let encoded = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(encoded, forKey: "completedWorkouts")
            } catch {
                print("Error encoding completed workouts: \(error.localizedDescription)")
            }
        }
    }
    @Published var completedExercises: [CompletedExercise] = [] {
        willSet {
            // Save to UserDefaults whenever completed exercises change
            do {
                let encoded = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(encoded, forKey: "completedExercises")
            } catch {
                print("Error encoding completed exercises: \(error.localizedDescription)")
            }
        }
    }
    @Published var customExerciseWeights: [String: Double] = [:] {
        willSet {
            // Save to UserDefaults whenever custom weights change
            UserDefaults.standard.set(newValue, forKey: "customExerciseWeights")
        }
    }
    @Published var completedSetRecords: [CompletedSetRecord] = [] {
        willSet {
            do {
                let encoded = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(encoded, forKey: "completedSetRecords")
            } catch {
                print("Error encoding completed set records: \(error.localizedDescription)")
            }
        }
    }
    @Published var exerciseProgressStates: [String: ExerciseProgressState] = [:] {
        willSet {
            do {
                let encoded = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(encoded, forKey: "exerciseProgressStates")
            } catch {
                print("Error encoding exercise progression state: \(error.localizedDescription)")
            }
        }
    }
    @Published var workoutSessionRecords: [WorkoutSessionRecord] = [] {
        willSet {
            do {
                let encoded = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(encoded, forKey: "workoutSessionRecords")
            } catch {
                print("Error encoding workout session records: \(error.localizedDescription)")
            }
        }
    }
    @Published var lastDeloadDate: Date? {
        willSet {
            if let date = newValue {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "lastDeloadDate")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastDeloadDate")
            }
        }
    }
    private var currentWorkoutStartDate: Date?
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var heartRateAnchor: HKQueryAnchor?
    private let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
#if canImport(WatchConnectivity)
    private var watchSession: WCSession?
#endif

    override init() {
        super.init()
        // Load saved weight program from UserDefaults
        if let savedData = UserDefaults.standard.data(forKey: "activeWeightProgram") {
            do {
                self.activeWeightProgram = try JSONDecoder().decode(WeightProgram.self, from: savedData)
            } catch {
                print("Error decoding weight program: \(error.localizedDescription)")
                self.activeWeightProgram = nil
            }
        }
        
        // Load saved completed workouts from UserDefaults
        if let savedData = UserDefaults.standard.data(forKey: "completedWorkouts") {
            do {
                self.completedWorkouts = try JSONDecoder().decode([CompletedWorkout].self, from: savedData)
            } catch {
                print("Error decoding completed workouts: \(error.localizedDescription)")
                self.completedWorkouts = []
            }
        }
        
        // Load saved completed exercises from UserDefaults
        if let savedData = UserDefaults.standard.data(forKey: "completedExercises") {
            do {
                self.completedExercises = try JSONDecoder().decode([CompletedExercise].self, from: savedData)
            } catch {
                print("Error decoding completed exercises: \(error.localizedDescription)")
                self.completedExercises = []
            }
        }
        
        // Load saved custom exercise weights from UserDefaults
        if let savedWeights = UserDefaults.standard.dictionary(forKey: "customExerciseWeights") as? [String: Double] {
            self.customExerciseWeights = savedWeights
        }

        if let savedData = UserDefaults.standard.data(forKey: "completedSetRecords") {
            do {
                self.completedSetRecords = try JSONDecoder().decode([CompletedSetRecord].self, from: savedData)
            } catch {
                print("Error decoding completed set records: \(error.localizedDescription)")
                self.completedSetRecords = []
            }
        }

        if let savedData = UserDefaults.standard.data(forKey: "exerciseProgressStates") {
            do {
                self.exerciseProgressStates = try JSONDecoder().decode([String: ExerciseProgressState].self, from: savedData)
            } catch {
                print("Error decoding exercise progression state: \(error.localizedDescription)")
                self.exerciseProgressStates = [:]
            }
        }

        if let savedData = UserDefaults.standard.data(forKey: "workoutSessionRecords") {
            do {
                self.workoutSessionRecords = try JSONDecoder().decode([WorkoutSessionRecord].self, from: savedData)
            } catch {
                print("Error decoding workout session records: \(error.localizedDescription)")
                self.workoutSessionRecords = []
            }
        }
        let deloadTimestamp = UserDefaults.standard.double(forKey: "lastDeloadDate")
        if deloadTimestamp > 0 {
            self.lastDeloadDate = Date(timeIntervalSince1970: deloadTimestamp)
        }

        migrateWeightsToValidIncrements()
        configureWatchConnectivity()
        checkAuthorizationStatus()
    }
    
    // MARK: - Workout Tracking
    
    /// Returns the next workout to do based on the active program and completed workouts
    func getNextWorkout() -> ProgramWorkout? {
        guard let program = activeWeightProgram else { return nil }
        guard let template = WorkoutProgramTemplate.getProgram(for: program.daysPerWeek) else { return nil }
        
        guard !template.workouts.isEmpty else { return nil }
        
        // If no workouts completed yet, return the first one
        if completedWorkouts.isEmpty {
            return template.workouts.first
        }
        
        // Find the most recent completed workout
        let sortedByDate = completedWorkouts.sorted { $0.completedDate > $1.completedDate }
        
        if let lastWorkout = sortedByDate.first {
            // Find the index of the last completed workout
            if let lastIndex = template.workouts.firstIndex(where: { $0.name == lastWorkout.workoutName }) {
                // Return the next one in rotation
                let nextIndex = (lastIndex + 1) % template.workouts.count
                return template.workouts[nextIndex]
            }
        }
        
        // Fallback to first workout if we can't find the last one
        return template.workouts.first
    }
    
    /// Mark a workout as completed
    func completeWorkout(_ workoutName: String) {
        let completed = CompletedWorkout(
            id: UUID(),
            workoutName: workoutName,
            completedDate: Date()
        )
        self.completedWorkouts.append(completed)
    }
    
    /// Mark an exercise as completed (within a workout)
    func completeExercise(_ exerciseName: String, inWorkout workoutName: String) {
        let completed = CompletedExercise(
            id: UUID(),
            exerciseName: exerciseName,
            workoutName: workoutName,
            completedDate: Date()
        )
        self.completedExercises.append(completed)
    }

    func recordWorkoutSession(
        workoutName: String,
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        status: WorkoutSessionStatus
    ) {
        let record = WorkoutSessionRecord(
            id: UUID(),
            workoutName: workoutName,
            startDate: startDate,
            endDate: endDate,
            duration: duration,
            status: status
        )
        workoutSessionRecords.append(record)
    }
    
    /// Get the number of times a specific exercise has been completed
    func getExerciseCompletionCount(_ exerciseName: String) -> Int {
        return completedExercises.filter { $0.exerciseName == exerciseName }.count
    }

    /// Returns the next target top-set weight based on exercise performance state.
    func getNextWorkWeight(for exercise: Exercise) -> Double {
        if let state = exerciseProgressStates[exercise.name] {
            return max(exercise.baseWeight, exercise.roundToNearestLoadableWeight(state.currentTrainingWeight))
        }

        if let customWeight = customExerciseWeights[exercise.name] {
            return max(exercise.baseWeight, exercise.roundToNearestLoadableWeight(customWeight))
        }

        return exercise.defaultWorkWeight(completionCount: getExerciseCompletionCount(exercise.name))
    }

    /// Persist set-level records and update progression for an exercise attempt.
    func recordExerciseAttempt(
        workoutId: UUID,
        workoutName: String,
        exercise: Exercise,
        setRecords: [(setIndex: Int, targetReps: Int, actualReps: Int, weight: Double, isWarmup: Bool, didFail: Bool)],
        completedDate: Date = .now
    ) {
        guard !setRecords.isEmpty else { return }

        let persistedRecords = setRecords.map { record in
            CompletedSetRecord(
                id: UUID(),
                workoutId: workoutId,
                workoutName: workoutName,
                exerciseName: exercise.name,
                setIndex: record.setIndex,
                targetReps: record.targetReps,
                actualReps: record.actualReps,
                weight: record.weight,
                isWarmup: record.isWarmup,
                didFail: record.didFail,
                completedDate: completedDate
            )
        }
        completedSetRecords.append(contentsOf: persistedRecords)

        let workSetRecords = persistedRecords.filter { !$0.isWarmup }
        guard !workSetRecords.isEmpty else { return }

        let attemptWeight = exercise.roundToNearestLoadableWeight(workSetRecords[0].weight)
        let attemptFailed = workSetRecords.contains { $0.didFail }

        var state = exerciseProgressStates[exercise.name] ?? ExerciseProgressState(
            exerciseName: exercise.name,
            currentTrainingWeight: attemptWeight,
            consecutiveFailuresAtWeight: 0,
            lastAttemptWeight: attemptWeight,
            lastAttemptFailed: false
        )

        let failedAtSameWeight = state.lastAttemptFailed && abs(state.lastAttemptWeight - attemptWeight) < 0.001

        if attemptFailed {
            if failedAtSameWeight {
                let deloadedWeight = exercise.roundToNearestLoadableWeight(attemptWeight * 0.9)
                state.currentTrainingWeight = max(exercise.baseWeight, deloadedWeight)
                state.consecutiveFailuresAtWeight = 0
            } else {
                state.currentTrainingWeight = attemptWeight
                state.consecutiveFailuresAtWeight = abs(state.lastAttemptWeight - attemptWeight) < 0.001
                    ? state.consecutiveFailuresAtWeight + 1
                    : 1
            }
            state.lastAttemptFailed = true
            state.lastAttemptWeight = attemptWeight
        } else {
            state.currentTrainingWeight = max(exercise.baseWeight, exercise.roundToNearestLoadableWeight(attemptWeight + 2.5))
            state.consecutiveFailuresAtWeight = 0
            state.lastAttemptFailed = false
            state.lastAttemptWeight = attemptWeight
        }

        exerciseProgressStates[exercise.name] = state
    }
    
    // MARK: - HealthKit Workout Session
    
    /// Start a HealthKit workout session.
    /// For runs, pass `isRun: true` so the watch records a running workout
    /// (outdoor vs treadmill via `outdoor`) instead of strength training.
    func startWorkoutSession(workoutName: String, isRun: Bool = false, outdoor: Bool = true) async {
        guard !isWorkoutActive else { return }

        currentWorkoutStartDate = Date()
        DispatchQueue.main.async {
            self.isWorkoutActive = true
        }

        // Tell the watch to start the HK workout session
        sendStartWorkoutToWatch(workoutName: workoutName, isRun: isRun, outdoor: outdoor)

        // Keep anchored query as fallback HR source (picks up synced data from watch)
        heartRateAnchor = nil
        startHeartRateUpdates()
    }
    
    /// End the current HealthKit workout session and save it
    func endWorkoutSession(duration: TimeInterval) async {
        // Tell watch to end session and save workout to HealthKit
        sendEndWorkoutToWatch()

        currentWorkoutStartDate = nil
        DispatchQueue.main.async {
            self.isWorkoutActive = false
        }
    }

    private func sendStartWorkoutToWatch(workoutName: String, isRun: Bool = false, outdoor: Bool = true) {
        #if canImport(WatchConnectivity)
        guard let session = watchSession else { return }
        let payload: [String: Any] = [
            "type": "startWorkoutSession",
            "workoutName": workoutName,
            "isRun": isRun,
            "outdoor": outdoor
        ]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                print("Failed to send startWorkoutSession: \(error.localizedDescription)")
            }
        } else {
            session.transferUserInfo(payload)
        }
        #endif
    }

    /// Stream live run metrics to the watch so its active-run face stays in sync.
    func sendRunUpdateToWatch(
        goalLabel: String,
        elapsed: TimeInterval,
        distanceKm: Double,
        currentKmPaceSec: Int?,
        averagePaceSec: Int?,
        goalKm: Double?
    ) {
        #if canImport(WatchConnectivity)
        guard let session = watchSession else { return }
        var payload: [String: Any] = [
            "type": "runUpdate",
            "goalLabel": goalLabel,
            "elapsed": elapsed,
            "distanceKm": distanceKm
        ]
        if let currentKmPaceSec { payload["currentKmPaceSec"] = currentKmPaceSec }
        if let averagePaceSec { payload["averagePaceSec"] = averagePaceSec }
        if let goalKm { payload["goalKm"] = goalKm }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
        #endif
    }

    private func sendEndWorkoutToWatch() {
        #if canImport(WatchConnectivity)
        guard let session = watchSession else { return }
        let payload: [String: Any] = ["type": "endWorkoutSession"]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                print("Failed to send endWorkoutSession: \(error.localizedDescription)")
            }
        } else {
            session.transferUserInfo(payload)
        }
        #endif
    }

    func startHeartRateUpdates() {
        guard authorized else { return }
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        if let query = heartRateQuery {
            healthStore.stop(query)
        }

        // Reset anchor when starting heart rate updates during an active workout
        if isWorkoutActive {
            heartRateAnchor = nil
        }

        // Use workout start date when workout is active, otherwise use 5 minutes ago
        let startDate = isWorkoutActive ? (currentWorkoutStartDate ?? Date().addingTimeInterval(-300)) : Date().addingTimeInterval(-300)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)
        let query = HKAnchoredObjectQuery(type: heartRateType, predicate: predicate, anchor: heartRateAnchor, limit: HKObjectQueryNoLimit) { [weak self] _, samples, _, newAnchor, error in
            guard let self = self else { return }
            self.heartRateAnchor = newAnchor
            if let error = error {
                print("Heart rate query error: \(error.localizedDescription)")
            }
            self.processHeartRateSamples(samples)
        }

        query.updateHandler = { [weak self] _, samples, _, newAnchor, error in
            guard let self = self else { return }
            self.heartRateAnchor = newAnchor
            if let error = error {
                print("Heart rate query update error: \(error.localizedDescription)")
            }
            self.processHeartRateSamples(samples)
        }

        heartRateQuery = query
        healthStore.execute(query)
        DispatchQueue.main.async {
            self.isReceivingHeartRate = false
        }
    }

    func stopHeartRateUpdates() {
        if let query = heartRateQuery {
            healthStore.stop(query)
        }
        heartRateQuery = nil
        heartRateAnchor = nil
        DispatchQueue.main.async {
            self.currentHeartRate = nil
            self.isReceivingHeartRate = false
        }
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let lastSample = samples.last else { return }
        updateHeartRate(with: lastSample.quantity)
    }

    private func updateHeartRate(with quantity: HKQuantity) {
        let heartRateValue = quantity.doubleValue(for: heartRateUnit)
        DispatchQueue.main.async {
            self.currentHeartRate = heartRateValue
            self.isReceivingHeartRate = true
        }
    }

    private func configureWatchConnectivity() {
#if canImport(WatchConnectivity)
        guard WCSession.isSupported() else {
            setWatchConnectionStatus(.unsupported)
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
        watchSession = session
        updateWatchStatus(session)
#else
        setWatchConnectionStatus(.unsupported)
#endif
    }

    func sendWatchRestCue(_ cue: WatchRestCue) {
#if canImport(WatchConnectivity)
        guard let session = watchSession else { return }
        updateWatchStatus(session)

        guard session.isPaired, session.isWatchAppInstalled else { return }

        let payload = cue.payload
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                print("Failed to deliver watch rest cue: \(error.localizedDescription)")
            }
            return
        }

        session.transferUserInfo(payload)
#else
        _ = cue
#endif
    }

    func sendWorkoutUpdate(
        workoutName: String,
        exerciseName: String,
        currentExerciseIndex: Int,
        totalExercises: Int,
        currentSetIndex: Int,
        totalSetsIncludingWarmup: Int,
        currentSetWeight: Double,
        currentSetReps: Int,
        isWarmupSet: Bool,
        isResting: Bool,
        restEndDate: Date?,
        platesDescription: String,
        workoutStartDate: Date?,
        nextSetWeight: Double? = nil,
        nextSetReps: Int? = nil,
        nextSetPlatesDescription: String? = nil,
        nextSetLabel: String? = nil,
        nextExerciseName: String? = nil,
        nextSetIsWarmup: Bool? = nil
    ) {
#if canImport(WatchConnectivity)
        guard let session = watchSession else { return }
        updateWatchStatus(session)

        guard session.isPaired, session.isWatchAppInstalled else { return }

        var payload: [String: Any] = [
            "type": "workoutUpdate",
            "workoutName": workoutName,
            "exerciseName": exerciseName,
            "currentExerciseIndex": currentExerciseIndex,
            "totalExercises": totalExercises,
            "currentSetIndex": currentSetIndex,
            "totalSetsIncludingWarmup": totalSetsIncludingWarmup,
            "currentSetWeight": currentSetWeight,
            "currentSetReps": currentSetReps,
            "isWarmupSet": isWarmupSet,
            "isResting": isResting,
            "platesDescription": platesDescription
        ]

        if let restEndDate {
            payload["restEndDate"] = restEndDate.timeIntervalSince1970
        }
        if let workoutStartDate {
            payload["workoutStartDate"] = workoutStartDate.timeIntervalSince1970
        }
        if let nextSetWeight {
            payload["nextSetWeight"] = nextSetWeight
        }
        if let nextSetReps {
            payload["nextSetReps"] = nextSetReps
        }
        if let nextSetPlatesDescription {
            payload["nextSetPlatesDescription"] = nextSetPlatesDescription
        }
        if let nextSetLabel {
            payload["nextSetLabel"] = nextSetLabel
        }
        if let nextExerciseName {
            payload["nextExerciseName"] = nextExerciseName
        }
        if let nextSetIsWarmup {
            payload["nextSetIsWarmup"] = nextSetIsWarmup
        }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                print("Failed to send workout update: \(error.localizedDescription)")
            }
            return
        }

        session.transferUserInfo(payload)
#endif
    }

    private func setWatchConnectionStatus(_ status: WatchConnectionStatus) {
        DispatchQueue.main.async {
            self.watchConnectionStatus = status
        }
    }

    #if canImport(WatchConnectivity)
    private func updateWatchStatus(_ session: WCSession) {
        if !session.isPaired {
            setWatchConnectionStatus(.notPaired)
        } else if !session.isWatchAppInstalled {
            setWatchConnectionStatus(.watchAppNotInstalled)
        } else if session.isReachable {
            setWatchConnectionStatus(.ready)
        } else {
            setWatchConnectionStatus(.pairedNotReachable)
        }
    }
    #endif

    private func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }

        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)
        
        if let stepType = stepType {
            let status = healthStore.authorizationStatus(for: stepType)
            DispatchQueue.main.async {
                self.authorized = (status == .sharingAuthorized)
                    if self.authorized {
                        self.enableBackgroundHeartRateDelivery()
                    }
            }
        }
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("Health data not available on this device")
            return
        }

        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)
        let workoutType = HKObjectType.workoutType()

        var readTypes = Set<HKObjectType>()
        if let step = stepType { readTypes.insert(step) }
        if let hr = heartRateType { readTypes.insert(hr) }
        readTypes.insert(workoutType)

        var shareTypes = Set<HKSampleType>()
        if let step = stepType { shareTypes.insert(step) }
        shareTypes.insert(workoutType)

        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
            DispatchQueue.main.async {
                self.authorized = success
            }
            if success {
                self.enableBackgroundHeartRateDelivery()
            }
            if let error = error {
                print("HealthKit authorization error: \(error.localizedDescription)")
            }
        }
    }

    private func enableBackgroundHeartRateDelivery() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return
        }
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
            if let error = error {
                print("Background delivery registration error: \(error.localizedDescription)")
            }
        }
    }

    func setWorkoutPreference(_ type: WorkoutType) {
        self.selectedWorkoutType = type
        self.selectedActivityType = nil
        self.selectedRunLocation = nil
        Task {
            await suggestActivity(for: type)
        }
    }
    
    func setActivityPreference(_ type: ActivityType) {
        self.selectedActivityType = type
    }

    func resetWorkoutPreference() {
        self.selectedWorkoutType = nil
        self.selectedActivityType = nil
        self.selectedRunLocation = nil
        self.runGoal = RunGoal()
        self.suggestion = nil
    }

    func setRunLocation(_ location: RunLocationType) {
        self.selectedRunLocation = location
    }

    var heartRateStatusDescription: String {
        if let heartRate = currentHeartRate {
            let rounded = Int(heartRate.rounded())
            return "\(rounded) bpm · Live from Apple Watch"
        }
        return watchConnectionStatus.helperText
    }
    
    func getActivitiesForWorkoutType(_ workoutType: WorkoutType) -> [ActivityType] {
        switch workoutType {
        case .cardio:
            return [.run, .walk, .ride]
        case .weights:
            return [.bench, .squat, .deadlift]
        }
    }

    // MARK: - HealthKit Aggregate Queries

    /// Fetches average heart rate over the last 7 days
    func fetchAverageHeartRate() async -> Double? {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return nil
        }

        let calendar = Calendar.current
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let predicate = HKQuery.predicateForSamples(
            withStart: sevenDaysAgo,
            end: now,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                if let error = error {
                    print("Error fetching heart rate: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                let avgHeartRate = result?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                continuation.resume(returning: avgHeartRate)
            }

            self.healthStore.execute(query)
        }
    }

    /// Fetches total step count for today
    func fetchStepCountToday() async -> Double? {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return nil
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    print("Error fetching step count: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                let stepCount = result?.sumQuantity()?.doubleValue(for: HKUnit.count())
                continuation.resume(returning: stepCount)
            }

            self.healthStore.execute(query)
        }
    }

    /// Fetches recent workouts from the last 7 days
    func fetchRecentWorkouts() async -> [HKWorkout] {
        let workoutType = HKObjectType.workoutType()
        let calendar = Calendar.current
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let predicate = HKQuery.predicateForSamples(
            withStart: sevenDaysAgo,
            end: now,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: 20,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    print("Error fetching recent workouts: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }

                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }

            self.healthStore.execute(query)
        }
    }

    // MARK: - Activity Suggestion

    /// Generates personalized activity advice based on aggregated HealthKit data using Foundation Models
    func suggestActivity(for workoutType: WorkoutType) async {
        DispatchQueue.main.async {
            self.isGeneratingAdvice = true
        }
        
        let avgHeartRate = await fetchAverageHeartRate()
        let stepCount = await fetchStepCountToday()
        let recentWorkouts = await fetchRecentWorkouts()

        let suggestion = await generateSuggestionWithAI(
            workoutType: workoutType,
            avgHeartRate: avgHeartRate,
            stepCount: stepCount,
            recentWorkouts: recentWorkouts
        )

        DispatchQueue.main.async {
            self.suggestion = suggestion
            self.isGeneratingAdvice = false
        }
    }

    /// Uses Apple Foundation Models to generate personalized fitness advice with streaming
    private func generateSuggestionWithAI(
        workoutType: WorkoutType,
        avgHeartRate: Double?,
        stepCount: Double?,
        recentWorkouts: [HKWorkout]
    ) async -> String {
        // Build context about the user's health data
        let healthContext = buildHealthContext(
            workoutType: workoutType,
            avgHeartRate: avgHeartRate,
            stepCount: stepCount,
            recentWorkouts: recentWorkouts
        )
        
        do {
            let model = SystemLanguageModel.default
            
            guard model.isAvailable else {
                return "AI advice is not available on this device. Please try again later."
            }
            
            let session = LanguageModelSession()
            
            let prompt = """
            You are a friendly fitness coach. Based on the following health data, provide brief, \
            personalized advice (2-3 sentences max) for the user who wants to do a \(workoutType.rawValue.lowercased()) workout.
            
            \(healthContext)
            
            Be encouraging, specific, and actionable. Consider recovery needs and workout timing.
            """
            
            // Stream the response for real-time UI updates
            var fullResponse = ""
            for try await partial in session.streamResponse(to: prompt) {
                fullResponse = partial.content
                await MainActor.run {
                    self.suggestion = fullResponse
                }
            }
            
            return fullResponse
            
        } catch {
            print("Foundation Models error: \(error.localizedDescription)")
            return "Unable to generate personalized advice at this time. Consider a moderate \(workoutType.rawValue.lowercased()) session based on how you feel."
        }
    }
    
    /// Builds a context string describing the user's health data for the AI model
    private func buildHealthContext(
        workoutType: WorkoutType,
        avgHeartRate: Double?,
        stepCount: Double?,
        recentWorkouts: [HKWorkout]
    ) -> String {
        var context = "Health Data:\n"
        
        // Time of day context
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        case 17..<21: timeOfDay = "evening"
        default: timeOfDay = "night"
        }
        context += "- Current time: \(timeOfDay)\n"
        
        // Heart rate context
        if let avgHR = avgHeartRate {
            context += "- Average resting heart rate (last 7 days): \(Int(avgHR)) bpm\n"
        } else {
            context += "- Heart rate data: not available\n"
        }
        
        // Step count context
        if let steps = stepCount {
            context += "- Steps today: \(Int(steps))\n"
        } else {
            context += "- Step count: not available\n"
        }
        
        // Recent workout context
        let cardioWorkouts = recentWorkouts.filter { workout in
            [.running, .cycling, .swimming, .walking, .hiking, .rowing, .elliptical, .stairClimbing]
                .contains(workout.workoutActivityType)
        }
        let strengthWorkouts = recentWorkouts.filter { $0.workoutActivityType == .traditionalStrengthTraining }
        
        if let lastCardio = cardioWorkouts.first {
            let daysSince = Calendar.current.dateComponents([.day], from: lastCardio.endDate, to: Date()).day ?? 0
            context += "- Days since last cardio workout: \(daysSince)\n"
        } else {
            context += "- No recent cardio workouts recorded\n"
        }
        
        if let lastStrength = strengthWorkouts.first {
            let daysSince = Calendar.current.dateComponents([.day], from: lastStrength.endDate, to: Date()).day ?? 0
            context += "- Days since last strength workout: \(daysSince)\n"
        } else {
            context += "- No recent strength workouts recorded\n"
        }
        
        context += "- Total workouts in last 7 days: \(recentWorkouts.count)\n"
        
        return context
    }
    
    // MARK: - Weights Program Suggestion
    
    func hasActiveWeightsProgram() -> Bool {
        return activeWeightProgram?.isActive ?? false
    }
    
    func generateWeightsProgramSuggestion() async {
        DispatchQueue.main.async {
            self.isGeneratingAdvice = true
        }
        
        let avgHeartRate = await fetchAverageHeartRate()
        let recentWorkouts = await fetchRecentWorkouts()
        
        let suggestion = await generateWeightsSuggestionWithAI(
            avgHeartRate: avgHeartRate,
            recentWorkouts: recentWorkouts
        )
        
        DispatchQueue.main.async {
            self.weightsSuggestion = suggestion
            self.isGeneratingAdvice = false
        }
    }
    
    private func generateWeightsSuggestionWithAI(
        avgHeartRate: Double?,
        recentWorkouts: [HKWorkout]
    ) async -> WeightsSuggestion {
        let strengthWorkouts = recentWorkouts.filter { $0.workoutActivityType == .traditionalStrengthTraining }
        
        let workoutFrequency: String
        if strengthWorkouts.count >= 3 {
            workoutFrequency = "high (already lifting frequently)"
        } else if strengthWorkouts.count >= 1 {
            workoutFrequency = "moderate (some lifting experience)"
        } else {
            workoutFrequency = "low (new to lifting)"
        }
        
        do {
            let model = SystemLanguageModel.default
            
            guard model.isAvailable else {
                return WeightsSuggestion(
                    recommendation: "We recommend starting with 3 days per week of lifting. This is a proven frequency for building strength and muscle while allowing adequate recovery.",
                    reasoning: "3 days is the most common starting point for strength training.",
                    suggestedDays: 3
                )
            }
            
            let session = LanguageModelSession()
            
            let prompt = """
            You are an expert strength training coach. Based on a user with \(workoutFrequency) and \
            average resting heart rate of \(Int(avgHeartRate ?? 70)) bpm, recommend the ideal number of \
            days per week they should lift weights (choose from 1, 2, 3, 4, or 5).
            
            Respond in this exact JSON format (no markdown, just raw JSON):
            {
                "days": <number 1-5>,
                "recommendation": "<2-3 sentence AI recommendation>",
                "reasoning": "<1 sentence explanation>"
            }
            
            Consider their current fitness level, recovery capacity, and the scientific evidence that \
            3-4 days per week is optimal for most people.
            """
            
            var fullResponse = ""
            for try await partial in session.streamResponse(to: prompt) {
                fullResponse = partial.content
            }
            
            // Parse JSON response
            if let data = fullResponse.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let days = json["days"] as? Int,
               let recommendation = json["recommendation"] as? String,
               let reasoning = json["reasoning"] as? String {
                return WeightsSuggestion(
                    recommendation: recommendation,
                    reasoning: reasoning,
                    suggestedDays: days
                )
            } else {
                // Fallback if parsing fails
                return WeightsSuggestion(
                    recommendation: "We recommend starting with 3 days per week of lifting. This balanced approach gives you time for strength building and muscle growth while maintaining adequate recovery.",
                    reasoning: "3 days is scientifically proven to be optimal for most lifters.",
                    suggestedDays: 3
                )
            }
            
        } catch {
            print("Foundation Models error: \(error.localizedDescription)")
            return WeightsSuggestion(
                recommendation: "We recommend starting with 3 days per week of lifting. This balanced approach gives you time for strength building and muscle growth while maintaining adequate recovery.",
                reasoning: "3 days is scientifically proven to be optimal for most lifters.",
                suggestedDays: 3
            )
        }
    }
    
    func setWeightsProgramDays(_ days: Int) {
        // This will be called when the user selects a day option
        // The actual program is created when they click "Create Program"
    }
    
    func setCustomExerciseWeights(_ weights: [String: Double]) {
        self.customExerciseWeights = weights

        for (exerciseName, weight) in weights {
            if let exercise = findExercise(named: exerciseName) {
                let roundedWeight = exercise.roundToNearestLoadableWeight(weight)
                exerciseProgressStates[exerciseName] = ExerciseProgressState(
                    exerciseName: exerciseName,
                    currentTrainingWeight: roundedWeight,
                    consecutiveFailuresAtWeight: 0,
                    lastAttemptWeight: roundedWeight,
                    lastAttemptFailed: false
                )
            }
        }
    }
    
    func getCustomWeight(for exerciseName: String) -> Double? {
        return customExerciseWeights[exerciseName]
    }

    private func findExercise(named exerciseName: String) -> Exercise? {
        for template in WorkoutProgramTemplate.programs.values {
            for workout in template.workouts {
                if let match = workout.exercises.first(where: { $0.name == exerciseName }) {
                    return match
                }
            }
        }
        return nil
    }

    // MARK: - Weight Migration

    private func migrateWeightsToValidIncrements() {
        for (exerciseName, state) in exerciseProgressStates {
            if let exercise = findExercise(named: exerciseName) {
                let rounded = exercise.roundToNearestLoadableWeight(state.currentTrainingWeight)
                if rounded != state.currentTrainingWeight {
                    exerciseProgressStates[exerciseName] = ExerciseProgressState(
                        exerciseName: exerciseName,
                        currentTrainingWeight: rounded,
                        consecutiveFailuresAtWeight: state.consecutiveFailuresAtWeight,
                        lastAttemptWeight: exercise.roundToNearestLoadableWeight(state.lastAttemptWeight),
                        lastAttemptFailed: state.lastAttemptFailed
                    )
                }
            }
        }

        for (exerciseName, weight) in customExerciseWeights {
            if let exercise = findExercise(named: exerciseName) {
                let rounded = exercise.roundToNearestLoadableWeight(weight)
                if rounded != weight {
                    customExerciseWeights[exerciseName] = rounded
                }
            }
        }
    }

    // MARK: - Deload

    var daysSinceLastWorkout: Int? {
        var latestDate: Date? = nil
        if let last = workoutSessionRecords.max(by: { $0.endDate < $1.endDate }) {
            latestDate = last.endDate
        }
        if let last = completedWorkouts.max(by: { $0.completedDate < $1.completedDate }) {
            latestDate = latestDate.map { max($0, last.completedDate) } ?? last.completedDate
        }
        guard let last = latestDate else { return nil }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day
    }

    var shouldShowDeloadBanner: Bool {
        guard activeWeightProgram?.isActive == true else { return false }
        guard let days = daysSinceLastWorkout, days >= 7 else { return false }
        if let deloadDate = lastDeloadDate,
           let lastWorkoutDate = workoutSessionRecords.max(by: { $0.endDate < $1.endDate })?.endDate,
           deloadDate > lastWorkoutDate {
            return false
        }
        return true
    }

    func deloadAllWeights(percent: Double) {
        let factor = 1.0 - (percent / 100.0)

        var updatedStates = exerciseProgressStates
        for (exerciseName, state) in updatedStates {
            if let exercise = findExercise(named: exerciseName) {
                let newWeight = max(exercise.baseWeight, exercise.roundToNearestLoadableWeight(state.currentTrainingWeight * factor))
                updatedStates[exerciseName] = ExerciseProgressState(
                    exerciseName: exerciseName,
                    currentTrainingWeight: newWeight,
                    consecutiveFailuresAtWeight: 0,
                    lastAttemptWeight: newWeight,
                    lastAttemptFailed: false
                )
            }
        }
        exerciseProgressStates = updatedStates

        var updatedCustom = customExerciseWeights
        for (exerciseName, weight) in updatedCustom {
            if exerciseProgressStates[exerciseName] == nil,
               let exercise = findExercise(named: exerciseName) {
                updatedCustom[exerciseName] = max(exercise.baseWeight, exercise.roundToNearestLoadableWeight(weight * factor))
            }
        }
        customExerciseWeights = updatedCustom

        lastDeloadDate = Date()
    }

    // MARK: - Workout Tip Generation
    
    func generateWorkoutTip(for workout: ProgramWorkout) async {
        DispatchQueue.main.async {
            self.isGeneratingAdvice = true
        }
        
        let tip = await generateWorkoutTipWithAI(workout: workout)
        
        DispatchQueue.main.async {
            self.workoutTip = tip
            self.isGeneratingAdvice = false
        }
    }
    
    private func generateWorkoutTipWithAI(workout: ProgramWorkout) async -> String {
        let exerciseNames = workout.exercises.map { $0.name }.joined(separator: ", ")
        
        do {
            let model = SystemLanguageModel.default
            
            guard model.isAvailable else {
                return "Focus on proper form for \(exerciseNames). Take adequate rest between sets."
            }
            
            let session = LanguageModelSession()
            
            let prompt = """
            You are a friendly strength training coach. Generate a brief, actionable tip (1-2 sentences max) \
            for someone about to do a workout with these exercises: \(exerciseNames).
            
            The tip should be specific to these exercises and encourage proper technique and safety.
            Avoid any JSON or special formatting - just provide the tip text directly.
            """
            
            var fullResponse = ""
            for try await partial in session.streamResponse(to: prompt) {
                fullResponse = partial.content
                await MainActor.run {
                    self.workoutTip = fullResponse
                }
            }
            
            return fullResponse
            
        } catch {
            print("Foundation Models error: \(error.localizedDescription)")
            return "Focus on proper form and take adequate rest between sets for optimal results."
        }
    }
}

#if canImport(WatchConnectivity)
extension HealthStore: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WatchConnectivity activation error: \(error.localizedDescription)")
        }
        updateWatchStatus(session)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        updateWatchStatus(session)
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        updateWatchStatus(session)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        updateWatchStatus(session)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleWatchMessage(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleWatchMessage(userInfo)
    }

    private func handleWatchMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        DispatchQueue.main.async {
            switch type {
            case "setComplete":
                NotificationCenter.default.post(
                    name: NSNotification.Name("WatchSetComplete"),
                    object: nil,
                    userInfo: ["didFail": message["didFail"] as? Bool ?? false]
                )
            case "skipRest":
                NotificationCenter.default.post(
                    name: NSNotification.Name("WatchSkipRest"),
                    object: nil
                )
            case "endWorkout":
                NotificationCenter.default.post(
                    name: NSNotification.Name("WatchEndWorkout"),
                    object: nil
                )
            case "heartRateUpdate":
                if let bpm = message["heartRate"] as? Double {
                    self.currentHeartRate = bpm
                    self.isReceivingHeartRate = true
                }
            case "workoutSessionStarted":
                print("Watch confirmed workout session started")
            case "workoutSessionEnded":
                print("Watch confirmed workout session ended and saved")
            default:
                break
            }
        }
    }
}
#endif

