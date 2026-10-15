import SwiftUI
import AppKit

public struct SettingsSheet: View {
    @ObservedObject var tracker: TrackerViewModel
    @Environment(\.dismiss) private var dismiss

    public init(tracker: TrackerViewModel) {
        self.tracker = tracker
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text("Settings")
                        .font(.system(size: 15, weight: .bold))
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // 1. Menu Bar Display Mode
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Menu Bar Item Title")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        Picker("", selection: $tracker.displayMode) {
                            ForEach(StatusDisplayMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // 2. Monitored Surfaces
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monitored Surfaces & Storage")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        VStack(spacing: 6) {
                            SurfaceStatusRow(
                                surface: .desktop,
                                path: tracker.customBrainPath.isEmpty ? "~/.gemini/antigravity/brain" : tracker.customBrainPath,
                                url: TranscriptScanner.shared.resolveBrainDirectory(
                                    customPath: tracker.customBrainPath.isEmpty ? nil : tracker.customBrainPath
                                )
                            )

                            SurfaceStatusRow(
                                surface: .cli,
                                path: "~/.gemini/antigravity-cli",
                                url: AppSurface.cli.defaultDirectoryURL
                            )

                            SurfaceStatusRow(
                                surface: .ide,
                                path: "~/.gemini/antigravity-ide",
                                url: AppSurface.ide.defaultDirectoryURL
                            )
                        }

                        // Custom 2.0 path input
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom Antigravity 2.0 brain directory (optional):")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            HStack {
                                TextField(
                                    "Default: ~/.gemini/antigravity/brain",
                                    text: $tracker.customBrainPath
                                )
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 10, design: .monospaced))

                                if !tracker.customBrainPath.isEmpty {
                                    Button("Reset") {
                                        tracker.customBrainPath = ""
                                        tracker.startWatcher()
                                        tracker.refresh()
                                    }
                                    .font(.system(size: 10))
                                }
                            }
                        }
                        .padding(.top, 2)
                    }

                    // 3. Pricing Engine
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pricing Engine")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Source: LiteLLM Open Database")
                                    .font(.system(size: 11, weight: .medium))
                                if let date = tracker.pricingSyncDate {
                                    Text("Last synced: \(date.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Using built-in Gemini Flash/Pro offline rates")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Button("Sync Rates") {
                                Task {
                                    await PricingService.shared.fetchRemotePricing()
                                    await MainActor.run {
                                        tracker.pricingSyncDate = PricingService.shared.lastSyncDate
                                        tracker.refresh()
                                    }
                                }
                            }
                            .font(.system(size: 11))
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    }
                }
            }

            Divider()

            // Footer / Actions
            HStack {
                Text("AGYTokenTracker v1.0.0")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                Button("Quit App", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 11))
            }
        }
        .padding(16)
        .frame(width: 420, height: 440)
    }
}

public struct SurfaceStatusRow: View {
    let surface: AppSurface
    let path: String
    let url: URL

    public init(surface: AppSurface, path: String, url: URL) {
        self.surface = surface
        self.path = path
        self.url = url
    }

    private var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: surface.iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(surface.badgeColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(surface.rawValue)
                        .font(.system(size: 11, weight: .semibold))

                    if exists {
                        Text("Active")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(3)
                    } else {
                        Text("Not Found")
                            .font(.system(size: 8, weight: .medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12))
                            .foregroundColor(.secondary)
                            .cornerRadius(3)
                    }
                }

                Text(path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if exists {
                Button(action: {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
                }) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open in Finder")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }
}
