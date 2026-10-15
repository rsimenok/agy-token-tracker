import Testing
import Foundation
@testable import AGVTokenTracker

@Suite("AGV Token Tracker Tests")
struct AGVTokenTrackerTests {

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
        #expect(flashRate.inputPerMillion == 0.15)

        let proRate = pricing.rateFor(modelName: "gemini-1.5-pro")
        #expect(proRate.inputPerMillion == 1.25)
        #expect(proRate.outputPerMillion == 5.00)

        let claudeRate = pricing.rateFor(modelName: "claude-3-5-sonnet")
        #expect(claudeRate.inputPerMillion == 3.00)
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

        let steps = TranscriptScanner.shared.parseTranscriptFile(fileURL: tempFile)

        // Step #3 was duplicated in input; should only have 2 steps (#1 and #3)
        #expect(steps.count == 2)

        let totalIn = steps.reduce(0) { $0 + $1.inputTokens }
        let totalCache = steps.reduce(0) { $0 + $1.cacheReadTokens }
        let totalOut = steps.reduce(0) { $0 + $1.outputTokens }

        #expect(totalIn == 1500)
        #expect(totalCache == 2000)
        #expect(totalOut == 300)
    }
}
