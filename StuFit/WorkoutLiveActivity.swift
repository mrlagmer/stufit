import ActivityKit
import Foundation

@MainActor
final class WorkoutLiveActivityManager {
    static let shared = WorkoutLiveActivityManager()

    private var activity: Activity<WorkoutLiveActivityAttributes>?

    private init() {}

    func start(
        workoutName: String,
        exerciseName: String,
        setLabel: String,
        startedAt: Date,
        isResting: Bool,
        restEndDate: Date?
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if let activity {
            let content = ActivityContent(state: activity.content.state, staleDate: nil)
            await activity.end(content, dismissalPolicy: .immediate)
            self.activity = nil
        }

        let attributes = WorkoutLiveActivityAttributes(startedAt: startedAt)
        let state = WorkoutLiveActivityAttributes.ContentState(
            workoutName: workoutName,
            exerciseName: exerciseName,
            setLabel: setLabel,
            isResting: isResting,
            restEndDate: restEndDate
        )

        do {
            let content = ActivityContent(state: state, staleDate: nil)
            activity = try Activity<WorkoutLiveActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            // Ignore request failures so workout flow is never blocked.
        }
    }

    func update(
        workoutName: String,
        exerciseName: String,
        setLabel: String,
        isResting: Bool,
        restEndDate: Date?
    ) async {
        guard let activity else { return }

        let state = WorkoutLiveActivityAttributes.ContentState(
            workoutName: workoutName,
            exerciseName: exerciseName,
            setLabel: setLabel,
            isResting: isResting,
            restEndDate: restEndDate
        )

        let content = ActivityContent(state: state, staleDate: nil)
        await activity.update(content)
    }

    func end() async {
        guard let activity else { return }

        let finalState = activity.content.state
        let content = ActivityContent(state: finalState, staleDate: nil)
        await activity.end(content, dismissalPolicy: .immediate)

        self.activity = nil
    }
}
