import Foundation

public final class FolderWatcher: @unchecked Sendable {
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var timer: Timer?
    private let queue = DispatchQueue(label: "com.antigravity.folderwatcher", qos: .utility)

    private var onChange: (@Sendable () -> Void)?
    private var lastEventTime = Date.distantPast
    private let debounceInterval: TimeInterval = 0.8

    public init() {}

    public func start(watching directoryURL: URL, onChange: @escaping @Sendable () -> Void) {
        stop()
        self.onChange = onChange

        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            return
        }

        // 1. Dispatch source for immediate file system notifications
        fileDescriptor = open(directoryURL.path, O_EVTONLY)
        if fileDescriptor >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: [.write, .extend, .attrib, .link],
                queue: queue
            )

            source.setEventHandler { [weak self] in
                self?.handleTrigger()
            }

            source.setCancelHandler { [weak self] in
                if let fd = self?.fileDescriptor, fd >= 0 {
                    close(fd)
                    self?.fileDescriptor = -1
                }
            }

            source.resume()
            self.dispatchSource = source
        }

        // 2. Auxiliary Polling Timer on main thread every 4 seconds to guarantee
        // subfolder file updates (e.g. brain/<uuid>/.system_generated/logs/transcript.jsonl)
        // are never missed even when top-level directory attributes don't change.
        DispatchQueue.main.async { [weak self] in
            self?.timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
                self?.handleTrigger()
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
        dispatchSource?.cancel()
        dispatchSource = nil
        timer?.invalidate()
        timer = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    deinit {
        stop()
    }
}
