import Foundation
import SwiftUI

/// Represents an individual quota window / bucket (e.g. 5-hour limit, weekly limit).
public struct QuotaBucket: Identifiable, Sendable, Codable {
    public let id: String
    public let name: String
    public let description: String?
    public let window: String // "5h", "weekly"
    public let remainingFraction: Double // 0.0 ... 1.0
    public let resetTime: Date?
    public let rawResetTime: String?

    public init(
        id: String,
        name: String,
        description: String? = nil,
        window: String,
        remainingFraction: Double,
        resetTime: Date? = nil,
        rawResetTime: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.window = window
        self.remainingFraction = max(0.0, min(1.0, remainingFraction))
        self.resetTime = resetTime
        self.rawResetTime = rawResetTime
    }

    public var remainingPercent: Double {
        remainingFraction * 100.0
    }

    public var usedPercent: Double {
        max(0.0, 100.0 - remainingPercent)
    }

    /// Color gauge matching Syrtis: green > 25%, amber 10-25%, red <= 10%
    public var gaugeColor: Color {
        if remainingPercent <= 10.0 {
            return Color(red: 0.937, green: 0.267, blue: 0.267) // Red
        } else if remainingPercent <= 25.0 {
            return Color(red: 0.961, green: 0.620, blue: 0.043) // Amber / Orange
        } else {
            return Color(red: 0.133, green: 0.773, blue: 0.369) // Green
        }
    }

    /// Dynamic countdown to reset: "Resets in 1h 38m", "Resets in 6d 19h"
    public var resetCountdownText: String {
        guard let resetTime = resetTime else {
            return description ?? ""
        }
        let interval = resetTime.timeIntervalSince(Date())
        if interval <= 0 {
            return "Refreshing soon"
        }
        let totalSeconds = Int(interval)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60

        if days > 0 {
            return "Resets in \(days)d \(hours)h"
        } else if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else {
            return "Resets in \(max(1, minutes))m"
        }
    }

    public var windowDisplayName: String {
        let lower = window.lowercased()
        if lower == "5h" {
            return "5-Hour Window"
        } else if lower == "weekly" {
            return "Weekly Window"
        } else {
            return name
        }
    }
}

/// Represents a group of models sharing a quota pool (e.g. Gemini Models, Claude & GPT models).
public struct QuotaGroup: Identifiable, Sendable, Codable {
    public var id: String { name }
    public let name: String
    public let description: String?
    public let buckets: [QuotaBucket]

    public init(name: String, description: String? = nil, buckets: [QuotaBucket]) {
        self.name = name
        self.description = description
        self.buckets = buckets
    }

    public var fiveHourBucket: QuotaBucket? {
        buckets.first(where: { $0.window.lowercased() == "5h" || $0.id.lowercased().contains("5h") })
    }

    public var weeklyBucket: QuotaBucket? {
        buckets.first(where: { $0.window.lowercased() == "weekly" || $0.id.lowercased().contains("weekly") })
    }

    public func matches(modelName: String) -> Bool {
        let lower = modelName.lowercased()
        let groupLower = name.lowercased()
        if groupLower.contains("gemini") {
            return lower.contains("gemini")
        }
        if groupLower.contains("claude") || groupLower.contains("gpt") {
            return lower.contains("claude") || lower.contains("sonnet") || lower.contains("opus") || lower.contains("haiku") || lower.contains("gpt") || lower.contains("openai")
        }
        return false
    }

    public var iconName: String {
        let lower = name.lowercased()
        if lower.contains("gemini") {
            return "sparkles"
        } else if lower.contains("claude") {
            return "brain.head.profile"
        } else {
            return "cpu"
        }
    }

    public var tintColor: Color {
        let lower = name.lowercased()
        if lower.contains("gemini") {
            return .blue
        } else if lower.contains("claude") {
            return .orange
        } else {
            return .purple
        }
    }
}

/// A complete quota snapshot containing groups and buckets fetched from the Antigravity backend.
public struct QuotaSnapshot: Sendable, Codable {
    public let fetchedAt: Date
    public let description: String?
    public let groups: [QuotaGroup]

    public init(fetchedAt: Date = Date(), description: String? = nil, groups: [QuotaGroup]) {
        self.fetchedAt = fetchedAt
        self.description = description
        self.groups = groups
    }

    public func group(for modelName: String) -> QuotaGroup? {
        groups.first(where: { $0.matches(modelName: modelName) })
    }

    public var allBuckets: [QuotaBucket] {
        groups.flatMap(\.buckets)
    }
}
