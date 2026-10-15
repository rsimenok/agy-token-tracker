import Foundation

public enum TimePeriod: String, CaseIterable, Identifiable, Sendable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case allTime = "All Time"

    public var id: String { rawValue }

    public func dateInterval(now: Date = Date(), calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
            return DateInterval(start: start, end: end)
        case .yesterday:
            let todayStart = calendar.startOfDay(for: now)
            guard let start = calendar.date(byAdding: .day, value: -1, to: todayStart) else { return nil }
            return DateInterval(start: start, end: todayStart)
        case .thisWeek:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return nil }
            return weekInterval
        case .thisMonth:
            guard let monthInterval = calendar.dateInterval(of: .month, for: now) else { return nil }
            return monthInterval
        case .allTime:
            return nil
        }
    }

    @inline(__always)
    public func matches(date: Date, interval: DateInterval?) -> Bool {
        guard let interval = interval else { return true }
        return date >= interval.start && date < interval.end
    }

    public func matches(date: Date, calendar: Calendar = .current) -> Bool {
        let interval = dateInterval(calendar: calendar)
        return matches(date: date, interval: interval)
    }
}
