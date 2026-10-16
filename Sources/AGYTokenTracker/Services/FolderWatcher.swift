import Foundation

public final class FolderWatcher: @unchecked Sendable {
    private let lock = NSLock()
    private var dispatchSources: [DispatchSourceFileSystemObject] = []
    private var timerSource: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.antigravity.folderwatcher", qos: .utility)

    private var watchedDirectories: [URL] = []
    private var lastLatestMtime: Date = .distantPast
    private var onChange: (@Sendable () -> Void)?
    private var lastEventTime = Date.distantPast
    private let debounceInterval: TimeInterval = 2.0
    private let pollInterval: TimeInterval = 5.0

    public init() {}

    public func start(watching directories: [URL], onChange: @escaping @Sendable () -> Void) {
        stop()

        let initialMtime = Self.latestRelevantModificationDate(in: directories)

        var newSources: [DispatchSourceFileSystemObject] = []
        for dir in directories {
            guard FileManager.default.fileExists(atPath: dir.path) else { continue }

            let fd = open(dir.path, O_EVTONLY)
            if fd >= 0 {
                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: fd,
                    eventMask: [.write, .extend, .attrib, .link, .rename, .delete],
                    queue: queue
                )

                source.setEventHandler { [weak self] in
                    guard let self = self else { return }
                    let latest = Self.latestRelevantModificationDate(in: self.currentWatchedDirectories())
                    self.handleTrigger(advancingMtimeTo: latest)
                }

                source.setCancelHandler {
                    close(fd)
                }

                newSources.append(source)
            }
        }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in
            self?.checkForNestedChanges()
        }

        lock.lock()
        self.onChange = onChange
        self.watchedDirectories = directories
        self.lastLatestMtime = initialMtime
        self.dispatchSources = newSources
        self.timerSource = timer
        lock.unlock()

        for source in newSources {
            source.resume()
        }
        timer.resume()
    }

    private func currentWatchedDirectories() -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        return watchedDirectories
    }

    private func checkForNestedChanges() {
        let dirs = currentWatchedDirectories()
        guard !dirs.isEmpty else { return }

        let currentLatest = Self.latestRelevantModificationDate(in: dirs)

        lock.lock()
        let hasNewerModification = currentLatest > lastLatestMtime
        lock.unlock()

        if hasNewerModification {
            handleTrigger(advancingMtimeTo: currentLatest)
        }
    }

    /// Computes the newest modification date across watched directories and their nested transcript / SQLite files.
    /// On APFS, modifying `<brain>/<session>/.system_generated/logs/transcript.jsonl` does not update `<brain>`'s mtime,
    /// so we inspect the known nested log and database paths directly.
    public static func latestRelevantModificationDate(in directories: [URL]) -> Date {
        let fm = FileManager.default
        var latest = Date.distantPast

        func recordMtime(of url: URL) {
            if let attrs = try? fm.attributesOfItem(atPath: url.path),
               let mtime = attrs[.modificationDate] as? Date,
               mtime > latest {
                latest = mtime
            }
        }

        for dir in directories {
            guard fm.fileExists(atPath: dir.path) else { continue }
            recordMtime(of: dir)

            guard let children = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for child in children {
                let ext = child.pathExtension
                if ext == "db" || ext == "db-wal" || ext == "jsonl" {
                    recordMtime(of: child)
                    continue
                }

                let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDir else { continue }

                // Check primary session transcript: <session>/.system_generated/logs/transcript.jsonl
                let primaryTranscript = child.appendingPathComponent(".system_generated/logs/transcript.jsonl")
                if fm.fileExists(atPath: primaryTranscript.path) {
                    recordMtime(of: primaryTranscript)
                }

                // Check subagent transcripts: <session>/subagents/<sub>/.system_generated/logs/transcript.jsonl
                let subagentsDir = child.appendingPathComponent("subagents", isDirectory: true)
                if let subFolders = try? fm.contentsOfDirectory(at: subagentsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    for subFolder in subFolders {
                        let subTranscript = subFolder.appendingPathComponent(".system_generated/logs/transcript.jsonl")
                        if fm.fileExists(atPath: subTranscript.path) {
                            recordMtime(of: subTranscript)
                        }
                    }
                }
            }
        }

        return latest
    }

    @discardableResult
    private func handleTrigger(advancingMtimeTo newMtime: Date? = nil) -> Bool {
        let now = Date()
        let callback: (@Sendable () -> Void)?

        lock.lock()
        guard now.timeIntervalSince(lastEventTime) > debounceInterval else {
            lock.unlock()
            return false
        }
        if let newMtime, newMtime > lastLatestMtime {
            lastLatestMtime = newMtime
        }
        lastEventTime = now
        callback = onChange
        lock.unlock()

        guard let callback = callback else { return false }
        DispatchQueue.main.async {
            callback()
        }
        return true
    }

    public func stop() {
        lock.lock()
        let sources = dispatchSources
        let timer = timerSource
        dispatchSources.removeAll()
        watchedDirectories.removeAll()
        timerSource = nil
        onChange = nil
        lastEventTime = .distantPast
        lock.unlock()

        for source in sources {
            source.cancel()
        }
        timer?.cancel()
    }

    deinit {
        stop()
    }
}
