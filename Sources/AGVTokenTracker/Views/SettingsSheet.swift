import SwiftUI
import AppKit

public struct SettingsSheet: View {
    @ObservedObject var tracker: TrackerViewModel
    @Environment(\.dismiss) private var dismiss

    public init(tracker: TrackerViewModel) {
        self.tracker = tracker
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // 1. Menu Bar Display Mode
            VStack(alignment: .leading, spacing: 6) {
                Text("Menu Bar Item Title")
                    .font(.system(size: 12, weight: .semibold))

                Picker("", selection: $tracker.displayMode) {
                    ForEach(StatusDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            // 2. Antigravity Brain Directory
            VStack(alignment: .leading, spacing: 6) {
                Text("Antigravity 2.0 Logs Directory")
                    .font(.system(size: 12, weight: .semibold))

                HStack {
                    TextField(
                        "Default: ~/.gemini/antigravity/brain",
                        text: $tracker.customBrainPath
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))

                    Button("Default") {
                        tracker.customBrainPath = ""
                        tracker.startWatcher()
                        tracker.refresh()
                    }
                    .font(.system(size: 11))
                }

                Text("Transcripts are scanned from `<brain>/<uuid>/.system_generated/logs/transcript.jsonl`")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // 3. Pricing Source
            VStack(alignment: .leading, spacing: 6) {
                Text("Pricing Engine")
                    .font(.system(size: 12, weight: .semibold))

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

            Spacer()

            // 4. Quick Actions
            HStack {
                Button("Open Logs in Finder") {
                    let url = TranscriptScanner.shared.resolveBrainDirectory(
                        customPath: tracker.customBrainPath.isEmpty ? nil : tracker.customBrainPath
                    )
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
                }
                .font(.system(size: 11))

                Spacer()

                Button("Quit App", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 11))
            }
        }
        .padding(16)
        .frame(width: 380, height: 350)
    }
}
