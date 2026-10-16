import Foundation
import SwiftUI
import AppKit
import Combine

public enum StatusDisplayMode: String, CaseIterable, Identifiable {
    case tokens = "Tokens"
    case cost = "Cost ($)"
    case compact = "Icon Only"

    public var id: String { rawValue }
}

public enum AppViewTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case models = "Models"
    case sessions = "Sessions"

    public var id: String { rawValue }
}

public typealias DashboardTab = AppViewTab

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

    @Published public var currentView: AppViewTab = .overview
    public var selectedTab: DashboardTab {
        get { currentView }
        set { currentView = newValue }
    }
    @Published public var selectedModelFilter: String? = nil {
        didSet {
            recomputeFilteredSessions()
        }
    }

    @Published public var allSteps: [TokenStep] = []
    @Published public var allSessions: [SessionSummary] = []
    @Published public var isScanning: Bool = false
    @Published public var isPulsing: Bool = false
    @Published public var lastRefreshDate: Date = Date()
    @Published public var pricingSyncDate: Date?
    @Published public var quotaSnapshot: QuotaSnapshot?
    @Published public var isFetchingQuota: Bool = false
    @Published public var isShowingSettings: Bool = false

    @Published public private(set) var currentMetrics = ComputedMetrics()
    @Published public private(set) var filteredSessions: [SessionSummary] = []
    @Published public private(set) var modelUsages: [ModelUsage] = []
    @Published public private(set) var breakdownMap: [AppSurface: (tokens: Int, cost: Double, sessionsCount: Int)] = [:]

    private let unifiedScanner = UnifiedScanner.shared
    private let pricing = PricingService.shared
    private let watcher = FolderWatcher()
    private let quotaService = QuotaService.shared

    private var cancellables = Set<AnyCancellable>()
    private var lastComputedDayStart: Date = Calendar.current.startOfDay(for: Date())
    private var lastQuotaFetchDate: Date?
    private let quotaRefreshCooldown: TimeInterval = 60.0
    private var lastWindowOpenRefreshDate: Date = .distantPast
    private var pendingRefresh: Bool = false

    public init(startBackgroundServices: Bool = true) {
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
        self.quotaSnapshot = quotaService.currentSnapshot

        guard startBackgroundServices else { return }

        refresh(forceQuota: true)
        startWatcher()
        setupLifecycleObservers()

        Task {
            await pricing.fetchRemotePricing()
            await MainActor.run {
                self.pricingSyncDate = self.pricing.lastSyncDate
                self.recomputeMetrics()
            }
        }
    }

    private func setupLifecycleObservers() {
        let dayChanged = NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .map { _ in () }
        let clockChanged = NotificationCenter.default.publisher(for: .NSSystemClockDidChange)
            .map { _ in () }
        let timeZoneChanged = NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)
            .map { _ in () }
        let systemWoke = NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .map { _ in () }

        Publishers.Merge4(dayChanged, clockChanged, timeZoneChanged, systemWoke)
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self = self else { return }
                self.recomputeMetrics()
                self.refresh()
            }
            .store(in: &cancellables)

        // Periodic 60-second check to ensure menu bar metrics roll over at midnight even while idle
        Timer.publish(every: 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                guard let self = self else { return }
                if !Calendar.current.isDate(now, inSameDayAs: self.lastComputedDayStart) {
                    self.recomputeMetrics(now: now)
                    self.refresh()
                }
            }
            .store(in: &cancellables)
    }

    /// Triggered when the MenuBarExtra popup window opens or becomes key.
    public func handleWindowOpened() {
        let now = Date()
        if !Calendar.current.isDate(now, inSameDayAs: lastComputedDayStart) {
            recomputeMetrics(now: now)
        }
        guard now.timeIntervalSince(lastWindowOpenRefreshDate) >= 1.5 else { return }
        lastWindowOpenRefreshDate = now
        refresh()
    }

    public func startWatcher() {
        var watchDirs: [URL] = [
            AppSurface.desktop.defaultDirectoryURL.appendingPathComponent("brain", isDirectory: true),
            AppSurface.cli.defaultDirectoryURL.appendingPathComponent("brain", isDirectory: true),
            AppSurface.cli.defaultDirectoryURL.appendingPathComponent("conversations", isDirectory: true),
            AppSurface.ide.defaultDirectoryURL.appendingPathComponent("brain", isDirectory: true),
            AppSurface.ide.defaultDirectoryURL.appendingPathComponent("conversations", isDirectory: true)
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

    public func refresh(forceQuota: Bool = false) {
        let now = Date()
        if !Calendar.current.isDate(now, inSameDayAs: lastComputedDayStart) {
            recomputeMetrics(now: now)
        }

        refreshQuota(force: forceQuota)

        guard !isScanning else {
            pendingRefresh = true
            return
        }
        isScanning = true
        pendingRefresh = false
        let customPath = customBrainPath.isEmpty ? nil : customBrainPath

        Task.detached(priority: .userInitiated) { [unifiedScanner] in
            let (steps, sessions) = unifiedScanner.scanAllSurfaces(customDesktopBrainPath: customPath)
            await MainActor.run {
                self.allSteps = steps
                self.allSessions = sessions
                self.lastRefreshDate = Date()
                self.recomputeMetrics()
                self.isScanning = false
                if self.pendingRefresh {
                    self.pendingRefresh = false
                    self.refresh()
                }
            }
        }
    }

    public func refreshQuota(force: Bool = false) {
        guard !isFetchingQuota else { return }
        let now = Date()
        if !force, let lastFetch = lastQuotaFetchDate, now.timeIntervalSince(lastFetch) < quotaRefreshCooldown {
            return
        }
        isFetchingQuota = true
        lastQuotaFetchDate = now

        Task { [weak self] in
            guard let self = self else { return }
            let snapshot = await self.quotaService.fetchLiveQuota()
            await MainActor.run {
                self.quotaSnapshot = snapshot
                self.isFetchingQuota = false
                self.recomputeMetrics()
            }
        }
    }

    private func triggerPulse() {
        isPulsing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.isPulsing = false
        }
    }

    // MARK: - Fast Precomputed Metrics (Single Pass, Zero Blocking)

    public func recomputeMetrics(now: Date = Date(), calendar: Calendar = .current) {
        lastComputedDayStart = calendar.startOfDay(for: now)
        let interval = selectedPeriod.dateInterval(now: now, calendar: calendar)
        let surface = selectedSurface

        var inTok = 0
        var cacheTok = 0
        var outTok = 0
        var cost = 0.0

        var desktopTok = 0
        var desktopCost = 0.0
        var cliTok = 0
        var cliCost = 0.0
        var ideTok = 0
        var ideCost = 0.0

        struct ModelAccumulator {
            let displayName: String
            let provider: String
            let color: Color
            let rate: ModelRate
            var inputTokens: Int = 0
            var cacheReadTokens: Int = 0
            var outputTokens: Int = 0
            var cost: Double = 0.0
            var stepCount: Int = 0
            var sessionIds = Set<String>()
        }

        var modelMap: [String: ModelAccumulator] = [:]

        // Single pass over allSteps for metrics, model breakdown, and surface breakdown
        for step in allSteps {
            guard selectedPeriod.matches(date: step.date, interval: interval) else { continue }

            // Surface breakdown counters
            switch step.surface {
            case .desktop:
                desktopTok += step.totalTokens
                desktopCost += step.cost
            case .cli:
                cliTok += step.totalTokens
                cliCost += step.cost
            case .ide:
                ideTok += step.totalTokens
                ideCost += step.cost
            case .all:
                break
            }

            // Surface filter for main cards
            guard surface == .all || step.surface == surface else { continue }

            inTok += step.inputTokens
            cacheTok += step.cacheReadTokens
            outTok += step.outputTokens
            cost += step.cost

            let canonicalId = step.canonicalModelId
            if modelMap[canonicalId] == nil {
                let displayName = ModelFormatter.displayName(for: step.modelName)
                let color = ModelFormatter.color(for: displayName)
                let provider = ModelFormatter.provider(for: displayName)
                let rate = pricing.rateFor(modelName: step.modelName)
                modelMap[canonicalId] = ModelAccumulator(
                    displayName: displayName,
                    provider: provider,
                    color: color,
                    rate: rate
                )
            }
            modelMap[canonicalId]!.inputTokens += step.inputTokens
            modelMap[canonicalId]!.cacheReadTokens += step.cacheReadTokens
            modelMap[canonicalId]!.outputTokens += step.outputTokens
            modelMap[canonicalId]!.cost += step.cost
            modelMap[canonicalId]!.stepCount += 1
            modelMap[canonicalId]!.sessionIds.insert(step.sessionId)
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

        var usages: [ModelUsage] = []
        for (id, acc) in modelMap {
            let mTotal = acc.inputTokens + acc.cacheReadTokens + acc.outputTokens
            let pct = total > 0 ? (Double(mTotal) / Double(total)) * 100.0 : 0.0
            let mPrompt = acc.inputTokens + acc.cacheReadTokens
            let mHitPct = mPrompt > 0 ? (Double(acc.cacheReadTokens) / Double(mPrompt)) * 100.0 : 0.0

            let group = quotaSnapshot?.group(for: acc.displayName)
            usages.append(ModelUsage(
                id: id,
                displayName: acc.displayName,
                provider: acc.provider,
                inputTokens: acc.inputTokens,
                cacheReadTokens: acc.cacheReadTokens,
                outputTokens: acc.outputTokens,
                totalTokens: mTotal,
                estimatedCost: acc.cost,
                stepCount: acc.stepCount,
                sessionCount: acc.sessionIds.count,
                percentageOfTotal: pct,
                cacheHitPercentage: mHitPct,
                rate: acc.rate,
                color: acc.color,
                quotaGroup: group
            ))
        }
        usages.sort { ($0.estimatedCost, $0.totalTokens) > ($1.estimatedCost, $1.totalTokens) }
        self.modelUsages = usages

        // Single pass over allSessions for filtering and session counts
        var desktopSessions = 0
        var cliSessions = 0
        var ideSessions = 0
        var filtered: [SessionSummary] = []

        for session in allSessions {
            guard selectedPeriod.matches(date: session.lastUpdated, interval: interval) else { continue }
            switch session.surface {
            case .desktop: desktopSessions += 1
            case .cli: cliSessions += 1
            case .ide: ideSessions += 1
            case .all: break
            }

            guard surface == .all || session.surface == surface else { continue }
            if let modelFilter = selectedModelFilter {
                let sessionModelId = ModelFormatter.canonicalId(for: session.modelName)
                guard sessionModelId == modelFilter else { continue }
            }
            filtered.append(session)
        }
        self.filteredSessions = filtered

        self.breakdownMap = [
            .desktop: (desktopTok, desktopCost, desktopSessions),
            .cli: (cliTok, cliCost, cliSessions),
            .ide: (ideTok, ideCost, ideSessions)
        ]
    }

    public func recomputeFilteredSessions(now: Date = Date(), calendar: Calendar = .current) {
        if !calendar.isDate(now, inSameDayAs: lastComputedDayStart) {
            recomputeMetrics(now: now, calendar: calendar)
            return
        }

        let interval = selectedPeriod.dateInterval(now: now, calendar: calendar)
        let surface = selectedSurface

        self.filteredSessions = allSessions.filter { session in
            let surfaceMatch = (surface == .all || session.surface == surface)
            let periodMatch = selectedPeriod.matches(date: session.lastUpdated, interval: interval)
            guard surfaceMatch && periodMatch else { return false }

            if let modelFilter = selectedModelFilter {
                let sessionModelId = ModelFormatter.canonicalId(for: session.modelName)
                return sessionModelId == modelFilter
            }
            return true
        }
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
            return Self.formatCompact(totalTokens)
        case .cost:
            return Self.formatCurrency(totalCost)
        case .compact:
            return ""
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
