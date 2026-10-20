//
//  HealthStore.swift
//  StuFit
//
//  Created by Copilot on 27/1/2026.
//

import Foundation
import Combine
import HealthKit

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

/// What a session was. Records saved before cardio was tracked decode as
/// weights, which is all the app logged back then.
enum SessionKind: String, Codable {
    case weights
    case run
    case walk

    var glyph: String {
        switch self {
        case .weights: return "🏋️"
        case .run: return "🏃"
        case .walk: return "🚶"
        }
    }

    var isCardio: Bool { self != .weights }
}

struct WorkoutSessionRecord: Identifiable, Codable {
    let id: UUID
    let workoutName: String
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let status: WorkoutSessionStatus
    let kind: SessionKind
    let distanceKm: Double?

    init(
        id: UUID,
        workoutName: String,
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        status: WorkoutSessionStatus,
        kind: SessionKind = .weights,
        distanceKm: Double? = nil
    ) {
        self.id = id
        self.workoutName = workoutName
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.status = status
        self.kind = kind
        self.distanceKm = distanceKm
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case workoutName
        case startDate
        case endDate
        case duration
        case status
        case kind
        case distanceKm
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
        self.kind = (try? container.decodeIfPresent(SessionKind.self, forKey: .kind)) ?? .weights
        self.distanceKm = try container.decodeIfPresent(Double.self, forKey: .distanceKm)
    }

    /// Average pace in seconds per km, for cardio sessions with distance.
    var paceSecondsPerKm: Int? {
        guard let distanceKm, distanceKm > 0.05 else { return nil }
        return Int((duration / distanceKm).rounded())
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

final class HealthStore: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var authorized: Bool = false
    @Published var currentHeartRate: Double?
    @Published var isReceivingHeartRate: Bool = false
    @Published var isWorkoutActive: Bool = false
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
    /// Sessions per week the streak counts toward. Defaults to the old
    /// weights program's days so existing streaks carry over.
    @Published var weeklySessionTarget: Int {
        didSet { UserDefaults.standard.set(weeklySessionTarget, forKey: "weeklySessionTarget") }
    }
    private var currentWorkoutStartDate: Date?
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var heartRateAnchor: HKQueryAnchor?
    private let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())

    override init() {
        let savedTarget = UserDefaults.standard.integer(forKey: "weeklySessionTarget")
        self.weeklySessionTarget = savedTarget > 0 ? savedTarget : 3
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

        if savedTarget == 0, let program = activeWeightProgram, program.isActive {
            weeklySessionTarget = program.daysPerWeek
        }

        migrateWeightsToValidIncrements()
        checkAuthorizationStatus()
    }
    
    // MARK: - Workout Tracking
    
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
        status: WorkoutSessionStatus,
        kind: SessionKind = .weights,
        distanceKm: Double? = nil
    ) {
        let record = WorkoutSessionRecord(
            id: UUID(),
            workoutName: workoutName,
            startDate: startDate,
            endDate: endDate,
            duration: duration,
            status: status,
            kind: kind,
            distanceKm: distanceKm
        )
        workoutSessionRecords.append(record)
    }
    
    /// Get the number of times a specific exercise has been completed
    func getExerciseCompletionCount(_ exerciseName: String) -> Int {
        return completedExercises.filter { $0.exerciseName == exerciseName }.count
    }

    /// Returns the next target top-set weight based on exercise performance state.
    func getNextWorkWeight(for exercise: Exercise) -> Double {
        // Bodyweight exercises carry no external load, regardless of any
        // stray progression state or custom weight saved for them.
        guard !exercise.isBodyweightExercise else { return 0.0 }

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

        // No weight progression for bodyweight exercises — adding 2.5kg to a
        // sit up or pull up would invent a load that doesn't exist.
        guard !exercise.isBodyweightExercise else { return }

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
    
    /// Mark a workout session as active and begin observing heart rate.
    func startWorkoutSession(workoutName: String, isRun: Bool = false, outdoor: Bool = true) async {
        guard !isWorkoutActive else { return }

        currentWorkoutStartDate = Date()
        DispatchQueue.main.async {
            self.isWorkoutActive = true
        }

        // Anchored query picks up any heart rate samples synced into HealthKit
        heartRateAnchor = nil
        startHeartRateUpdates()
    }
    
    /// End the current HealthKit workout session and save it
    func endWorkoutSession(duration: TimeInterval) async {
        currentWorkoutStartDate = nil
        DispatchQueue.main.async {
            self.isWorkoutActive = false
        }
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

    // MARK: - HealthKit Aggregate Queries

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
        ExerciseCatalog.exercise(named: exerciseName)
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
        guard !exerciseProgressStates.isEmpty || !customExerciseWeights.isEmpty else { return false }
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
}
