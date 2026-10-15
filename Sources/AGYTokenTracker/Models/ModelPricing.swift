import Foundation

public struct ModelRate: Codable, Sendable {
    public let inputPerMillion: Double
    public let cacheReadPerMillion: Double
    public let outputPerMillion: Double

    public var inputPerToken: Double { inputPerMillion / 1_000_000.0 }
    public var cacheReadPerToken: Double { cacheReadPerMillion / 1_000_000.0 }
    public var outputPerToken: Double { outputPerMillion / 1_000_000.0 }

    public init(inputPerMillion: Double, cacheReadPerMillion: Double, outputPerMillion: Double) {
        self.inputPerMillion = inputPerMillion
        self.cacheReadPerMillion = cacheReadPerMillion
        self.outputPerMillion = outputPerMillion
    }

    public func calculateCost(input: Int, cacheRead: Int, output: Int) -> Double {
        (Double(input) * inputPerToken) +
        (Double(cacheRead) * cacheReadPerToken) +
        (Double(output) * outputPerToken)
    }
}
