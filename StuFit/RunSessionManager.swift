//
//  RunSessionManager.swift
//  FullFitness
//
//  Drives an active run: elapsed time, distance (GPS outdoor / pedometer
//  treadmill), overall + current-km pace, per-km splits, and a spoken pace
//  cue at the end of every kilometre. Heart rate comes from the paired watch
//  via HealthStore. The km cue reuses the weights speech flow so podcasts
//  duck for the announcement and resume once it finishes.
//

import Foundation
import Combine
import CoreLocation
import CoreMotion
import HealthKit
import UIKit

@MainActor
final class RunSessionManager: NSObject, ObservableObject {

    struct Split: Identifiable {
        let id = UUID()
        let km: Int
        let seconds: Int
    }

    enum GPSStrength {
        case notApplicable   // treadmill — no GPS
        case acquiring
        case weak
        case fair
        case strong

        var label: String {
            switch self {
            case .notApplicable: return "TREADMILL"
            case .acquiring:     return "ACQUIRING"
            case .weak:          return "WEAK"
            case .fair:          return "FAIR"
            case .strong:        return "STRONG"
            }
        }
    }

    // MARK: - Published state (drives the UI)

    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var distanceKm: Double = 0
    @Published private(set) var splits: [Split] = []
    @Published private(set) var paused: Bool = false
    @Published private(set) var isActive: Bool = false
    @Published private(set) var gpsStrength: GPSStrength = .acquiring

    // MARK: - Configuration

    let goal: RunGoal
    let outdoor: Bool
    private let healthStore: HealthStore

    // MARK: - Internals

    private let speech = SpeechSynthesizerDelegate()
    private var timer: Timer?

    private var startDate = Date()
    private var pauseStartedAt: Date?
    private var accumulatedPaused: TimeInterval = 0

    private var distanceMeters: Double = 0
    private var completedKm = 0
    private var lastSplitElapsed: TimeInterval = 0

    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private let pedometer = CMPedometer()
    private var pedometerStartDate: Date?

    private var lastWatchUpdate: Date = .distantPast

    // HealthKit — the phone saves the authoritative run workout (distance +
    // route + duration) so the run lands in Apple Health with or without a watch.
    private let hkStore = HKHealthStore()
    private var workoutBuilder: HKWorkoutBuilder?
    private var routeBuilder: HKWorkoutRouteBuilder?

    init(goal: RunGoal, outdoor: Bool, healthStore: HealthStore) {
        self.goal = goal
        self.outdoor = outdoor
        self.healthStore = healthStore
        super.init()
        self.gpsStrength = outdoor ? .acquiring : .notApplicable
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .fitness
        locationManager.distanceFilter = kCLDistanceFilterNone
    }

    // MARK: - Derived metrics

    var goalKm: Double? {
        goal.type == .distance ? goal.distanceKm : nil
    }

    var goalLabel: String {
        let place = outdoor ? "Outdoor" : "Treadmill"
        switch goal.type {
        case .distance: return "\(formatKm(goal.distanceKm)) km run · \(place)"
        case .time:     return "\(goal.timeMinutes) min run · \(place)"
        case .open:     return "Open run · \(place)"
        }
    }

    /// Average pace over the whole run, in seconds per km.
    var overallPaceSec: Int? {
        guard distanceKm > 0.05 else { return nil }
        return Int((elapsed / distanceKm).rounded())
    }

    /// Pace over the kilometre currently in progress, in seconds per km.
    var currentKmPaceSec: Int? {
        let intoCurrent = distanceKm - Double(completedKm)
        guard intoCurrent > 0.03 else { return nil }
        let timeIntoCurrent = elapsed - lastSplitElapsed
        guard timeIntoCurrent > 0 else { return nil }
        return Int((timeIntoCurrent / intoCurrent).rounded())
    }

    var heartRate: Double? { healthStore.currentHeartRate }

    // MARK: - Lifecycle

    func start() {
        guard !isActive else { return }
        isActive = true
        startDate = Date()
        UIApplication.shared.isIdleTimerDisabled = true

        // HealthKit run workout (streams HR back from the watch).
        Task {
            await healthStore.startWorkoutSession(
                workoutName: goalLabel,
                isRun: true,
                outdoor: outdoor
            )
        }

        beginHealthKitWorkout()

        if outdoor {
            startLocationTracking()
        } else {
            startPedometerTracking()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func togglePause() {
        paused ? resume() : pause()
    }

    func pause() {
        guard isActive, !paused else { return }
        paused = true
        pauseStartedAt = Date()
        if outdoor { locationManager.stopUpdatingLocation() }
    }

    func resume() {
        guard isActive, paused else { return }
        if let pauseStartedAt {
            accumulatedPaused += Date().timeIntervalSince(pauseStartedAt)
        }
        pauseStartedAt = nil
        paused = false
        lastLocation = nil   // don't count distance jumped while paused
        if outdoor { locationManager.startUpdatingLocation() }
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        timer?.invalidate()
        timer = nil
        locationManager.stopUpdatingLocation()
        pedometer.stopUpdates()
        speech.stopAndClearQueue()
        UIApplication.shared.isIdleTimerDisabled = false
        finishHealthKitWorkout()
        Task { await healthStore.endWorkoutSession(duration: elapsed) }
    }

    // MARK: - HealthKit workout

    private func beginHealthKitWorkout() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKSeriesType.workoutRoute()
        ]
        let begin = startDate
        hkStore.requestAuthorization(toShare: share, read: []) { [weak self] granted, _ in
            guard granted else { return }
            Task { @MainActor in self?.startWorkoutBuilder(at: begin) }
        }
    }

