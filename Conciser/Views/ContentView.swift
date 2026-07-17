import SwiftUI

struct ContentView: View {
    @State private var viewModel = AppViewModel()

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 900, minHeight: 600)
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(
            selection: Binding(
                get: { viewModel.selectedRecordID },
                set: { newValue in
                    if let id = newValue {
                        viewModel.select(id)
                    }
                }
            )
        ) {
            if viewModel.records.isEmpty {
                ContentUnavailableView(
                    "No Meetings Yet",
                    systemImage: "waveform",
                    description: Text("Drop an audio or video file to create your first transcript.")
                )
            } else {
                ForEach(viewModel.records) { record in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.displayTitle)
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(record.displaySubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(record.id)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            viewModel.delete(record.id)
                        }
                    }
                }
            }
        }
        .navigationTitle("Conciser")
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.startNew()
                } label: {
                    Label("New Transcription", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .automatic) {
                SettingsLink {
                    Image(systemName: "gearshape")
                }
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if viewModel.isComposingNew && viewModel.stage.isBusy {
            ProcessingStatusCard(
                stage: viewModel.stage,
                progress: viewModel.progress,
                startedAt: viewModel.processingStartedAt
            )
            .padding(20)
        } else if !viewModel.isComposingNew, let record = viewModel.selectedRecord {
            MeetingDetailView(record: record, viewModel: viewModel)
        } else {
            DropZoneView(stage: viewModel.stage) { url in
                Task { await viewModel.process(url: url) }
            }
            .padding(20)
        }
    }
}

/// The detail pane for a selected (or freshly created) meeting: a tabbed
/// Transcript / Verdict view. The transcript tab fills the available height
/// and scrolls internally via `TranscriptView`; nothing here wraps it in an
/// additional `ScrollView`.
private struct MeetingDetailView: View {
    let record: MeetingRecord
    let viewModel: AppViewModel

    var body: some View {
        TabView {
            transcriptTab
                .tabItem {
                    Label("Transcript", systemImage: "text.alignleft")
                }

            verdictTab
                .tabItem {
                    Label("Verdict", systemImage: "sparkles")
                }
        }
        .padding(20)
    }

    private var transcriptTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.displayTitle)
                    .font(.title3.bold())
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(record.displaySubtitle) · \(speakerText) · \(durationString(record.duration))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TranscriptView(segments: record.segments)
        }
    }

    @ViewBuilder
    private var verdictTab: some View {
        if let verdict = record.verdict {
            ScrollView {
                VerdictView(verdict: verdict)
                    .padding(.vertical, 4)
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    Text("No verdict yet")
                        .font(.headline)
                    Text("Generate an AI summary of this meeting's transcript with Gemini.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                Button {
                    Task { await viewModel.runVerdict() }
                } label: {
                    Label("Generate Verdict", systemImage: "sparkles")
                        .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.stage.isBusy)

                if viewModel.stage == .verdicting {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Generating verdict…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var speakerText: String {
        let count = record.speakerCount
        return count == 1 ? "1 speaker" : "\(count) speakers"
    }

    private func durationString(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

/// A centered status panel shown while the app is processing a file and no
/// transcript is available yet. Surfaces the current stage, a one-line
/// explanation of what's happening, progress (determinate or indeterminate),
/// and an elapsed-time counter.
private struct ProcessingStatusCard: View {
    let stage: ProcessingStage
    let progress: Double?
    let startedAt: Date?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbolName)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text(stage.label)
                    .font(.headline)

                if !stage.detail.isEmpty {
                    Text(stage.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
            }

            progressRow

            if let startedAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("Elapsed \(elapsedString(from: startedAt, to: context.date))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.quaternary.opacity(0.25))
        )
    }

    @ViewBuilder
    private var progressRow: some View {
        if let progress {
            VStack(spacing: 6) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 300)
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        } else {
            ProgressView()
                .controlSize(.regular)
        }
    }

    private var symbolName: String {
        switch stage {
        case .extracting: return "gearshape"
        case .downloadingModels: return "arrow.down.circle"
        case .transcribing: return "waveform"
        case .diarizing: return "person.2"
        case .merging: return "gearshape"
        case .verdicting: return "sparkles"
        case .idle, .ready, .done, .failed: return "hourglass"
        }
    }

    private func elapsedString(from start: Date, to now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(start)))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
}
