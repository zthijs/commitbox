import Foundation

nonisolated enum ContributionService {
    enum FetchError: LocalizedError {
        case invalidUsername
        case userNotFound(String)
        case badResponse(Int)
        case unreadablePage

        var errorDescription: String? {
            switch self {
            case .invalidUsername: "That doesn't look like a GitHub username."
            case .userNotFound(let username): "GitHub has no user named \(username)."
            case .badResponse(let status): "GitHub responded with an error (\(status))."
            case .unreadablePage: "Couldn't read the contribution graph from GitHub."
            }
        }
    }

    @concurrent
    static func fetch(username: String) async throws -> ContributionCalendar {
        let username = try normalized(username)
        let url = URL(string: "https://github.com/users/\(username)/contributions")!
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 20))

        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200: break
        case 404: throw FetchError.userNotFound(username)
        case let status: throw FetchError.badResponse(status)
        }

        let days = parseDays(fromHTML: String(decoding: data, as: UTF8.self))
        guard !days.isEmpty else { throw FetchError.unreadablePage }
        return ContributionCalendar(username: username, days: days, fetchedAt: .now)
    }

    static func normalized(_ input: String) throws -> String {
        var username = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let profile = username.firstMatch(of: #/github\.com/([^/?#]+)/#.ignoresCase()) {
            username = String(profile.1)
        }
        if username.hasPrefix("@") {
            username.removeFirst()
        }
        guard username.wholeMatch(of: #/[A-Za-z0-9][A-Za-z0-9-]{0,38}/#) != nil else {
            throw FetchError.invalidUsername
        }
        return username
    }

    static func parseDays(fromHTML html: String) -> [ContributionDay] {
        var countsByID: [Substring: Int] = [:]
        for tooltip in html.matches(of: #/<tool-tip\b[^>]*?\bfor="([^"]+)"[^>]*>\s*([^<]*)</tool-tip>/#) {
            let number = tooltip.2.prefixMatch(of: #/[\d,]+/#)?.0.filter(\.isNumber)
            countsByID[tooltip.1] = number.flatMap { Int($0) } ?? 0
        }

        var days: [ContributionDay] = []
        for tag in html.matches(of: #/<td\b[^>]*\bdata-date="[^"]*"[^>]*>/#) {
            var attributes: [Substring: Substring] = [:]
            for attribute in tag.0.matches(of: #/([\w-]+)="([^"]*)"/#) {
                attributes[attribute.1] = attribute.2
            }

            let ymd = attributes["data-date"]?.split(separator: "-").compactMap { Int($0) } ?? []
            guard ymd.count == 3,
                  let date = ContributionCalendar.calendar.date(from: DateComponents(year: ymd[0], month: ymd[1], day: ymd[2]))
            else { continue }

            let level = attributes["data-level"].flatMap { Int($0) } ?? 0
            let count = attributes["id"].flatMap { countsByID[$0] } ?? 0
            days.append(ContributionDay(date: date, count: count, level: min(max(level, 0), 4)))
        }
        return days.sorted { $0.date < $1.date }
    }
}
