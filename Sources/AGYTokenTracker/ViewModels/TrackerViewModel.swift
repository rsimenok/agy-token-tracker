import Foundation
import SwiftUI
import Combine

public enum StatusDisplayMode: String, CaseIterable, Identifiable {
    case tokens = "Tokens"
    case cost = "Cost ($)"
    case compact = "Icon Only"

    public var id: String { rawValue }
}

public struct ComputedMetrics: Sendable {
    public var inputTokens: Int = 0
    public var cacheReadTokens: Int = 0
    public var outputTokens: Int = 0
    public var totalTokens: Int = 0
    public var totalCost: Double = 0.0
    public var cacheHitPercentage: Double = 0.0

    public init(
        inputTokens: Int = 0,
        cacheReadTokens: Int = 0,
        outputTokens: Int = 0,
        totalTokens: Int = 0,
        totalCost: Double = 0.0,
        cacheHitPercentage: Double = 0.0
    ) {
        self.inputTokens = inputTokens
        self.cacheReadTokens = cacheReadTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.cacheHitPercentage = cacheHitPercentage
    }
}

@MainActor
public final class TrackerViewModel: ObservableObject {
    @Published public var selectedPeriod: TimePeriod = .today {
        didSet {
            UserDefaults.standard.set(selectedPeriod.rawValue, forKey: "agy_selected_period")
            recomputeMetrics()
        }
    }

    @Published public var selectedSurface: AppSurface = .all {
        didSet {
            UserDefaults.standard.set(selectedSurface.rawValue, forKey: "agy_selected_surface")
            recomputeMetrics()
        }
    }

