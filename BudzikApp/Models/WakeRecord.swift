import Foundation
import SwiftData

@Model
final class WakeRecord {
    @Attribute(.unique) var id: UUID
    var alarmTime: Date            // scheduled alarm time
    var alarmStartedAt: Date       // moment alarm started ringing
    var movementStartedAt: Date?   // moment user started walking
    var dismissedAt: Date?         // moment alarm was dismissed
    var stepsTaken: Int
    var morningScore: Int

    init(
        id: UUID = UUID(),
        alarmTime: Date,
        alarmStartedAt: Date,
        movementStartedAt: Date? = nil,
        dismissedAt: Date? = nil,
        stepsTaken: Int = 0,
        morningScore: Int = 0
    ) {
        self.id = id
        self.alarmTime = alarmTime
        self.alarmStartedAt = alarmStartedAt
        self.movementStartedAt = movementStartedAt
        self.dismissedAt = dismissedAt
        self.stepsTaken = stepsTaken
        self.morningScore = morningScore
    }

    var reactionTime: TimeInterval? {
        guard let movementStartedAt else { return nil }
        return movementStartedAt.timeIntervalSince(alarmStartedAt)
    }

    var stepTime: TimeInterval? {
        guard let dismissedAt, let movementStartedAt else { return nil }
        return dismissedAt.timeIntervalSince(movementStartedAt)
    }
}
