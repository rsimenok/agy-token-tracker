import Foundation

public final class HistoryStore: @unchecked Sendable {
    public static let shared = HistoryStore()

    private let fileURL: URL
    private let lock = NSLock()
    private var data: MonthlyHistoryData

    public init(customFileURL: URL? = nil) {
        if let url = customFileURL {
            self.fileURL = url
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("AGYTokenTracker", isDirectory: true)
            self.fileURL = appSupport.appendingPathComponent("monthly_history.json")
        }
        self.data = MonthlyHistoryData()
        load()
    }

    public var currentData: MonthlyHistoryData {
        lock.lock()
        defer { lock.unlock() }
        return data
    }

    public var availableYears: [Int] {
        lock.lock()
        defer { lock.unlock() }
        let years = Set(data.records.values.map(\.year))
        if years.isEmpty {
            return [Calendar.current.component(.year, from: Date())]
        }
        return years.sorted(by: >)
    }

    public func records(for year: Int) -> [MonthlyRecord] {
        lock.lock()
        defer { lock.unlock() }
        return data.records.values
            .filter { $0.year == year }
            .sorted { $0.month > $1.month }
    }

    public func annualMetrics(year: Int, surface: AppSurface = .all) -> (tokens: Int, cost: Double, sessions: Int, activeMonths: Int, cacheHitRatio: Double) {
        let yearRecords = records(for: year)
        var totalTokens = 0
        var totalCost = 0.0
        var totalSessions = 0
        var activeMonths = 0
        var totalInput = 0
        var totalCache = 0

        for record in yearRecords {
            let m = record.metrics(for: surface)
            if m.tokens > 0 || m.cost > 0 {
                activeMonths += 1
                totalTokens += m.tokens
                totalCost += m.cost
                totalSessions += m.sessions
            }
            if surface == .all {
                totalInput += record.inputTokens
                totalCache += record.cacheReadTokens
            }
        }

        let prompt = totalInput + totalCache
        let hitRatio = prompt > 0 ? (Double(totalCache) / Double(prompt)) : 0.0

        return (totalTokens, totalCost, totalSessions, activeMonths, hitRatio)
    }

    public func load() {
        lock.lock()
        defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let fileData = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.data = try decoder.decode(MonthlyHistoryData.self, from: fileData)
        } catch {
            print("Failed to load history from \(fileURL.path): \(error)")
        }
    }

    public func save() {
        lock.lock()
        let dataToSave = self.data
        lock.unlock()

        let folder = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let encoded = try encoder.encode(dataToSave)
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save history to \(fileURL.path): \(error)")
        }
    }

    /// Aggregates scanned steps and merges with existing history records.
    @discardableResult
    public func aggregateAndSave(steps: [TokenStep]) -> MonthlyHistoryData {
        let calendar = Calendar.current

        var stepsByMonth: [String: (year: Int, month: Int, steps: [TokenStep])] = [:]
        for step in steps {
            let comps = calendar.dateComponents([.year, .month], from: step.date)
            guard let y = comps.year, let m = comps.month else { continue }
            let key = String(format: "%04d-%02d", y, m)
            if stepsByMonth[key] == nil {
                stepsByMonth[key] = (y, m, [])
            }
            stepsByMonth[key]?.steps.append(step)
        }

        lock.lock()
        for (key, entry) in stepsByMonth {
            let monthSteps = entry.steps
            let y = entry.year
            let m = entry.month

            var inTok = 0
            var cacheTok = 0
            var outTok = 0
            var cost = 0.0
            var sessionIds = Set<String>()

            var modelMap: [String: (name: String, tokens: Int, cost: Double)] = [:]
            var surfaceMap: [String: (tokens: Int, cost: Double, sessionIds: Set<String>)] = [:]

            for step in monthSteps {
                inTok += step.inputTokens
                cacheTok += step.cacheReadTokens
                outTok += step.outputTokens
                cost += step.cost
                sessionIds.insert(step.sessionId)

                let modelId = step.canonicalModelId
                let displayName = ModelFormatter.displayName(for: step.modelName)
                if modelMap[modelId] == nil {
                    modelMap[modelId] = (displayName, 0, 0.0)
                }
                modelMap[modelId]!.tokens += step.totalTokens
                modelMap[modelId]!.cost += step.cost

                let surfKey = step.surface.rawValue
                if surfaceMap[surfKey] == nil {
                    surfaceMap[surfKey] = (0, 0.0, Set<String>())
                }
                surfaceMap[surfKey]!.tokens += step.totalTokens
                surfaceMap[surfKey]!.cost += step.cost
                surfaceMap[surfKey]!.sessionIds.insert(step.sessionId)
            }

            var modelBreakdown: [String: ModelMonthlyStat] = [:]
            for (id, val) in modelMap {
                modelBreakdown[id] = ModelMonthlyStat(
                    displayName: val.name,
                    canonicalModelId: id,
                    tokens: val.tokens,
                    cost: val.cost
                )
            }

            var surfaceBreakdown: [String: SurfaceMonthlyStat] = [:]
            for (surfKey, val) in surfaceMap {
                surfaceBreakdown[surfKey] = SurfaceMonthlyStat(
                    tokens: val.tokens,
                    cost: val.cost,
                    sessions: val.sessionIds.count
                )
            }

            let record = MonthlyRecord(
                year: y,
                month: m,
                inputTokens: inTok,
                cacheReadTokens: cacheTok,
                outputTokens: outTok,
                totalTokens: inTok + cacheTok + outTok,
                totalCost: cost,
                sessionCount: sessionIds.count,
                stepCount: monthSteps.count,
                modelBreakdown: modelBreakdown,
                surfaceBreakdown: surfaceBreakdown,
                lastUpdated: Date()
            )
            data.records[key] = record
        }
        data.lastScanDate = Date()
        let result = data
        lock.unlock()

        save()
        return result
    }
}
