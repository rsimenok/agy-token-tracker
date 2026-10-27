import Foundation

public struct ModelMonthlyStat: Codable, Sendable, Equatable {
    public var displayName: String
    public var canonicalModelId: String
    public var tokens: Int
    public var cost: Double

    public init(displayName: String, canonicalModelId: String, tokens: Int, cost: Double) {
        self.displayName = displayName
        self.canonicalModelId = canonicalModelId
        self.tokens = tokens
        self.cost = cost
    }
}

public struct SurfaceMonthlyStat: Codable, Sendable, Equatable {
    public var tokens: Int
    public var cost: Double
    public var sessions: Int

    public init(tokens: Int, cost: Double, sessions: Int) {
        self.tokens = tokens
        self.cost = cost
        self.sessions = sessions
    }
}

public struct MonthlyRecord: Codable, Identifiable, Sendable, Equatable {
    public let year: Int
    public let month: Int // 1...12
    public var inputTokens: Int
    public var cacheReadTokens: Int
    public var outputTokens: Int
    public var totalTokens: Int
    public var totalCost: Double
    public var sessionCount: Int
    public var stepCount: Int
    public var modelBreakdown: [String: ModelMonthlyStat]
    public var surfaceBreakdown: [String: SurfaceMonthlyStat]
    public var lastUpdated: Date

    public var id: String {
        String(format: "%04d-%02d", year, month)
    }

    public var cacheHitRatio: Double {
        let totalPrompt = inputTokens + cacheReadTokens
        guard totalPrompt > 0 else { return 0 }
        return Double(cacheReadTokens) / Double(totalPrompt)
    }

    public var monthName: String {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        if let date = calendar.date(from: components) {
            let formatter = DateFormatter()
            formatter.dateFormat = "LLLL"
            return formatter.string(from: date).capitalized
        }
        return "Month \(month)"
    }

    public var shortMonthName: String {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        if let date = calendar.date(from: components) {
            let formatter = DateFormatter()
            formatter.dateFormat = "LLL"
            return formatter.string(from: date).capitalized
        }
        return "M\(month)"
    }

    public init(
        year: Int,
        month: Int,
        inputTokens: Int = 0,
        cacheReadTokens: Int = 0,
        outputTokens: Int = 0,
        totalTokens: Int = 0,
        totalCost: Double = 0.0,
        sessionCount: Int = 0,
        stepCount: Int = 0,
        modelBreakdown: [String: ModelMonthlyStat] = [:],
        surfaceBreakdown: [String: SurfaceMonthlyStat] = [:],
        lastUpdated: Date = Date()
    ) {
        self.year = year
        self.month = month
        self.inputTokens = inputTokens
        self.cacheReadTokens = cacheReadTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.sessionCount = sessionCount
        self.stepCount = stepCount
        self.modelBreakdown = modelBreakdown
        self.surfaceBreakdown = surfaceBreakdown
        self.lastUpdated = lastUpdated
    }

    /// Filtered metrics for a specific surface
    public func metrics(for surface: AppSurface) -> (tokens: Int, cost: Double, sessions: Int) {
        if surface == .all {
            return (totalTokens, totalCost, sessionCount)
        }
        if let stat = surfaceBreakdown[surface.rawValue] {
            return (stat.tokens, stat.cost, stat.sessions)
        }
        return (0, 0.0, 0)
    }
}

public struct MonthlyHistoryData: Codable, Sendable {
    public var version: Int
    public var lastScanDate: Date
    public var records: [String: MonthlyRecord]

    public init(
        version: Int = 1,
        lastScanDate: Date = Date(),
        records: [String: MonthlyRecord] = [:]
    ) {
        self.version = version
        self.lastScanDate = lastScanDate
        self.records = records
    }
}