    @Published public var displayMode: StatusDisplayMode = .tokens {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: "agy_display_mode")
        }
    }

    @Published public var customBrainPath: String = "" {
        didSet {
            UserDefaults.standard.set(customBrainPath, forKey: "agy_custom_brain_path")
        }
    }

    @Published public var allSteps: [TokenStep] = []
    @Published public var allSessions: [SessionSummary] = []
    @Published public var isScanning: Bool = false
    @Published public var isPulsing: Bool = false
    @Published public var lastRefreshDate: Date = Date()
    @Published public var pricingSyncDate: Date?

    @Published public private(set) var currentMetrics = ComputedMetrics()
    @Published public private(set) var filteredSessions: [SessionSummary] = []
    @Published public private(set) var breakdownMap: [AppSurface: (tokens: Int, cost: Double, sessionsCount: Int)] = [:]

    private let unifiedScanner = UnifiedScanner.shared
    private let pricing = PricingService.shared
    private let watcher = FolderWatcher()

    public init() {
        if let savedPeriod = UserDefaults.standard.string(forKey: "agy_selected_period") ?? UserDefaults.standard.string(forKey: "agv_selected_period"),
           let period = TimePeriod(rawValue: savedPeriod) {
            self.selectedPeriod = period
        }

        if let savedSurface = UserDefaults.standard.string(forKey: "agy_selected_surface") ?? UserDefaults.standard.string(forKey: "agv_selected_surface"),
           let surface = AppSurface(rawValue: savedSurface) {
            self.selectedSurface = surface
        }

        if let savedMode = UserDefaults.standard.string(forKey: "agy_display_mode") ?? UserDefaults.standard.string(forKey: "agv_display_mode"),
           let mode = StatusDisplayMode(rawValue: savedMode) {
            self.displayMode = mode
        }

        self.customBrainPath = UserDefaults.standard.string(forKey: "agy_custom_brain_path") ?? UserDefaults.standard.string(forKey: "agv_custom_brain_path") ?? ""
        self.pricingSyncDate = pricing.lastSyncDate

        refresh()
        startWatcher()

        Task {
            await pricing.fetchRemotePricing()
            await MainActor.run {
                self.pricingSyncDate = self.pricing.lastSyncDate
                self.recomputeMetrics()
            }
        }
    }

    public func startWatcher() {
        var watchDirs: [URL] = [
            AppSurface.desktop.defaultDirectoryURL,
            AppSurface.cli.defaultDirectoryURL,
            AppSurface.ide.defaultDirectoryURL
        ]

        if !customBrainPath.isEmpty {
            watchDirs.append(URL(fileURLWithPath: (customBrainPath as NSString).expandingTildeInPath))
        }

        watcher.start(watching: watchDirs) { [weak self] in
            Task { @MainActor [weak self] in
                self?.triggerPulse()
                self?.refresh()
            }
        }
    }

    public func refresh() {
        isScanning = true
        let customPath = customBrainPath.isEmpty ? nil : customBrainPath

        Task.detached(priority: .userInitiated) { [unifiedScanner] in
            let (steps, sessions) = unifiedScanner.scanAllSurfaces(customDesktopBrainPath: customPath)
            await MainActor.run {
                self.allSteps = steps
                self.allSessions = sessions
                self.lastRefreshDate = Date()
                self.recomputeMetrics()
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

    // MARK: - Fast Precomputed Metrics

    public func recomputeMetrics() {
        let interval = selectedPeriod.dateInterval()
        let surface = selectedSurface

        var inTok = 0
        var cacheTok = 0
        var outTok = 0
        var cost = 0.0

        for step in allSteps {
            if surface != .all && step.surface != surface { continue }
            if !selectedPeriod.matches(date: step.date, interval: interval) { continue }

            inTok += step.inputTokens
            cacheTok += step.cacheReadTokens
            outTok += step.outputTokens

            let rate = pricing.rateFor(modelName: step.modelName)
            cost += rate.calculateCost(input: step.inputTokens, cacheRead: step.cacheReadTokens, output: step.outputTokens)
        }

        let total = inTok + cacheTok + outTok
        let prompt = inTok + cacheTok
        let hitPct = prompt > 0 ? (Double(cacheTok) / Double(prompt)) * 100.0 : 0.0

        self.currentMetrics = ComputedMetrics(
            inputTokens: inTok,
            cacheReadTokens: cacheTok,
            outputTokens: outTok,
            totalTokens: total,
            totalCost: cost,
            cacheHitPercentage: hitPct
        )

        self.filteredSessions = allSessions.filter { session in
            let surfaceMatch = (surface == .all || session.surface == surface)
            let periodMatch = selectedPeriod.matches(date: session.lastUpdated, interval: interval)
            return surfaceMatch && periodMatch
        }

        var bMap: [AppSurface: (tokens: Int, cost: Double, sessionsCount: Int)] = [:]
        for surf in [AppSurface.desktop, AppSurface.cli, AppSurface.ide] {
            var sTok = 0
            var sCost = 0.0
            for step in allSteps where step.surface == surf && selectedPeriod.matches(date: step.date, interval: interval) {
                sTok += step.totalTokens
                let rate = pricing.rateFor(modelName: step.modelName)
                sCost += rate.calculateCost(input: step.inputTokens, cacheRead: step.cacheReadTokens, output: step.outputTokens)
            }
            let sCount = allSessions.filter { $0.surface == surf && selectedPeriod.matches(date: $0.lastUpdated, interval: interval) }.count
            bMap[surf] = (sTok, sCost, sCount)
        }
        self.breakdownMap = bMap
    }

    public var totalInputTokens: Int { currentMetrics.inputTokens }
    public var totalCacheReadTokens: Int { currentMetrics.cacheReadTokens }
    public var totalOutputTokens: Int { currentMetrics.outputTokens }
    public var totalTokens: Int { currentMetrics.totalTokens }
    public var totalCost: Double { currentMetrics.totalCost }
    public var cacheHitPercentage: Double { currentMetrics.cacheHitPercentage }

    public func surfaceMetrics(for surface: AppSurface) -> (tokens: Int, cost: Double, sessionsCount: Int) {
        breakdownMap[surface] ?? (0, 0.0, 0)
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
