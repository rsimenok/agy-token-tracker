import Foundation

public final class UnifiedScanner: Sendable {
    public static let shared = UnifiedScanner()

    private let transcriptScanner = TranscriptScanner.shared
    private let sqliteScanner = SQLiteConversationScanner.shared

    public init() {}

    public func scanAllSurfaces(customDesktopBrainPath: String? = nil) -> (steps: [TokenStep], sessions: [SessionSummary]) {
        var allSteps: [TokenStep] = []
        var allSessions: [SessionSummary] = []
        var seenSessionKeys = Set<String>()

        let home = FileManager.default.homeDirectoryForCurrentUser

        // 1. Antigravity 2.0 (Desktop)
        let desktopBrainURL = transcriptScanner.resolveBrainDirectory(customPath: customDesktopBrainPath)
        let (desktopSteps, desktopSessions) = transcriptScanner.scanAll(brainURL: desktopBrainURL, surface: .desktop)
        for s in desktopSessions {
            seenSessionKeys.insert("desktop:\(s.sessionId)")
        }
        allSteps.append(contentsOf: desktopSteps)
        allSessions.append(contentsOf: desktopSessions)

        // 2. Antigravity CLI
        let cliHome = home.appendingPathComponent(".gemini/antigravity-cli", isDirectory: true)
        // Check CLI transcripts
        let cliBrain = cliHome.appendingPathComponent("brain", isDirectory: true)
        let (cliTranscriptSteps, cliTranscriptSessions) = transcriptScanner.scanAll(brainURL: cliBrain, surface: .cli)
        for s in cliTranscriptSessions {
            seenSessionKeys.insert("cli:\(s.sessionId)")
        }
        allSteps.append(contentsOf: cliTranscriptSteps)
        allSessions.append(contentsOf: cliTranscriptSessions)

        // Also check CLI SQLite conversations for any sessions not yet in transcript
        let (cliDbSteps, cliDbSessions) = sqliteScanner.scanDirectory(directoryURL: cliHome, surface: .cli)
        for s in cliDbSessions where !seenSessionKeys.contains("cli:\(s.sessionId)") {
            seenSessionKeys.insert("cli:\(s.sessionId)")
            allSessions.append(s)
            let matchingSteps = cliDbSteps.filter { $0.sessionId == s.sessionId }
            allSteps.append(contentsOf: matchingSteps)
        }

        // 3. Antigravity IDE
        let ideHome = home.appendingPathComponent(".gemini/antigravity-ide", isDirectory: true)
        let (ideSteps, ideSessions) = sqliteScanner.scanDirectory(directoryURL: ideHome, surface: .ide)
        for s in ideSessions where !seenSessionKeys.contains("ide:\(s.sessionId)") {
            seenSessionKeys.insert("ide:\(s.sessionId)")
            allSessions.append(s)
            let matchingSteps = ideSteps.filter { $0.sessionId == s.sessionId }
            allSteps.append(contentsOf: matchingSteps)
        }

        allSessions.sort { $0.lastUpdated > $1.lastUpdated }
        allSteps.sort { $0.date > $1.date }

        return (allSteps, allSessions)
    }
}
