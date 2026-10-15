import Foundation

public enum TimePeriod: String, CaseIterable, Identifiable, Sendable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case allTime = "All Time"

    public var id: String { rawValue }

    public func matches(date: Date, calendar: Calendar = .current) -> Bool {
        let now = Date()
        switch self {
        case .today:
            return calendar.isDateInToday(date)
        case .yesterday:
            return calendar.isDateInYesterday(date)
        case .thisWeek:
            return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) &&
                   calendar.isDate(date, equalTo: now, toGranularity: .yearForWeekOfYear)
        case .thisMonth:
            return calendar.isDate(date, equalTo: now, toGranularity: .month) &&
                   calendar.isDate(date, equalTo: now, toGranularity: .year)
        case .allTime:
            return true
        }
    }
}
