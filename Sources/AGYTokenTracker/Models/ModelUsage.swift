import Foundation
import SwiftUI

public struct ModelUsage: Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let provider: String
    public let inputTokens: Int
    public let cacheReadTokens: Int
    public let outputTokens: Int
    public let totalTokens: Int
    public let estimatedCost: Double
    public let stepCount: Int
    public let sessionCount: Int
    public let percentageOfTotal: Double
    public let cacheHitPercentage: Double
    public let rate: ModelRate
    public let color: Color
    public let quotaGroup: QuotaGroup?

    public var fiveHourQuota: QuotaBucket? { quotaGroup?.fiveHourBucket }
    public var weeklyQuota: QuotaBucket? { quotaGroup?.weeklyBucket }

    public init(
        id: String,
        displayName: String,
        provider: String,
        inputTokens: Int,
        cacheReadTokens: Int,
        outputTokens: Int,
        totalTokens: Int,
        estimatedCost: Double,
        stepCount: Int,
        sessionCount: Int,
        percentageOfTotal: Double,
        cacheHitPercentage: Double,
        rate: ModelRate,
        color: Color,
        quotaGroup: QuotaGroup? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.provider = provider
        self.inputTokens = inputTokens
        self.cacheReadTokens = cacheReadTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.estimatedCost = estimatedCost
        self.stepCount = stepCount
        self.sessionCount = sessionCount
        self.percentageOfTotal = percentageOfTotal
        self.cacheHitPercentage = cacheHitPercentage
        self.rate = rate
        self.color = color
        self.quotaGroup = quotaGroup
    }
}

public struct ModelFormatter: Sendable {
    public static func isValidModelName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 && trimmed.count <= 50 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-. _"))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        let forbidden = ["{", "}", "(", ")", ";", "\"", "'", "[", "]", "return", "nil", "else", "guard", "let", "var", "func", "import", "class", "struct", "enum"]
        let lower = trimmed.lowercased()
        for bad in forbidden {
            if lower.contains(bad) { return false }
        }
        return true
    }

    public static func displayName(for rawName: String?) -> String {
        guard let raw = rawName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "Gemini Flash (Default)"
        }
        let cleaned = raw.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? raw
        guard isValidModelName(cleaned) else {
            return "Gemini Flash (Default)"
        }

        let lower = cleaned.lowercased()
        switch lower {
        case "gemini-3.8-flash", "gemini 3.8 flash":
            return "Gemini 3.8 Flash"
        case "gemini-3-flash", "gemini 3 flash":
            return "Gemini 3 Flash"
        case "gemini-2.5-flash", "gemini 2.5 flash":
            return "Gemini 2.5 Flash"
        case "gemini-2.0-flash", "gemini 2.0 flash":
            return "Gemini 2.0 Flash"
        case "gemini-1.5-flash", "gemini 1.5 flash":
            return "Gemini 1.5 Flash"
        case "gemini-flash", "gemini flash":
            return "Gemini Flash"
        case "gemini-2.5-pro", "gemini 2.5 pro":
            return "Gemini 2.5 Pro"
        case "gemini-1.5-pro", "gemini 1.5 pro":
            return "Gemini 1.5 Pro"
        case "gemini-pro", "gemini pro":
            return "Gemini Pro"
        case "claude-3-7-sonnet", "claude 3.7 sonnet":
            return "Claude 3.7 Sonnet"
        case "claude-3-5-sonnet", "claude 3.5 sonnet":
            return "Claude 3.5 Sonnet"
        case "claude-3-5-haiku", "claude 3.5 haiku":
            return "Claude 3.5 Haiku"
        case "claude-3-opus", "claude 3 opus":
            return "Claude 3 Opus"
        default:
            return isValidModelName(cleaned) ? cleaned : "Gemini Flash (Default)"
        }
    }

    public static func canonicalId(for rawName: String?) -> String {
        let display = displayName(for: rawName)
        return display.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
    }

    public static func color(for displayName: String) -> Color {
        let lower = displayName.lowercased()
        if lower.contains("3.8") { return Color.cyan }
        if lower.contains("pro") { return Color.purple }
        if lower.contains("claude") || lower.contains("sonnet") { return Color.orange }
        if lower.contains("haiku") { return Color.yellow }
        if lower.contains("opus") { return Color.red }
        if lower.contains("flash") { return Color.blue }
        return Color.teal
    }

    public static func provider(for displayName: String) -> String {
        let lower = displayName.lowercased()
        if lower.contains("gemini") { return "Google" }
        if lower.contains("claude") { return "Anthropic" }
        if lower.contains("gpt") || lower.contains("o1") || lower.contains("o3") { return "OpenAI" }
        return "AI"
    }
}
