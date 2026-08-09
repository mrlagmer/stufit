import Foundation
import Combine
import HealthKit

@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {
    static let shared = WatchWorkoutManager()

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())

    @Published var currentHeartRate: Double?
    @Published var isSessionActive: Bool = false

    var onHeartRateUpdate: ((Double) -> Void)?
    var onSessionStarted: (() -> Void)?
    var onSessionEnded: (() -> Void)?

    private override init() {
        super.init()
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let typesToShare: Set<HKSampleType> = [HKWorkoutType.workoutType()]
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if let error = error {
                print("Watch HealthKit authorization error: \(error.localizedDescription)")
            }
        }
    }

    func startWorkout(workoutName: String, isRun: Bool = false, outdoor: Bool = true) async {
        guard workoutSession == nil else { return }

        let configuration = HKWorkoutConfiguration()
        if isRun {
            // For runs the iPhone is the authoritative recorder (GPS distance +
            // route) and this watch session exists only to stream heart rate.
            // We deliberately use `.other` rather than `.running`: a `.running`
            // configuration makes HKLiveWorkoutDataSource auto-collect
            // distanceWalkingRunning + stepCount into HealthKit. If the watch
            // session is interrupted mid-run (suspended / wrist-down / killed)
            // those partial samples leak into Health and get picked up ahead of
            // the phone's full GPS distance — which is exactly what truncated a
            // run to ~6.85 km and made Strava flag the data. `.other` still
            // collects heart rate but never distance or steps.
            configuration.activityType = .other
            configuration.locationType = outdoor ? .outdoor : .indoor
        } else {
            configuration.activityType = .traditionalStrengthTraining
            configuration.locationType = .indoor
        }

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            let dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            session.delegate = self
            builder.delegate = self
            builder.dataSource = dataSource

            self.workoutSession = session
            self.workoutBuilder = builder

            session.startActivity(with: Date())
            try await builder.beginCollection(at: Date())

            self.isSessionActive = true
            self.onSessionStarted?()
            print("Watch workout session started: \(workoutName)")
        } catch {
            print("Watch workout session error: \(error.localizedDescription)")
        }
    }

    /// `discard: true` ends the session for heart-rate streaming without saving
    /// a workout — used for runs, where the iPhone saves the authoritative
    /// workout (distance + route) so we avoid a duplicate in Apple Health.
    func endWorkout(discard: Bool = false) async {
        guard let session = workoutSession else { return }

        session.end()

        if let builder = workoutBuilder {
            if discard {
                builder.discardWorkout()
                print("Watch run workout discarded (iPhone saves the run)")
            } else {
                do {
                    let endDate = Date()
                    try await builder.endCollection(at: endDate)
                    try await builder.finishWorkout()
                    print("Watch workout saved to HealthKit")
                } catch {
                    print("Watch workout save error: \(error.localizedDescription)")
                }
            }
        }

        workoutSession = nil
        workoutBuilder = nil
        currentHeartRate = nil
        isSessionActive = false
        onSessionEnded?()
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            self.isSessionActive = (toState == .running)
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Watch workout session failed: \(error.localizedDescription)")
    }
}

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(heartRateType),
              let statistics = workoutBuilder.statistics(for: heartRateType),
              let quantity = statistics.mostRecentQuantity()
        else { return }

        let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))

        Task { @MainActor in
            self.currentHeartRate = bpm
            self.onHeartRateUpdate?(bpm)
        }
    }
}
