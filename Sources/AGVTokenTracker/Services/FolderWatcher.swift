import Foundation

public final class FolderWatcher: @unchecked Sendable {
    private var fileDescriptors: [Int32] = []
    private var dispatchSources: [DispatchSourceFileSystemObject] = []
    private var timer: Timer?
    private let queue = DispatchQueue(label: "com.antigravity.folderwatcher", qos: .utility)

    private var onChange: (@Sendable () -> Void)?
    private var lastEventTime = Date.distantPast
    private let debounceInterval: TimeInterval = 0.8

    public init() {}

    public func start(watching directories: [URL], onChange: @escaping @Sendable () -> Void) {
        stop()
        self.onChange = onChange

        for dir in directories {
            guard FileManager.default.fileExists(atPath: dir.path) else { continue }

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

        // Auxiliary Polling Timer on main thread every 4 seconds
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
