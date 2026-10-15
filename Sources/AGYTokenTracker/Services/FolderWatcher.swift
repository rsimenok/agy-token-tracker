import Foundation

public final class FolderWatcher: @unchecked Sendable {
    private var fileDescriptors: [Int32] = []
    private var dispatchSources: [DispatchSourceFileSystemObject] = []
    private var timer: Timer?
    private let queue = DispatchQueue(label: "com.antigravity.folderwatcher", qos: .utility)

    private var watchedDirectories: [URL] = []
    private var lastMtimes: [URL: Date] = [:]
    private var onChange: (@Sendable () -> Void)?
    private var lastEventTime = Date.distantPast
    private let debounceInterval: TimeInterval = 2.5

    public init() {}

    public func start(watching directories: [URL], onChange: @escaping @Sendable () -> Void) {
        stop()
        self.onChange = onChange
        self.watchedDirectories = directories

        for dir in directories {
            guard FileManager.default.fileExists(atPath: dir.path) else { continue }

            let mtime = (try? dir.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            lastMtimes[dir] = mtime

            let fd = open(dir.path, O_EVTONLY)
            if fd >= 0 {
                fileDescriptors.append(fd)
                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: fd,
                    eventMask: [.write, .extend, .attrib, .link],
                    queue: queue
                )

                source.setEventHandler { [weak self] in
                    self?.handleTrigger()
                }

                source.setCancelHandler {
                    close(fd)
                }

                source.resume()
                dispatchSources.append(source)
            }
        }

        // Low-frequency background fallback check every 45 seconds: only trigger if an mtime actually changed
        DispatchQueue.main.async { [weak self] in
            self?.timer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                var changed = false
                for dir in self.watchedDirectories {
                    guard let currentMtime = try? dir.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else { continue }
                    if let prev = self.lastMtimes[dir], currentMtime > prev {
                        self.lastMtimes[dir] = currentMtime
                        changed = true
                    }
                }
                if changed {
                    self.handleTrigger()
                }
            }
        }
    }

    private func handleTrigger() {
        let now = Date()
        guard now.timeIntervalSince(lastEventTime) > debounceInterval else { return }
        lastEventTime = now

        DispatchQueue.main.async { [weak self] in
            self?.onChange?()
        }
    }

    public func stop() {
        for source in dispatchSources {
            source.cancel()
        }
        dispatchSources.removeAll()
        fileDescriptors.removeAll()
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stop()
    }
}
