import Foundation
import SQLite3

public final class SQLiteConversationScanner: @unchecked Sendable {
    public static let shared = SQLiteConversationScanner()

    private let lock = NSLock()
    private struct CacheEntry {
        let mtime: Date
        let steps: [TokenStep]
        let session: SessionSummary?
    }
    private var dbCache: [URL: CacheEntry] = [:]

    public init() {}

    public func scanDirectory(directoryURL: URL, surface: AppSurface) -> (steps: [TokenStep], sessions: [SessionSummary]) {
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            return ([], [])
        }

        var allSteps: [TokenStep] = []
        var sessionSummaries: [SessionSummary] = []

        let conversationsDir = directoryURL.appendingPathComponent("conversations", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: conversationsDir, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return ([], [])
        }

        for fileURL in files where fileURL.pathExtension == "db" {
            let fileMtime = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()

            lock.lock()
            if let cached = dbCache[fileURL], cached.mtime == fileMtime {
                lock.unlock()
                if !cached.steps.isEmpty, let session = cached.session {
                    allSteps.append(contentsOf: cached.steps)
                    sessionSummaries.append(session)
                }
                continue
            }
            lock.unlock()

            let sessionId = fileURL.deletingPathExtension().lastPathComponent
            let (steps, session) = parseDatabase(fileURL: fileURL, sessionId: sessionId, surface: surface)

            lock.lock()
            dbCache[fileURL] = CacheEntry(mtime: fileMtime, steps: steps, session: session)
            lock.unlock()

            if !steps.isEmpty, let session = session {
                allSteps.append(contentsOf: steps)
                sessionSummaries.append(session)
            }
        }

        sessionSummaries.sort { $0.lastUpdated > $1.lastUpdated }
        allSteps.sort { $0.date > $1.date }

