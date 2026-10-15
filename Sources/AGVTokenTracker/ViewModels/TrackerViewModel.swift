import Foundation
import SwiftUI
import Combine

public enum StatusDisplayMode: String, CaseIterable, Identifiable {
    case tokens = "Tokens"
    case cost = "Cost ($)"
    case compact = "Icon Only"

    public var id: String { rawValue }
}

@MainActor
public final class TrackerViewModel: ObservableObject {
    @Published public var selectedPeriod: TimePeriod = .today {
        didSet {
            UserDefaults.standard.set(selectedPeriod.rawValue, forKey: "agv_selected_period")
        }
    }

    @Published public var displayMode: StatusDisplayMode = .tokens {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: "agv_display_mode")
        }
    }

    @Published public var customBrainPath: String = "" {
        didSet {
            UserDefaults.standard.set(customBrainPath, forKey: "agv_custom_brain_path")
        }
    }

    @Published public var allSteps: [TokenStep] = []
    @Published public var allSessions: [SessionSummary] = []
    @Published public var isScanning: Bool = false
    @Published public var isPulsing: Bool = false
    @Published public var lastRefreshDate: Date = Date()
    @Published public var pricingSyncDate: Date?

    private let scanner = TranscriptScanner.shared
    private let pricing = PricingService.shared
    private let watcher = FolderWatcher()

    public init() {
        if let savedPeriod = UserDefaults.standard.string(forKey: "agv_selected_period"),
           let period = TimePeriod(rawValue: savedPeriod) {
            self.selectedPeriod = period
        }

        if let savedMode = UserDefaults.standard.string(forKey: "agv_display_mode"),
           let mode = StatusDisplayMode(rawValue: savedMode) {
            self.displayMode = mode
        }

        self.customBrainPath = UserDefaults.standard.string(forKey: "agv_custom_brain_path") ?? ""
        self.pricingSyncDate = pricing.lastSyncDate

        refresh()
        startWatcher()

        Task {
            await pricing.fetchRemotePricing()
            await MainActor.run {
                self.pricingSyncDate = self.pricing.lastSyncDate
                self.refresh()
            }
        }
    }

    public func startWatcher() {
        let brainURL = scanner.resolveBrainDirectory(customPath: customBrainPath.isEmpty ? nil : customBrainPath)
        watcher.start(watching: brainURL) { [weak self] in
            Task { @MainActor [weak self] in
                self?.triggerPulse()
                self?.refresh()
            }
        }
    }

    public func refresh() {
        isScanning = true
        let brainURL = scanner.resolveBrainDirectory(customPath: customBrainPath.isEmpty ? nil : customBrainPath)

        Task.detached(priority: .userInitiated) { [scanner] in
            let (steps, sessions) = scanner.scanAll(brainURL: brainURL)
            await MainActor.run {
                self.allSteps = steps
                self.allSessions = sessions
                self.lastRefreshDate = Date()
                self.isScanning = false
            }
        }
    }

    private func triggerPulse() {
        isPulsing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.isPulsing = false
        }
    }

    // MARK: - Filtered Metrics

    public var filteredSteps: [TokenStep] {
        allSteps.filter { selectedPeriod.matches(date: $0.date) }
    }

    public var filteredSessions: [SessionSummary] {
        allSessions.filter { selectedPeriod.matches(date: $0.lastUpdated) }
    }

    public var totalInputTokens: Int {
        filteredSteps.reduce(0) { $0 + $1.inputTokens }
    }

    public var totalCacheReadTokens: Int {
        filteredSteps.reduce(0) { $0 + $1.cacheReadTokens }
    }

    public var totalOutputTokens: Int {
        filteredSteps.reduce(0) { $0 + $1.outputTokens }
    }

    public var totalTokens: Int {
        totalInputTokens + totalCacheReadTokens + totalOutputTokens
    }

    public var totalCost: Double {
        filteredSteps.reduce(0.0) { acc, step in
            let rate = pricing.rateFor(modelName: step.modelName)
            return acc + rate.calculateCost(
                input: step.inputTokens,
                cacheRead: step.cacheReadTokens,
                output: step.outputTokens
            )
        }
    }

    public var cacheHitPercentage: Double {
        let promptTokens = totalInputTokens + totalCacheReadTokens
        guard promptTokens > 0 else { return 0 }
        return (Double(totalCacheReadTokens) / Double(promptTokens)) * 100.0
    }

    public var menuBarTitle: String {
        switch displayMode {
        case .tokens:
            return "⚡️ \(Self.formatCompact(totalTokens))"
        case .cost:
            return "⚡️ \(Self.formatCurrency(totalCost))"
        case .compact:
            return "⚡️"
        }
    }

    // MARK: - Formatters

    public static func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }

    public static func formatCompact(_ num: Int) -> String {
        let d = Double(num)
        if d >= 1_000_000 {
            return String(format: "%.2fM", d / 1_000_000)
        } else if d >= 1_000 {
            return String(format: "%.1fk", d / 1_000)
        } else {
            return "\(num)"
        }
    }

    public static func formatCurrency(_ amount: Double) -> String {
        if amount == 0 {
            return "$0.00"
        } else if amount < 0.01 {
            return String(format: "$%.4f", amount)
        } else if amount < 10.0 {
            return String(format: "$%.3f", amount)
        } else {
            return String(format: "$%.2f", amount)
        }
    }
}
