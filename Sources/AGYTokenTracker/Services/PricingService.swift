import Foundation

public final class PricingService: @unchecked Sendable {
    public static let shared = PricingService()

    private let litellmURL = URL(string: "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json")!
    private let cacheURL: URL

    private var rates: [String: ModelRate] = [:]
    private var resolutionCache: [String: ModelRate] = [:]
    private let lock = NSLock()

    public private(set) var lastSyncDate: Date?

    private init() {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let appCacheDir = cachesDir.appendingPathComponent("AGYTokenTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: appCacheDir, withIntermediateDirectories: true)
        self.cacheURL = appCacheDir.appendingPathComponent("pricing-litellm.json")

        loadBuiltInDefaults()
        loadLocalCache()
    }

    private func loadBuiltInDefaults() {
        // Official rates per 1M tokens ($/1M)
        let defaults: [String: ModelRate] = [
            // Gemini Flash family (Standard Antigravity default models)
            "gemini-3.8-flash": ModelRate(inputPerMillion: 0.75, cacheReadPerMillion: 0.1875, outputPerMillion: 3.00),
            "gemini-3-flash": ModelRate(inputPerMillion: 0.15, cacheReadPerMillion: 0.0375, outputPerMillion: 0.60),
            "gemini-2.5-flash": ModelRate(inputPerMillion: 0.15, cacheReadPerMillion: 0.0375, outputPerMillion: 0.60),
            "gemini-2.0-flash": ModelRate(inputPerMillion: 0.10, cacheReadPerMillion: 0.0250, outputPerMillion: 0.40),
            "gemini-1.5-flash": ModelRate(inputPerMillion: 0.075, cacheReadPerMillion: 0.01875, outputPerMillion: 0.30),
            "gemini-flash": ModelRate(inputPerMillion: 0.15, cacheReadPerMillion: 0.0375, outputPerMillion: 0.60),

            // Gemini Pro family
            "gemini-2.5-pro": ModelRate(inputPerMillion: 1.25, cacheReadPerMillion: 0.3125, outputPerMillion: 5.00),
            "gemini-1.5-pro": ModelRate(inputPerMillion: 1.25, cacheReadPerMillion: 0.3125, outputPerMillion: 5.00),
            "gemini-pro": ModelRate(inputPerMillion: 1.25, cacheReadPerMillion: 0.3125, outputPerMillion: 5.00),

            // Claude family (if used via Antigravity)
            "claude-3-7-sonnet": ModelRate(inputPerMillion: 3.00, cacheReadPerMillion: 0.30, outputPerMillion: 15.00),
            "claude-3-5-sonnet": ModelRate(inputPerMillion: 3.00, cacheReadPerMillion: 0.30, outputPerMillion: 15.00),
            "claude-3-5-haiku": ModelRate(inputPerMillion: 0.80, cacheReadPerMillion: 0.08, outputPerMillion: 4.00),
            "claude-3-opus": ModelRate(inputPerMillion: 15.00, cacheReadPerMillion: 1.50, outputPerMillion: 75.00),
        ]

        lock.lock()
        for (key, val) in defaults {
            rates[key] = val
        }
        lock.unlock()
    }

    private func loadLocalCache() {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        parseAndApply(data: data)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: cacheURL.path),
           let modDate = attrs[.modificationDate] as? Date {
            self.lastSyncDate = modDate
        }
    }

