import Foundation
import SwiftUI

extension Date {
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }

    var fullDateTimeString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    var weekdayShort: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "EEE"
        return formatter.string(from: self).capitalized
    }
}

extension Color {
    static func morningScoreColor(score: Int) -> Color {
        switch score {
        case ..<40: return .red
        case ..<70: return .orange
        default:    return .green
        }
    }
}

extension Int {
    var morningScoreLabel: String {
        switch self {
        case ..<40: return "Słaby"
        case ..<70: return "Dobry"
        default:    return "Świetny"
        }
    }
}

extension Array where Element == Int {
    /// Polish-formatted list of repeated weekday short names.
    /// Convention: 0 = Sunday … 6 = Saturday.
    var repeatDaysLabel: String {
        if self.isEmpty { return "Jednorazowo" }
        if Set(self) == Set(0...6) { return "Codziennie" }
        if Set(self) == Set([1, 2, 3, 4, 5]) { return "Dni robocze" }
        if Set(self) == Set([0, 6]) { return "Weekend" }

        let names = ["Nd", "Pn", "Wt", "Śr", "Cz", "Pt", "Sb"]
        return self.sorted().compactMap { names[safe: $0] }.joined(separator: " ")
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
