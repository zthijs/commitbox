import Foundation

nonisolated struct ContributionDay: Codable, Hashable, Sendable {
    let date: Date
    let count: Int
    let level: Int

    var isActive: Bool { count > 0 || level > 0 }
}

nonisolated struct ContributionCalendar: Codable, Hashable, Sendable {
    let username: String
    let days: [ContributionDay]
    let fetchedAt: Date

    static let calendar = Calendar(identifier: .gregorian)

    var year: Int {
        Self.calendar.component(.year, from: days.last?.date ?? fetchedAt)
    }

    var yearTotal: Int {
        let year = year
        return days.lazy
            .filter { Self.calendar.component(.year, from: $0.date) == year }
            .reduce(0) { $0 + $1.count }
    }

    var currentStreak: Int {
        var remaining = days[...]
        if remaining.last?.isActive == false {
            remaining = remaining.dropLast()
        }
        return remaining.reversed().prefix(while: \.isActive).count
    }

    var weeks: [[ContributionDay?]] {
        guard let first = days.first else { return [] }
        let leadingBlanks = Self.calendar.component(.weekday, from: first.date) - 1
        var slots: [ContributionDay?] = Array(repeating: nil, count: leadingBlanks) + days
        slots += Array(repeating: nil, count: (7 - slots.count % 7) % 7)
        return stride(from: 0, to: slots.count, by: 7).map { Array(slots[$0 ..< $0 + 7]) }
    }
}

extension ContributionCalendar {
    static let sample: ContributionCalendar = {
        let today = calendar.startOfDay(for: .now)
        let days = (0 ..< 365).map { offset in
            let wave = sin(Double(offset) * 0.9) + sin(Double(offset) * 0.21) + cos(Double(offset) * 0.05)
            let count = max(0, Int((wave * 3.5).rounded()))
            let level = count == 0 ? 0 : min(4, (count + 2) / 3)
            let date = calendar.date(byAdding: .day, value: offset - 364, to: today)!
            return ContributionDay(date: date, count: count, level: level)
        }
        return ContributionCalendar(username: "octocat", days: days, fetchedAt: .now)
    }()
}
