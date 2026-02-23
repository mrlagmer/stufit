import ActivityKit
import Foundation

struct WorkoutLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var workoutName: String
        var exerciseName: String
        var setLabel: String
        var isResting: Bool
        var restEndDate: Date?
    }

    var startedAt: Date
}
