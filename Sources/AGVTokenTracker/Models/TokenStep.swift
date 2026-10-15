import Foundation

public struct TokenStep: Identifiable, Sendable {
    public let id: String
    public let stepIndex: Int
    public let sessionId: String
    public let date: Date
    public let inputTokens: Int
    public let cacheReadTokens: Int
    public let outputTokens: Int
    public let modelName: String?

    public var totalTokens: Int {
        inputTokens + cacheReadTokens + outputTokens
    }

    public var billableTokens: Int {
        inputTokens + outputTokens
    }

    public init(
        stepIndex: Int,
        sessionId: String,
        date: Date,
        inputTokens: Int,
        cacheReadTokens: Int,
        outputTokens: Int,
        modelName: String? = nil
    ) {
        self.id = "\(sessionId):\(stepIndex)"
        self.stepIndex = stepIndex
        self.sessionId = sessionId
        self.date = date
        self.inputTokens = inputTokens
        self.cacheReadTokens = cacheReadTokens
        self.outputTokens = outputTokens
        self.modelName = modelName
    }
}

public struct SessionSummary: Identifiable, Sendable {
    public let id: String
    public let lastUpdated: Date
    public let stepCount: Int
    public let inputTokens: Int
    public let cacheReadTokens: Int
    public let outputTokens: Int
    public let totalTokens: Int
    public let estimatedCost: Double
    public let modelName: String?

    public var cacheHitRatio: Double {
        let totalInput = inputTokens + cacheReadTokens
        guard totalInput > 0 else { return 0 }
        return Double(cacheReadTokens) / Double(totalInput)
    }

    public init(
        id: String,
        lastUpdated: Date,
        stepCount: Int,
        inputTokens: Int,
        cacheReadTokens: Int,
        outputTokens: Int,
        estimatedCost: Double,
        modelName: String? = nil
    ) {
        self.id = id
        self.lastUpdated = lastUpdated
        self.stepCount = stepCount
        self.inputTokens = inputTokens
        self.cacheReadTokens = cacheReadTokens
        self.outputTokens = outputTokens
        self.totalTokens = inputTokens + cacheReadTokens + outputTokens
        self.estimatedCost = estimatedCost
        self.modelName = modelName
    }
}
