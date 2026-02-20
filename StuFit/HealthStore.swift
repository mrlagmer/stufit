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
}

struct CompletedWorkout: Identifiable, Codable {
    let id: UUID
    let workoutName: String
    let completedDate: Date
}

struct CompletedExercise: Identifiable, Codable {
    let id: UUID
    let exerciseName: String
    let workoutName: String
    let completedDate: Date
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
    private var currentWorkoutStartDate: Date?
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var heartRateAnchor: HKQueryAnchor?
    private let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var workoutDataSource: HKLiveWorkoutDataSource?
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
    
    /// Get the number of times a specific exercise has been completed
    func getExerciseCompletionCount(_ exerciseName: String) -> Int {
        return completedExercises.filter { $0.exerciseName == exerciseName }.count
    }
    
    // MARK: - HealthKit Workout Session
    
    /// Start a HealthKit workout session
    func startWorkoutSession(workoutName: String) async {
        guard authorized else {
            print("Health authorization required to start workout")
            return
        }

        guard HKHealthStore.isHealthDataAvailable() else {
            print("Health data is not available on this device")
            return
        }

        guard !isWorkoutActive else {
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            let dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            session.delegate = self
            builder.delegate = self
            builder.dataSource = dataSource
            try await builder.addMetadata([HKMetadataKeyWorkoutBrandName: workoutName])

            workoutSession = session
            workoutBuilder = builder
            workoutDataSource = dataSource

            session.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { success, error in
                if let error = error {
                    print("Workout builder start error: \(error.localizedDescription)")
                    return
                }
                if !success {
                    print("Workout builder failed to begin collection")
                }
            }

            currentWorkoutStartDate = Date()
            DispatchQueue.main.async {
                self.isWorkoutActive = true
            }
            startHeartRateUpdates()
        } catch {
            print("Workout session error: \(error.localizedDescription)")
        }
    }
    
    /// End the current HealthKit workout session and save it
    func endWorkoutSession(duration: TimeInterval) async {
        guard let startDate = currentWorkoutStartDate else {
            print("No active workout session to end")
            return
        }

        let endDate = Date()
        workoutSession?.end()

        if let builder = workoutBuilder {
            do {
                try await finishWorkoutCollection(using: builder, endDate: endDate)
            } catch {
                print("Workout collection error: \(error.localizedDescription)")
                await saveFallbackWorkout(startDate: startDate, endDate: endDate, duration: duration)
            }
        } else {
            await saveFallbackWorkout(startDate: startDate, endDate: endDate, duration: duration)
        }

        currentWorkoutStartDate = nil
        workoutSession = nil
        workoutBuilder = nil
        workoutDataSource = nil

        DispatchQueue.main.async {
            self.isWorkoutActive = false
        }
    }

    private func finishWorkoutCollection(using builder: HKLiveWorkoutBuilder, endDate: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: endDate) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if !success {
                    let endError = NSError(domain: "StuFit.HealthStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Workout builder failed to end collection"]) as Error
                    continuation.resume(throwing: endError)
                    return
                }
                builder.finishWorkout { _, finishError in
                    if let finishError = finishError {
                        continuation.resume(throwing: finishError)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        }
    }

    private func saveFallbackWorkout(startDate: Date, endDate: Date, duration: TimeInterval) async {
        let workout = HKWorkout(
            activityType: .traditionalStrengthTraining,
            start: startDate,
            end: endDate,
            duration: duration,
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: nil
        )

        do {
            try await healthStore.save(workout)
            print("Workout saved to HealthKit (fallback)")
        } catch {
            print("Error saving workout to HealthKit: \(error.localizedDescription)")
        }
    }

    func startHeartRateUpdates() {
        guard authorized else { return }
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        if let query = heartRateQuery {
            healthStore.stop(query)
        }

        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-300), end: nil, options: .strictStartDate)
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
            watchConnectionStatus = .unsupported
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
        watchSession = session
        updateWatchStatus(session)
#else
        watchConnectionStatus = .unsupported
#endif
    }

    #if canImport(WatchConnectivity)
    private func updateWatchStatus(_ session: WCSession) {
        if !session.isPaired {
            watchConnectionStatus = .notPaired
        } else if !session.isWatchAppInstalled {
            watchConnectionStatus = .watchAppNotInstalled
        } else if session.isReachable {
            watchConnectionStatus = .ready
        } else {
            watchConnectionStatus = .pairedNotReachable
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
        self.suggestion = nil
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
    }
    
    func getCustomWeight(for exerciseName: String) -> Double? {
        return customExerciseWeights[exerciseName]
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

extension HealthStore: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            self.isWorkoutActive = (toState == .running)
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(heartRateType),
              let statistics = workoutBuilder.statistics(for: heartRateType),
              let quantity = statistics.mostRecentQuantity()
        else {
            return
        }
        updateHeartRate(with: quantity)
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
}
#endif

