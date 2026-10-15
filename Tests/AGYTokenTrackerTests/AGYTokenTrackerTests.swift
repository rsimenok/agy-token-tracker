import Testing
import Foundation
import SQLite3
@testable import AGYTokenTracker

@Suite("AGY Token Tracker Tests")
struct AGYTokenTrackerTests {

    @Test("TimePeriod matching logic")
    func testTimePeriodMatching() {
        let now = Date()
        #expect(TimePeriod.today.matches(date: now))
        #expect(TimePeriod.thisWeek.matches(date: now))
        #expect(TimePeriod.thisMonth.matches(date: now))
        #expect(TimePeriod.allTime.matches(date: now))

        let calendar = Calendar.current
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now) {
            #expect(TimePeriod.yesterday.matches(date: yesterday))
            #expect(!TimePeriod.today.matches(date: yesterday))
        }
    }

    @Test("ModelRate cost calculations")
    func testCostCalculation() {
        // Flash rate: $0.15 in, $0.0375 cache, $0.60 out per 1M
        let rate = ModelRate(inputPerMillion: 0.15, cacheReadPerMillion: 0.0375, outputPerMillion: 0.60)

        // 1,000,000 input tokens = $0.15
        let costIn = rate.calculateCost(input: 1_000_000, cacheRead: 0, output: 0)
        #expect(abs(costIn - 0.15) < 0.0001)

        // 1,000,000 cache read tokens = $0.0375
        let costCache = rate.calculateCost(input: 0, cacheRead: 1_000_000, output: 0)
        #expect(abs(costCache - 0.0375) < 0.0001)

        // 1,000,000 output tokens = $0.60
        let costOut = rate.calculateCost(input: 0, cacheRead: 0, output: 1_000_000)
        #expect(abs(costOut - 0.60) < 0.0001)
    }

    @Test("PricingService model resolution")
    func testPricingResolution() {
        let pricing = PricingService.shared

        let flashRate = pricing.rateFor(modelName: "gemini-3.8-flash")
        #expect(flashRate.inputPerMillion == 0.75)

        let proRate = pricing.rateFor(modelName: "gemini-1.5-pro")
        #expect(proRate.inputPerMillion == 1.25)
        #expect(proRate.outputPerMillion == 5.00)

        let claudeRate = pricing.rateFor(modelName: "claude-3-5-sonnet")
        #expect(claudeRate.inputPerMillion == 3.00)
    }

    @Test("AppSurface properties and formatting")
    func testAppSurfaceProperties() {
        #expect(AppSurface.all.shortLabel == "All")
        #expect(AppSurface.desktop.shortLabel == "2.0")
        #expect(AppSurface.cli.shortLabel == "CLI")
        #expect(AppSurface.ide.shortLabel == "IDE")

        #expect(AppSurface.desktop.rawValue == "Antigravity 2.0")
        #expect(AppSurface.cli.rawValue == "CLI")
        #expect(AppSurface.ide.rawValue == "IDE")
    }

    @Test("TranscriptScanner parsing synthetic JSONL")
    func testTranscriptParsing() throws {
        let sampleJSONL = """
        {"step_index":0,"source":"USER_EXPLICIT","type":"USER_INPUT","status":"DONE","created_at":"2026-10-14T17:03:41Z","content":"Hello"}
        {"step_index":1,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","created_at":"2026-10-14T17:03:41Z","input_tokens":1000,"cache_read_tokens":500,"output_tokens":200}
        {"step_index":2,"source":"MODEL","type":"GENERIC","status":"DONE","created_at":"2026-10-14T17:03:45Z","content":"Output"}
        {"step_index":3,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","created_at":"2026-10-14T17:03:48Z","input_tokens":500,"cache_read_tokens":1500,"output_tokens":100}
        {"step_index":3,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","created_at":"2026-10-14T17:03:48Z","input_tokens":500,"cache_read_tokens":1500,"output_tokens":100}
        """

        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_transcript_\(UUID().uuidString).jsonl")
        try sampleJSONL.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let steps = TranscriptScanner.shared.parseTranscriptFile(fileURL: tempFile, surface: .desktop)

        // Step #3 was duplicated in input; should only have 2 steps (#1 and #3)
        #expect(steps.count == 2)

        let totalIn = steps.reduce(0) { $0 + $1.inputTokens }
        let totalCache = steps.reduce(0) { $0 + $1.cacheReadTokens }
        let totalOut = steps.reduce(0) { $0 + $1.outputTokens }

        #expect(totalIn == 1500)
        #expect(totalCache == 2000)
        #expect(totalOut == 300)
        #expect(steps.first?.surface == .desktop)
    }

    @Test("SQLiteConversationScanner parsing protobuf blobs")
    func testSQLiteConversationScanner() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_sqlite_\(UUID().uuidString)")
        let convDir = tempDir.appendingPathComponent("conversations")
        try FileManager.default.createDirectory(at: convDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = convDir.appendingPathComponent("test-session-1.db")

        // Build protobuf data:
        // usage: field 2 = 1200 (in), field 5 = 800 (cache), field 9 = 400 (out), field 10 = 50 (thinking)
        var usagePayload = Data()
        usagePayload.append(encodeVarintField(fieldNumber: 2, value: 1200))
        usagePayload.append(encodeVarintField(fieldNumber: 5, value: 800))
        usagePayload.append(encodeVarintField(fieldNumber: 9, value: 400))
        usagePayload.append(encodeVarintField(fieldNumber: 10, value: 50))
        usagePayload.append(encodeLengthDelimited(fieldNumber: 11, data: "resp-abc".data(using: .utf8)!))

        // chatModel: field 19 = "gemini-3.8-flash", field 4 = usagePayload
        var chatModelPayload = Data()
        chatModelPayload.append(encodeLengthDelimited(fieldNumber: 19, data: "gemini-3.8-flash".data(using: .utf8)!))
        chatModelPayload.append(encodeLengthDelimited(fieldNumber: 4, data: usagePayload))

        // top: field 1 = chatModelPayload
        let topPayload = encodeLengthDelimited(fieldNumber: 1, data: chatModelPayload)

        // Create SQLite DB
        var db: OpaquePointer?
        #expect(sqlite3_open(dbURL.path, &db) == SQLITE_OK)

        let createTable = "CREATE TABLE gen_metadata (idx INTEGER, data BLOB);"
        #expect(sqlite3_exec(db, createTable, nil, nil, nil) == SQLITE_OK)

        var stmt: OpaquePointer?
        let insertSQL = "INSERT INTO gen_metadata (idx, data) VALUES (1, ?);"
        #expect(sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK)
        _ = topPayload.withUnsafeBytes { rawBuffer in
            sqlite3_bind_blob(stmt, 1, rawBuffer.baseAddress, Int32(topPayload.count), nil)
        }
        #expect(sqlite3_step(stmt) == SQLITE_DONE)
        sqlite3_finalize(stmt)
        sqlite3_close(db)

        let (steps, sessions) = SQLiteConversationScanner.shared.scanDirectory(directoryURL: tempDir, surface: .ide)
        #expect(sessions.count == 1)
        #expect(steps.count == 1)

        let step = steps[0]
        #expect(step.inputTokens == 1200)
        #expect(step.cacheReadTokens == 800)
        #expect(step.outputTokens == 450) // 400 + 50 thinking
        #expect(step.modelName == "gemini-3.8-flash")
        #expect(step.surface == .ide)
        #expect(sessions[0].surface == .ide)
    }

    // MARK: - Protobuf Encoding Helpers for Tests

    private func encodeVarint(_ value: UInt64) -> Data {
        var v = value
        var data = Data()
        while v >= 0x80 {
            data.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        data.append(UInt8(v & 0x7F))
        return data
    }

    private func encodeLengthDelimited(fieldNumber: Int, data: Data) -> Data {
        var result = encodeVarint(UInt64((fieldNumber << 3) | 2))
        result.append(encodeVarint(UInt64(data.count)))
        result.append(data)
        return result
    }

    private func encodeVarintField(fieldNumber: Int, value: UInt64) -> Data {
        var result = encodeVarint(UInt64((fieldNumber << 3) | 0))
        result.append(encodeVarint(value))
        return result
    }
}
