import Foundation
import SwiftUI

public final class QuotaService: @unchecked Sendable {
    public static let shared = QuotaService()

    private let cacheKey = "agy_cached_quota_json"
    private let cacheDateKey = "agy_cached_quota_timestamp"

    private let lock = NSLock()
    private var _currentSnapshot: QuotaSnapshot?

    public var currentSnapshot: QuotaSnapshot? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _currentSnapshot
        }
        set {
            lock.lock()
            _currentSnapshot = newValue
            lock.unlock()
        }
    }

    public init() {
        self._currentSnapshot = loadCachedSnapshot()
    }

    /// Discovers candidate path for `agy` CLI
    public func resolveAgyBinaryPath() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/opt/homebrew/bin/agy",
            "/usr/local/bin/agy",
            "\(home)/.local/bin/agy",
            "/usr/bin/agy",
            "/bin/agy"
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Try searching PATH
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.components(separatedBy: ":") {
                let p = (dir as NSString).appendingPathComponent("agy")
                if FileManager.default.isExecutableFile(atPath: p) {
                    return p
                }
            }
        }

        return nil
    }

    /// Asynchronously fetches live quota from `agy --print /usage --output-format json`
    public func fetchLiveQuota() async -> QuotaSnapshot? {
        guard let agyPath = resolveAgyBinaryPath() else {
            // Cannot locate agy binary; fallback to cached
            return currentSnapshot
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: agyPath)
                process.arguments = ["--print", "/usage", "--output-format", "json", "--print-timeout", "15s"]

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                    
                    // Allow up to 18 seconds for process to exit
                    let deadline = Date().addingTimeInterval(18)
                    while process.isRunning && Date() < deadline {
                        Thread.sleep(forTimeInterval: 0.1)
                    }

                    if process.isRunning {
                        process.terminate()
                        continuation.resume(returning: self.currentSnapshot)
                        return
                    }

                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    guard !data.isEmpty else {
                        continuation.resume(returning: self.currentSnapshot)
                        return
                    }

                    if let snapshot = try? self.parseQuotaJSON(data: data) {
                        self.currentSnapshot = snapshot
                        self.saveCachedSnapshot(data: data)
                        continuation.resume(returning: snapshot)
                    } else {
                        continuation.resume(returning: self.currentSnapshot)
                    }
                } catch {
                    continuation.resume(returning: self.currentSnapshot)
                }
            }
        }
    }

    // MARK: - JSON Parsing

    private struct RawAgyResponse: Decodable {
        let status: String?
        let response: String?
        let command: RawAgyCommand?
    }

    private struct RawAgyCommand: Decodable {
        let name: String?
        let data: RawAgyData?
    }

    private struct RawAgyData: Decodable {
        let description: String?
        let groups: [RawAgyGroup]?
    }

    private struct RawAgyGroup: Decodable {
        let name: String?
        let description: String?
        let buckets: [RawAgyBucket]?
    }

    private struct RawAgyBucket: Decodable {
        let id: String?
        let name: String?
        let description: String?
        let window: String?
        let remaining_fraction: Double?
        let reset_time: String?
    }

    public func parseQuotaJSON(data: Data) throws -> QuotaSnapshot {
        let decoder = JSONDecoder()
        let resp = try decoder.decode(RawAgyResponse.self, from: data)

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let standardIso = ISO8601DateFormatter()
        standardIso.formatOptions = [.withInternetDateTime]

        func parseDate(_ str: String?) -> Date? {
            guard let str = str else { return nil }
            return isoFormatter.date(from: str) ?? standardIso.date(from: str)
        }

        var groups: [QuotaGroup] = []

        if let rawGroups = resp.command?.data?.groups, !rawGroups.isEmpty {
            for rg in rawGroups {
                let gName = rg.name ?? "Models"
                var buckets: [QuotaBucket] = []

                if let rawBuckets = rg.buckets {
                    for rb in rawBuckets {
                        guard let bId = rb.id, let bWindow = rb.window else { continue }
                        let bName = rb.name ?? bWindow
                        let fraction = rb.remaining_fraction ?? 1.0
                        let resetDate = parseDate(rb.reset_time)

                        buckets.append(QuotaBucket(
                            id: bId,
                            name: bName,
                            description: rb.description,
                            window: bWindow,
                            remainingFraction: fraction,
                            resetTime: resetDate,
                            rawResetTime: rb.reset_time
                        ))
                    }
                }

                groups.append(QuotaGroup(
                    name: gName,
                    description: rg.description,
                    buckets: buckets
                ))
            }
        } else if let responseText = resp.response, !responseText.isEmpty {
            // Fallback parsing from response string lines:
            // "Gemini Models\tWeekly Limit Remaining\t93%\t2026-10-22T07:27:59Z"
            var groupDict: [String: [QuotaBucket]] = [:]
            for line in responseText.components(separatedBy: "\n") {
                let parts = line.components(separatedBy: "\t")
                guard parts.count >= 3 else { continue }
                let groupName = parts[0].trimmingCharacters(in: .whitespaces)
                let bucketName = parts[1].trimmingCharacters(in: .whitespaces)
                let pctStr = parts[2].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "")
                let resetStr = parts.count >= 4 ? parts[3].trimmingCharacters(in: .whitespaces) : nil

                let pct = (Double(pctStr) ?? 100.0) / 100.0
                let isWeekly = bucketName.lowercased().contains("weekly")
                let window = isWeekly ? "weekly" : "5h"
                let bucketId = "\(groupName.lowercased().prefix(3))-\(window)"

                let bucket = QuotaBucket(
                    id: bucketId,
                    name: bucketName,
                    window: window,
                    remainingFraction: pct,
                    resetTime: parseDate(resetStr),
                    rawResetTime: resetStr
                )

                if groupDict[groupName] == nil {
                    groupDict[groupName] = []
                }
                groupDict[groupName]?.append(bucket)
            }

            for (name, bList) in groupDict {
                groups.append(QuotaGroup(name: name, buckets: bList))
            }
        }

        let desc = resp.command?.data?.description
        return QuotaSnapshot(fetchedAt: Date(), description: desc, groups: groups)
    }

    // MARK: - Caching

    private func saveCachedSnapshot(data: Data) {
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheDateKey)
    }

    private func loadCachedSnapshot() -> QuotaSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return nil
        }
        return try? parseQuotaJSON(data: data)
    }
}
