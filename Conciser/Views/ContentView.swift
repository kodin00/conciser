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

/// The detail pane for a selected meeting. The transcript remains the primary
/// workspace while an adjustable, optional summary and verdict sits on the right.
private struct MeetingDetailView: View {
    let record: MeetingRecord
    let viewModel: AppViewModel
    @State private var isBriefVisible = true

    var body: some View {
        HSplitView {
            transcriptPane
                .frame(minWidth: 420)

            if isBriefVisible {
                briefSidebar
                    .frame(minWidth: 280, idealWidth: 360, maxWidth: 620)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isBriefVisible.toggle()
                } label: {
                    Label(
                        isBriefVisible ? "Hide Summary & Verdict" : "Show Summary & Verdict",
                        systemImage: "sidebar.right"
                    )
                }
                .help(isBriefVisible ? "Hide summary and verdict" : "Show summary and verdict")
            }
        }
    }

    private var transcriptPane: some View {
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
        .padding(20)
    }

    @ViewBuilder
    private var briefSidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)
                Text("Summary & Verdict")
                    .font(.headline)
                Spacer()
                Button {
                    isBriefVisible = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Hide summary and verdict")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            Divider()

            briefContent
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var briefContent: some View {
        if let verdict = record.verdict {
            ScrollView {
                VerdictView(verdict: verdict)
                    .padding(16)
            }
        } else {
            VStack(alignment: .leading, spacing: 18) {
                Spacer()

                Image(systemName: "text.quote")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 7) {
                    Text("Ready when you are")
                        .font(.title3.weight(.semibold))
                    Text("Create a concise summary, key points, and verdict for this meeting. Your transcript is sent to Gemini only after you click the button below.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Task { await viewModel.runVerdict() }
                } label: {
                    Label("Generate Summary & Verdict", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
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

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
