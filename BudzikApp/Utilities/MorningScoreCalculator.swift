import Foundation

enum MorningScoreCalculator {
    /// Computes Morning Score (0–100) per the formula in CLAUDE.md.
    static func calculate(record: WakeRecord) -> Int {
        let base = 100

        let reactionPenalty: Int = {
            guard let reaction = record.reactionTime, reaction > 60 else { return 0 }
            return Int(((reaction - 60) / 10) * 2)
        }()

        let speedBonus: Int = {
            guard let step = record.stepTime, step < 120 else { return 0 }
            return 10
        }()

        let raw = base - reactionPenalty + speedBonus
        return min(100, max(0, raw))
    }

    /// Breakdown for the score chart.
    static func breakdown(record: WakeRecord) -> Breakdown {
        let base = 100
        let reactionPenalty: Int = {
            guard let reaction = record.reactionTime, reaction > 60 else { return 0 }
            return Int(((reaction - 60) / 10) * 2)
        }()
        let speedBonus: Int = {
            guard let step = record.stepTime, step < 120 else { return 0 }
            return 10
        }()
        return Breakdown(
            base: base,
            reactionPenalty: reactionPenalty,
            speedBonus: speedBonus
        )
    }

    struct Breakdown {
        let base: Int
        let reactionPenalty: Int
        let speedBonus: Int
    }
}