        return (allSteps, sessionSummaries)
    }

    private func parseDatabase(fileURL: URL, sessionId: String, surface: AppSurface) -> (steps: [TokenStep], session: SessionSummary?) {
        var db: OpaquePointer?
        if sqlite3_open_v2(fileURL.path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            sqlite3_close(db)
            return ([], nil)
        }
        defer { sqlite3_close(db) }

        let fileMtime = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
        let sessionDate = readSessionDate(db: db) ?? fileMtime

        let query = "SELECT idx, data FROM gen_metadata ORDER BY idx"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) != SQLITE_OK {
            return ([], nil)
        }
        defer { sqlite3_finalize(stmt) }

        var steps: [TokenStep] = []
        var detectedModel: String? = nil
        var seenResponseIds = Set<String>()

        while sqlite3_step(stmt) == SQLITE_ROW {
            let idx = Int(sqlite3_column_int64(stmt, 0))
            guard let blobPtr = sqlite3_column_blob(stmt, 1) else { continue }
            let blobBytes = sqlite3_column_bytes(stmt, 1)
            let data = Data(bytes: blobPtr, count: Int(blobBytes))

            if let parsed = parseGenMetadataBlob(data: data) {
                if let respId = parsed.responseId {
                    if seenResponseIds.contains(respId) { continue }
                    seenResponseIds.insert(respId)
                }

                if let m = parsed.modelName, detectedModel == nil {
                    detectedModel = m
                }

                let step = TokenStep(
                    stepIndex: idx,
                    sessionId: sessionId,
                    date: sessionDate,
                    inputTokens: parsed.inputTokens,
                    cacheReadTokens: parsed.cacheReadTokens,
                    outputTokens: parsed.outputTokens,
                    modelName: parsed.modelName,
                    surface: surface
                )
                steps.append(step)
            }
        }

        guard !steps.isEmpty else { return ([], nil) }

        let totalInput = steps.reduce(0) { $0 + $1.inputTokens }
        let totalCache = steps.reduce(0) { $0 + $1.cacheReadTokens }
        let totalOutput = steps.reduce(0) { $0 + $1.outputTokens }

        let rate = PricingService.shared.rateFor(modelName: detectedModel)
        let cost = rate.calculateCost(input: totalInput, cacheRead: totalCache, output: totalOutput)

        let summary = SessionSummary(
            id: sessionId,
            lastUpdated: sessionDate,
            stepCount: steps.count,
            inputTokens: totalInput,
            cacheReadTokens: totalCache,
            outputTokens: totalOutput,
            estimatedCost: cost,
            modelName: detectedModel,
            surface: surface
        )

        return (steps, summary)
    }

    private func readSessionDate(db: OpaquePointer?) -> Date? {
        let query = "SELECT data FROM trajectory_metadata_blob LIMIT 1"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) != SQLITE_OK {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            guard let blobPtr = sqlite3_column_blob(stmt, 0) else { return nil }
            let count = Int(sqlite3_column_bytes(stmt, 0))
            let data = Data(bytes: blobPtr, count: count)
            let fields = parseProtobufFields(data)
            if let dateData = fields[2] as? Data {
                let dateFields = parseProtobufFields(dateData)
                if let sec = dateFields[1] as? UInt64 {
                    return Date(timeIntervalSince1970: TimeInterval(sec))
                }
            }
        }
        return nil
    }

    private struct ParsedGenRow {
        let modelName: String?
        let inputTokens: Int
        let cacheReadTokens: Int
        let outputTokens: Int
        let responseId: String?
    }

    private func parseGenMetadataBlob(data: Data) -> ParsedGenRow? {
        let top = parseProtobufFields(data)
        guard let chatModelData = top[1] as? Data else { return nil }
        let chatModel = parseProtobufFields(chatModelData)

        var modelName: String? = nil
        if let modelData = chatModel[19] as? Data, let str = String(data: modelData, encoding: .utf8), !str.isEmpty {
            modelName = str
        }

        guard let usageData = chatModel[4] as? Data else { return nil }
        let usage = parseProtobufFields(usageData)

        let input = Int(usage[2] as? UInt64 ?? 0)
        let cache = Int(usage[5] as? UInt64 ?? 0)
        let output = Int(usage[9] as? UInt64 ?? 0)
        let thinking = Int(usage[10] as? UInt64 ?? 0)

        guard (input + cache + output + thinking) > 0 else { return nil }

        var respId: String? = nil
        if let respData = usage[11] as? Data {
            respId = String(data: respData, encoding: .utf8)
        }

        return ParsedGenRow(
            modelName: modelName,
            inputTokens: input,
            cacheReadTokens: cache,
            outputTokens: output + thinking,
            responseId: respId
        )
    }

    // Lightweight Protobuf wire parser
    private func parseProtobufFields(_ data: Data) -> [Int: Any] {
        var fields: [Int: Any] = [:]
        var pos = 0
        let count = data.count

        while pos < count {
            guard let (tag, newPos) = decodeVarint(data, from: pos) else { break }
            pos = newPos
            let fieldNum = Int(tag >> 3)
            let wireType = Int(tag & 7)

            if wireType == 0 { // Varint
                guard let (val, nPos) = decodeVarint(data, from: pos) else { break }
                pos = nPos
                fields[fieldNum] = val
            } else if wireType == 2 { // Length-delimited
                guard let (len, nPos) = decodeVarint(data, from: pos) else { break }
                pos = nPos
                let length = Int(len)
                guard pos + length <= count else { break }
                let slice = data.subdata(in: pos..<(pos + length))
                pos += length
                fields[fieldNum] = slice
            } else if wireType == 1 { // 64-bit
                pos += 8
            } else if wireType == 5 { // 32-bit
                pos += 4
            } else {
                break
            }
        }

        return fields
    }

    private func decodeVarint(_ data: Data, from start: Int) -> (UInt64, Int)? {
        var res: UInt64 = 0
        var shift: UInt64 = 0
        var pos = start
        let count = data.count

        while pos < count {
            let b = data[pos]
            pos += 1
            res |= UInt64(b & 0x7f) << shift
            if (b & 0x80) == 0 {
                return (res, pos)
            }
            shift += 7
            if shift >= 64 { return nil }
        }
        return nil
    }
}