    public func rateFor(modelName: String?) -> ModelRate {
        lock.lock()
        defer { lock.unlock() }

        guard let rawName = modelName?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !rawName.isEmpty else {
            return rates["gemini-2.5-flash"] ?? ModelRate(inputPerMillion: 0.15, cacheReadPerMillion: 0.0375, outputPerMillion: 0.60)
        }

        // 1. Fast lookup from memoized resolution cache
        if let cached = resolutionCache[rawName] {
            return cached
        }

        var cleaned = rawName
        cleaned = cleaned.replacingOccurrences(of: "\"", with: "")
        cleaned = cleaned.replacingOccurrences(of: "`", with: "")
        if let parenIdx = cleaned.firstIndex(of: "(") {
            cleaned = String(cleaned[..<parenIdx])
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        let hyphenated = cleaned.replacingOccurrences(of: " ", with: "-")

        if let cached = resolutionCache[cleaned] ?? resolutionCache[hyphenated] {
            resolutionCache[rawName] = cached
            return cached
        }

        // 2. Exact match in rates dictionary
        if let direct = rates[rawName] ?? rates[cleaned] ?? rates[hyphenated] {
            resolutionCache[rawName] = direct
            resolutionCache[cleaned] = direct
            resolutionCache[hyphenated] = direct
            return direct
        }

        // 3. Known model family pattern matching (instant, no dictionary linear scan)
        let resolved: ModelRate
        if hyphenated.contains("3.8-flash") || hyphenated.contains("3.8flash") {
            resolved = rates["gemini-3.8-flash"] ?? ModelRate(inputPerMillion: 0.75, cacheReadPerMillion: 0.1875, outputPerMillion: 3.00)
        } else if hyphenated.contains("3-flash") || hyphenated.contains("3.0-flash") {
            resolved = rates["gemini-3-flash"] ?? ModelRate(inputPerMillion: 0.15, cacheReadPerMillion: 0.0375, outputPerMillion: 0.60)
        } else if hyphenated.contains("2.5-flash") {
            resolved = rates["gemini-2.5-flash"] ?? ModelRate(inputPerMillion: 0.15, cacheReadPerMillion: 0.0375, outputPerMillion: 0.60)
        } else if hyphenated.contains("2.0-flash") || hyphenated.contains("2-flash") {
            resolved = rates["gemini-2.0-flash"] ?? ModelRate(inputPerMillion: 0.10, cacheReadPerMillion: 0.0250, outputPerMillion: 0.40)
        } else if hyphenated.contains("1.5-flash") {
            resolved = rates["gemini-1.5-flash"] ?? ModelRate(inputPerMillion: 0.075, cacheReadPerMillion: 0.01875, outputPerMillion: 0.30)
        } else if hyphenated.contains("flash") {
            resolved = rates["gemini-2.5-flash"] ?? ModelRate(inputPerMillion: 0.15, cacheReadPerMillion: 0.0375, outputPerMillion: 0.60)
        } else if hyphenated.contains("2.5-pro") {
            resolved = rates["gemini-2.5-pro"] ?? ModelRate(inputPerMillion: 1.25, cacheReadPerMillion: 0.3125, outputPerMillion: 5.00)
        } else if hyphenated.contains("1.5-pro") {
            resolved = rates["gemini-1.5-pro"] ?? ModelRate(inputPerMillion: 1.25, cacheReadPerMillion: 0.3125, outputPerMillion: 5.00)
        } else if hyphenated.contains("pro") {
            resolved = rates["gemini-2.5-pro"] ?? ModelRate(inputPerMillion: 1.25, cacheReadPerMillion: 0.3125, outputPerMillion: 5.00)
        } else if hyphenated.contains("3-7-sonnet") || hyphenated.contains("3.7-sonnet") {
            resolved = rates["claude-3-7-sonnet"] ?? ModelRate(inputPerMillion: 3.00, cacheReadPerMillion: 0.30, outputPerMillion: 15.00)
        } else if hyphenated.contains("3-5-sonnet") || hyphenated.contains("3.5-sonnet") {
            resolved = rates["claude-3-5-sonnet"] ?? ModelRate(inputPerMillion: 3.00, cacheReadPerMillion: 0.30, outputPerMillion: 15.00)
        } else if hyphenated.contains("haiku") {
            resolved = rates["claude-3-5-haiku"] ?? ModelRate(inputPerMillion: 0.80, cacheReadPerMillion: 0.08, outputPerMillion: 4.00)
        } else if hyphenated.contains("opus") {
            resolved = rates["claude-3-opus"] ?? ModelRate(inputPerMillion: 15.00, cacheReadPerMillion: 1.50, outputPerMillion: 75.00)
        } else {
            resolved = rates["gemini-2.5-flash"] ?? ModelRate(inputPerMillion: 0.15, cacheReadPerMillion: 0.0375, outputPerMillion: 0.60)
        }

        resolutionCache[rawName] = resolved
        resolutionCache[cleaned] = resolved
        resolutionCache[hyphenated] = resolved
        return resolved
    }

    public func fetchRemotePricing() async {
        do {
            let (data, response) = try await URLSession.shared.data(from: litellmURL)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return
            }

            try? data.write(to: cacheURL, options: .atomic)
            parseAndApply(data: data)
            self.lastSyncDate = Date()
        } catch {
            // Keep using cached or default rates if offline
        }
    }

    private func parseAndApply(data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            return
        }

        lock.lock()
        defer { lock.unlock() }

        for (modelKey, props) in json {
            let inputCost = (props["input_cost_per_token"] as? Double) ?? 0.0
            let cacheCost = (props["cache_read_input_token_cost"] as? Double) ?? (inputCost * 0.25)
            let outputCost = (props["output_cost_per_token"] as? Double) ?? 0.0

            if inputCost > 0 || outputCost > 0 {
                rates[modelKey.lowercased()] = ModelRate(
                    inputPerMillion: inputCost * 1_000_000.0,
                    cacheReadPerMillion: cacheCost * 1_000_000.0,
                    outputPerMillion: outputCost * 1_000_000.0
                )
            }
        }
        resolutionCache.removeAll()
    }
}
