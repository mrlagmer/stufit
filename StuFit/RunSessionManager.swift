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
    @Published private(set) var cadenceSpm: Int?
    @Published private(set) var steps: Int = 0

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
    // Fixes timestamped before this are pre-run/pre-resume cache and ignored.
    private var trackingStartedAt: Date = .distantPast
    private let pedometer = CMPedometer()
    private var pedometerStartDate: Date?

    // Cadence/steps captured on the phone (CMPedometer) for both outdoor and
    // treadmill runs, and HR recorded from the live stream the watch relays.
    // These are saved onto the phone's authoritative workout so the run lands
    // in Health with distance + cadence + HR even though the watch records none.
    private var stepSamples: [HKQuantitySample] = []
    private var lastStepTotal: Double = 0
    private var lastStepSampleAt: Date?
    private var resyncSteps = false
    private var hrSamples: [HKQuantitySample] = []
    private var lastRecordedHR: Double?

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
        }
        // Always capture cadence + steps from the phone; treadmill also takes
        // its distance from here (outdoor distance comes from GPS).
        startStepTracking()

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
        resyncSteps = true   // don't count steps taken while paused
        if outdoor {
            trackingStartedAt = Date()   // ignore fixes buffered during the pause
            locationManager.startUpdatingLocation()
        }
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
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
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
        // Cadence/steps captured on the phone during the run.
        samples.append(contentsOf: stepSamples)

        let finalize: () -> Void = {
            builder.endCollection(withEnd: end) { _, _ in
                builder.finishWorkout { workout, _ in
                    if outdoor, let workout, let routeBuilder {
                        routeBuilder.finishRoute(with: workout, metadata: nil) { _, _ in }
                    }
                }
            }
        }

        let recordedHR = hrSamples
        if !recordedHR.isEmpty {
            // Prefer HR recorded live from the watch's stream — the watch's own
            // run workout is discarded, so HealthKit holds no HR to fetch.
            builder.add(samples + recordedHR) { _, _ in finalize() }
        } else {
            // Fallback for older data paths: pull whatever HR is in HealthKit.
            fetchHeartRateSamples(start: start, end: end) { fetched in
                let all = samples + fetched
                if all.isEmpty {
                    finalize()
                } else {
                    builder.add(all) { _, _ in finalize() }
                }
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
        // Surface the live route in the system location indicator so iOS keeps
        // delivering fixes while backgrounded with the screen off.
        locationManager.showsBackgroundLocationIndicator = true
        trackingStartedAt = Date()
        locationManager.startUpdatingLocation()
    }

    private func startStepTracking() {
        guard CMPedometer.isStepCountingAvailable() || CMPedometer.isDistanceAvailable() else { return }
        let start = Date()
        pedometerStartDate = start
        lastStepSampleAt = start
        pedometer.startUpdates(from: start) { [weak self] data, _ in
            guard let data else { return }
            Task { @MainActor in
                guard let self, self.isActive, !self.paused else { return }
                self.handlePedometer(data)
            }
        }
    }

    private func handlePedometer(_ data: CMPedometerData) {
        let now = Date()

        // Live cadence for the UI (currentCadence is steps/second).
        if let cadence = data.currentCadence?.doubleValue {
            cadenceSpm = Int((cadence * 60).rounded())
        }

        let total = data.numberOfSteps.doubleValue
        steps = Int(total)

        // After a resume, drop the interval that spans the pause so paused steps
        // aren't emitted as a single inflated-cadence sample.
        if resyncSteps {
            resyncSteps = false
            lastStepTotal = total
            lastStepSampleAt = now
            return
        }

        // Record per-interval stepCount samples so the saved workout carries a
        // cadence trace (the bridge/Health derive cadence from step samples).
        let delta = total - lastStepTotal
        if delta >= 1, let from = lastStepSampleAt, now > from,
           let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let sample = HKQuantitySample(
                type: stepType,
                quantity: HKQuantity(unit: .count(), doubleValue: delta),
                start: from,
                end: now
            )
            stepSamples.append(sample)
            lastStepTotal = total
            lastStepSampleAt = now
        }

        // Treadmill distance comes from the pedometer; outdoor uses GPS.
        if !outdoor, let meters = data.distance?.doubleValue {
            distanceMeters = meters
            distanceKm = meters / 1000
            checkForKmCompletion()
        }
    }

    /// Record an HR sample from the value the watch streams in (the watch's own
    /// run workout is discarded, so its HR isn't otherwise persisted). Called
    /// each tick; only stores a new sample when the value changes.
    private func recordHeartRateSample() {
        guard let bpm = heartRate, bpm > 30, bpm < 240, bpm != lastRecordedHR else { return }
        lastRecordedHR = bpm
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let now = Date()
        let sample = HKQuantitySample(
            type: hrType,
            quantity: HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: bpm),
            start: now,
            end: now
        )
        hrSamples.append(sample)
    }

    // MARK: - Timer tick

    private func tick() {
        guard isActive, !paused else { return }
        elapsed = Date().timeIntervalSince(startDate) - accumulatedPaused
        // Pedometer/location push distance asynchronously; recompute km here too
        // so a boundary crossed between updates is still caught promptly.
        checkForKmCompletion()
        recordHeartRateSample()
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
                // Reject low-accuracy fixes and any cached fix recorded before
                // this tracking segment began. We deliberately do NOT reject by
                // "age": when backgrounded iOS delivers fixes in coalesced
                // bursts that are several seconds old but completely valid —
                // discarding them was dropping real distance and gapping the
                // route (which Strava then flagged as bad data).
                guard location.horizontalAccuracy >= 0,
                      location.horizontalAccuracy < 50,
                      location.timestamp >= trackingStartedAt else { continue }

                if let last = lastLocation {
                    let dt = location.timestamp.timeIntervalSince(last.timestamp)
                    // Skip out-of-order / duplicate timestamps from batched delivery.
                    guard dt > 0 else { continue }
                    let step = location.distance(from: last)
                    // Reject physically impossible jumps (> 12 m/s ≈ 43 km/h):
                    // a GPS glitch that would inflate distance and corrupt the route.
                    guard step / dt < 12.0 else { continue }
                    // Drop sub-metre jitter while standing still.
                    if step > 1.0 {
                        distanceMeters += step
                        distanceKm = distanceMeters / 1000
                        checkForKmCompletion()
                    }
                }
                lastLocation = location
                updateGPSStrength(from: location.horizontalAccuracy)
                routeFixes.append(location)
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
