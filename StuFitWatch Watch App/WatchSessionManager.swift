//
//  WatchSessionManager.swift
//  StuFitWatch Watch App
//
//  Created by Kiro on 16/3/2026.
//

import Foundation
import Combine
import HealthKit
import WatchConnectivity
#if canImport(WatchKit)
import WatchKit
#endif

@MainActor
final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()
    
    let objectWillChange = PassthroughSubject<Void, Never>()
    
    @Published var workoutName: String = "" {
        didSet { objectWillChange.send() }
    }
    @Published var exerciseName: String = "" {
        didSet { objectWillChange.send() }
    }
    @Published var currentExerciseIndex: Int = 0 {
        didSet { objectWillChange.send() }
    }
    @Published var totalExercises: Int = 0 {
        didSet { objectWillChange.send() }
    }
    @Published var currentSetIndex: Int = 0 {
        didSet { objectWillChange.send() }
    }
    @Published var totalSetsIncludingWarmup: Int = 0 {
        didSet { objectWillChange.send() }
    }
    @Published var currentSetWeight: Double = 0 {
        didSet { objectWillChange.send() }
    }
    @Published var currentSetReps: Int = 0 {
        didSet { objectWillChange.send() }
    }
    @Published var isWarmupSet: Bool = false {
        didSet { objectWillChange.send() }
    }
    @Published var isResting: Bool = false {
        didSet { objectWillChange.send() }
    }
    @Published var restTimeRemaining: TimeInterval = 0 {
        didSet { objectWillChange.send() }
    }
    @Published var elapsedTime: TimeInterval = 0 {
        didSet { objectWillChange.send() }
    }
    @Published var platesDescription: String = "" {
        didSet { objectWillChange.send() }
    }
    @Published var nextSetWeight: Double? = nil {
        didSet { objectWillChange.send() }
    }
    @Published var nextSetReps: Int? = nil {
        didSet { objectWillChange.send() }
    }
    @Published var nextSetPlatesDescription: String? = nil {
        didSet { objectWillChange.send() }
    }
    @Published var nextSetLabel: String? = nil {
        didSet { objectWillChange.send() }
    }
    @Published var nextExerciseName: String? = nil {
        didSet { objectWillChange.send() }
    }
    @Published var nextSetIsWarmup: Bool? = nil {
        didSet { objectWillChange.send() }
    }

    // MARK: - Run session state (mirrors the phone's active run)
    @Published var isRunSession: Bool = false {
        didSet { objectWillChange.send() }
    }
    @Published var runGoalLabel: String = "" {
        didSet { objectWillChange.send() }
    }
    @Published var runDistanceKm: Double = 0 {
        didSet { objectWillChange.send() }
    }
    @Published var runCurrentKmPaceSec: Int? = nil {
        didSet { objectWillChange.send() }
    }
    @Published var runAveragePaceSec: Int? = nil {
        didSet { objectWillChange.send() }
    }
    @Published var runGoalKm: Double? = nil {
        didSet { objectWillChange.send() }
    }
    @Published var currentHeartRate: Double? = nil {
        didSet { objectWillChange.send() }
    }

    private var wcSession: WCSession?
    private var timer: Timer?
    private var restEndsAt: Date?
    private var workoutStartDate: Date = .now
    private var now: Date = .now
    private var lastHRSendTime: Date = .distantPast
    private let hrSendInterval: TimeInterval = 3.0
    
    private override init() {
        super.init()
    }
    
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        wcSession = session

        // Start timer for elapsed time and rest countdown
        startTimer()

        // Set up watch workout manager for HealthKit workout sessions
        WatchWorkoutManager.shared.requestAuthorization()

        WatchWorkoutManager.shared.onHeartRateUpdate = { [weak self] bpm in
            self?.currentHeartRate = bpm
            self?.relayHeartRateToPhone(bpm)
        }
        WatchWorkoutManager.shared.onSessionStarted = { [weak self] in
            self?.sendMessage(["type": "workoutSessionStarted"])
        }
        WatchWorkoutManager.shared.onSessionEnded = { [weak self] in
            self?.sendMessage(["type": "workoutSessionEnded"])
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            print("WatchConnectivity activation failed: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleMessage(userInfo)
    }
    
    // MARK: - Message Handling
    
    private func handleMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        
        DispatchQueue.main.async {
            switch type {
            case "workoutUpdate":
                self.handleWorkoutUpdate(message)
            case "runUpdate":
                self.handleRunUpdate(message)
            case "restCue":
                self.handleRestCue(message)
            case "startWorkoutSession":
                let name = message["workoutName"] as? String ?? "Workout"
                let isRun = message["isRun"] as? Bool ?? false
                let outdoor = message["outdoor"] as? Bool ?? true
                self.isRunSession = isRun
                if isRun { self.workoutName = name }
                self.workoutStartDate = Date()
                Task { await WatchWorkoutManager.shared.startWorkout(workoutName: name, isRun: isRun, outdoor: outdoor) }
            case "endWorkoutSession":
                let wasRun = self.isRunSession
                Task { await WatchWorkoutManager.shared.endWorkout(discard: wasRun) }
                self.resetSessionState()
            default:
                break
            }
        }
    }
    
    private func resetSessionState() {
        workoutName = ""
        exerciseName = ""
        currentExerciseIndex = 0
        totalExercises = 0
        currentSetIndex = 0
        totalSetsIncludingWarmup = 0
        currentSetWeight = 0
        currentSetReps = 0
        isWarmupSet = false
        isResting = false
        restTimeRemaining = 0
        elapsedTime = 0
        platesDescription = ""
        nextSetWeight = nil
        nextSetReps = nil
        nextSetPlatesDescription = nil
        nextSetLabel = nil
        nextExerciseName = nil
        nextSetIsWarmup = nil
        restEndsAt = nil
        isRunSession = false
        runGoalLabel = ""
        runDistanceKm = 0
        runCurrentKmPaceSec = nil
        runAveragePaceSec = nil
        runGoalKm = nil
    }

    private func handleRunUpdate(_ message: [String: Any]) {
        isRunSession = true
        if let label = message["goalLabel"] as? String { runGoalLabel = label }
        if let elapsed = message["elapsed"] as? TimeInterval {
            workoutStartDate = Date().addingTimeInterval(-elapsed)
        }
        if let distance = message["distanceKm"] as? Double { runDistanceKm = distance }
        runCurrentKmPaceSec = message["currentKmPaceSec"] as? Int
        runAveragePaceSec = message["averagePaceSec"] as? Int
        runGoalKm = message["goalKm"] as? Double
    }

    private func handleWorkoutUpdate(_ message: [String: Any]) {
        if let workoutName = message["workoutName"] as? String {
            self.workoutName = workoutName
        }
        if let exerciseName = message["exerciseName"] as? String {
            self.exerciseName = exerciseName
        }
        if let currentExerciseIndex = message["currentExerciseIndex"] as? Int {
            self.currentExerciseIndex = currentExerciseIndex
        }
        if let totalExercises = message["totalExercises"] as? Int {
            self.totalExercises = totalExercises
        }
        if let currentSetIndex = message["currentSetIndex"] as? Int {
            self.currentSetIndex = currentSetIndex
        }
        if let totalSetsIncludingWarmup = message["totalSetsIncludingWarmup"] as? Int {
            self.totalSetsIncludingWarmup = totalSetsIncludingWarmup
        }
        if let currentSetWeight = message["currentSetWeight"] as? Double {
            self.currentSetWeight = currentSetWeight
        }
        if let currentSetReps = message["currentSetReps"] as? Int {
            self.currentSetReps = currentSetReps
        }
        if let isWarmupSet = message["isWarmupSet"] as? Bool {
            self.isWarmupSet = isWarmupSet
        }
        if let isResting = message["isResting"] as? Bool {
            self.isResting = isResting
        }
        if let restEndDateTimestamp = message["restEndDate"] as? TimeInterval {
            self.restEndsAt = Date(timeIntervalSince1970: restEndDateTimestamp)
        } else {
            self.restEndsAt = nil
        }
        if let platesDescription = message["platesDescription"] as? String {
            self.platesDescription = platesDescription
        }
        self.nextSetWeight = message["nextSetWeight"] as? Double
        self.nextSetReps = message["nextSetReps"] as? Int
        self.nextSetPlatesDescription = message["nextSetPlatesDescription"] as? String
        self.nextSetLabel = message["nextSetLabel"] as? String
        self.nextExerciseName = message["nextExerciseName"] as? String
        self.nextSetIsWarmup = message["nextSetIsWarmup"] as? Bool
        if let workoutStartDateTimestamp = message["workoutStartDate"] as? TimeInterval {
            self.workoutStartDate = Date(timeIntervalSince1970: workoutStartDateTimestamp)
        }
    }
    
    private func handleRestCue(_ message: [String: Any]) {
        guard let cue = message["cue"] as? String else { return }
        
        switch cue {
        case "tMinus10":
            playHapticTMinus10()
        case "restComplete":
            playHapticRestComplete()
        default:
            break
        }
    }
    
    // MARK: - User Actions
    
    func completeSet(didFail: Bool) {
        let message: [String: Any] = [
            "type": "setComplete",
            "didFail": didFail
        ]
        sendMessage(message)
    }
    
    func skipRest() {
        let message: [String: Any] = [
            "type": "skipRest"
        ]
        sendMessage(message)
    }
    
    func endWorkout() {
        let message: [String: Any] = [
            "type": "endWorkout"
        ]
        sendMessage(message)
        // Also end the local workout session on the watch
        let wasRun = isRunSession
        Task { await WatchWorkoutManager.shared.endWorkout(discard: wasRun) }
    }
    
    // MARK: - Private Helpers

    private func relayHeartRateToPhone(_ bpm: Double) {
        let now = Date()
        guard now.timeIntervalSince(lastHRSendTime) >= hrSendInterval else { return }
        lastHRSendTime = now

        let message: [String: Any] = [
            "type": "heartRateUpdate",
            "heartRate": bpm
        ]
        sendMessage(message)
    }

    private func sendMessage(_ message: [String: Any]) {
        guard let session = wcSession else {
            print("WCSession not available")
            return
        }
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Failed to send message: \(error.localizedDescription)")
            }
        } else {
            print("Watch is not reachable, using transferUserInfo")
            session.transferUserInfo(message)
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.updateTimers()
            }
        }
    }
    
    private func updateTimers() {
        now = .now
        elapsedTime = now.timeIntervalSince(workoutStartDate)
        
        if isResting, let restEndsAt {
            restTimeRemaining = max(0, restEndsAt.timeIntervalSince(now))
        } else {
            restTimeRemaining = 0
        }
    }
    
    private func playHapticTMinus10() {
        #if canImport(WatchKit)
        WKInterfaceDevice.current().play(.directionUp)
        #endif
    }
    
    private func playHapticRestComplete() {
        #if canImport(WatchKit)
        WKInterfaceDevice.current().play(.notification)
        #endif
    }
    
    // MARK: - Computed Properties
    
    var currentSetLabel: String {
        "Set \(currentSetIndex + 1)/\(totalSetsIncludingWarmup)"
    }
    
    var restTimeString: String {
        let roundedSeconds = max(0, Int(restTimeRemaining.rounded(.up)))
        let minutes = roundedSeconds / 60
        let seconds = roundedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var exerciseProgress: Double {
        guard totalExercises > 0 else { return 0 }
        return Double(currentExerciseIndex + 1) / Double(totalExercises)
    }
    
    var restProgress: Double {
        let totalRestDuration: TimeInterval = 180
        return 1.0 - (restTimeRemaining / totalRestDuration)
    }
    
    private func formatPlatesForDisplay(_ platesDescription: String) -> String {
        // The iPhone sends a pre-formatted string, just return it
        return platesDescription
    }
    
    deinit {
        timer?.invalidate()
    }
}