    private func startWorkoutBuilder(at begin: Date) {
        guard isActive else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = outdoor ? .outdoor : .indoor

        let builder = HKWorkoutBuilder(healthStore: hkStore, configuration: config, device: .local())
        workoutBuilder = builder
        if outdoor {
            routeBuilder = HKWorkoutRouteBuilder(healthStore: hkStore, device: .local())
        }
        builder.beginCollection(withStart: begin) { _, _ in }
    }

    private func finishHealthKitWorkout() {
        guard let builder = workoutBuilder else { return }
        workoutBuilder = nil
        let routeBuilder = self.routeBuilder
        self.routeBuilder = nil
        let end = Date()
        let start = startDate
        let meters = distanceMeters
        let outdoor = self.outdoor

        var samples: [HKSample] = []
        if meters > 0, let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            let quantity = HKQuantity(unit: .meter(), doubleValue: meters)
            samples.append(HKQuantitySample(type: distanceType, quantity: quantity, start: start, end: end))
        }
        // Rough active-energy estimate: ~0.9 kcal per kg per km ≈ 63 kcal/km at 70 kg.
        let kcal = (meters / 1000) * 63
        if kcal > 0, let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
            samples.append(HKQuantitySample(type: energyType, quantity: quantity, start: start, end: end))
        }

        let finalize: () -> Void = {
            builder.endCollection(withEnd: end) { _, _ in
                builder.finishWorkout { workout, _ in
                    if outdoor, let workout, let routeBuilder {
                        routeBuilder.finishRoute(with: workout, metadata: nil) { _, _ in }
                    }
                }
            }
        }

        // Pull HR samples the watch streamed into HealthKit during the run and
        // attach them to this workout so Apple Health shows HR for the activity.
        fetchHeartRateSamples(start: start, end: end) { hrSamples in
            let all = samples + hrSamples
            if all.isEmpty {
                finalize()
            } else {
                builder.add(all) { _, _ in finalize() }
            }
        }
    }

    private func fetchHeartRateSamples(start: Date, end: Date, completion: @escaping ([HKSample]) -> Void) {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion([])
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: hrType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            completion(samples ?? [])
        }
        hkStore.execute(query)
    }

    // MARK: - Tracking sources

    private func startLocationTracking() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        // Enabling background updates throws if "location" isn't declared in
        // UIBackgroundModes, so only do it when the mode is actually present.
        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        if backgroundModes.contains("location") {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
        }
        locationManager.startUpdatingLocation()
    }

    private func startPedometerTracking() {
        guard CMPedometer.isDistanceAvailable() else { return }
        pedometerStartDate = Date()
        pedometer.startUpdates(from: pedometerStartDate ?? Date()) { [weak self] data, _ in
            guard let data, let meters = data.distance?.doubleValue else { return }
            Task { @MainActor in
                guard let self, !self.paused else { return }
                self.distanceMeters = meters
                self.distanceKm = meters / 1000
                self.checkForKmCompletion()
            }
        }
    }

    // MARK: - Timer tick

    private func tick() {
        guard isActive, !paused else { return }
        elapsed = Date().timeIntervalSince(startDate) - accumulatedPaused
        // Pedometer/location push distance asynchronously; recompute km here too
        // so a boundary crossed between updates is still caught promptly.
        checkForKmCompletion()
        pushWatchUpdate()
    }

    /// Fire a split + spoken cue each time a whole new kilometre is completed.
    private func checkForKmCompletion() {
        while distanceKm >= Double(completedKm + 1) {
            completedKm += 1
            let splitSeconds = Int((elapsed - lastSplitElapsed).rounded())
            lastSplitElapsed = elapsed
            let split = Split(km: completedKm, seconds: max(1, splitSeconds))
            splits.append(split)
            speech.speakRunSplit(km: split.km, paceSeconds: split.seconds)
            pushWatchUpdate(force: true)
        }
    }

    private func pushWatchUpdate(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastWatchUpdate) >= 2 else { return }
        lastWatchUpdate = now
        healthStore.sendRunUpdateToWatch(
            goalLabel: goalLabel,
            elapsed: elapsed,
            distanceKm: distanceKm,
            currentKmPaceSec: currentKmPaceSec,
            averagePaceSec: overallPaceSec,
            goalKm: goalKm
        )
    }

    private func formatKm(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}

// MARK: - CLLocationManagerDelegate

extension RunSessionManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard isActive, !paused else { return }
            var routeFixes: [CLLocation] = []
            for location in locations {
                // Ignore stale or low-accuracy fixes.
                guard location.horizontalAccuracy >= 0,
                      location.horizontalAccuracy < 50,
                      abs(location.timestamp.timeIntervalSinceNow) < 5 else { continue }

                updateGPSStrength(from: location.horizontalAccuracy)
                routeFixes.append(location)

                if let last = lastLocation {
                    let step = location.distance(from: last)
                    // Drop GPS jitter while standing still.
                    if step > 1.0 {
                        distanceMeters += step
                        distanceKm = distanceMeters / 1000
                        checkForKmCompletion()
                    }
                }
                lastLocation = location
            }
            if !routeFixes.isEmpty {
                routeBuilder?.insertRouteData(routeFixes) { _, _ in }
            }
        }
    }

    private func updateGPSStrength(from accuracy: CLLocationAccuracy) {
        if accuracy <= 10 { gpsStrength = .strong }
        else if accuracy <= 25 { gpsStrength = .fair }
        else { gpsStrength = .weak }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep the run going on transient GPS errors.
    }
}
