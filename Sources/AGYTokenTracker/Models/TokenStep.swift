import Foundation

public struct TokenStep: Identifiable, Sendable {
    public let id: String
    public let stepIndex: Int
    public let sessionId: String
    public let date: Date
    public let inputTokens: Int
    public let cacheReadTokens: Int
    public let outputTokens: Int
    public let cost: Double
    public let modelName: String?
    public let canonicalModelId: String
    public let surface: AppSurface

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
        cost: Double = 0.0,
        modelName: String? = nil,
        canonicalModelId: String? = nil,
        surface: AppSurface = .desktop
    ) {
        self.id = "\(surface.rawValue):\(sessionId):\(stepIndex)"
        self.stepIndex = stepIndex
        self.sessionId = sessionId
        self.date = date
        self.inputTokens = inputTokens
        self.cacheReadTokens = cacheReadTokens
        self.outputTokens = outputTokens
        self.cost = cost
        self.modelName = modelName
        self.canonicalModelId = canonicalModelId ?? ModelFormatter.canonicalId(for: modelName)
        self.surface = surface
    }
}

public struct SessionSummary: Identifiable, Sendable {
    public let id: String
    public let sessionId: String
    public let lastUpdated: Date
    public let stepCount: Int
    public let inputTokens: Int
    public let cacheReadTokens: Int
    public let outputTokens: Int
    public let totalTokens: Int
    public let estimatedCost: Double
    public let modelName: String?
    public let surface: AppSurface

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
        modelName: String? = nil,
        surface: AppSurface = .desktop
    ) {
        self.id = "\(surface.rawValue):\(id)"
        self.sessionId = id
        self.lastUpdated = lastUpdated
        self.stepCount = stepCount
        self.inputTokens = inputTokens
        self.cacheReadTokens = cacheReadTokens
        self.outputTokens = outputTokens
        self.totalTokens = inputTokens + cacheReadTokens + outputTokens
        self.estimatedCost = estimatedCost
        self.modelName = modelName
        self.surface = surface
    }
}
