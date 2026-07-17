import SwiftUI
import UniformTypeIdentifiers

/// A drag-and-drop target plus a "Choose File…" button for picking a video
/// or audio recording to process.
struct DropZoneView: View {
    let stage: ProcessingStage
    let onFile: (URL) -> Void

    @State private var isTargeted = false
    @State private var isImporterPresented = false

    private static let acceptedTypes: [UTType] = [
        .movie,
        .audio,
        .mpeg4Movie,
        .quickTimeMovie,
        .mp3,
        .wav,
        .audiovisualContent
    ]

    private var isBusy: Bool { stage.isBusy }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("Drop a video or recording, or click to choose")
                    .font(.headline)
                Text("Video and audio files are supported")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                isImporterPresented = true
            } label: {
                Label("Choose File…", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isBusy else { return }
            isImporterPresented = true
        }
        .opacity(isBusy ? 0.5 : 1)
        .allowsHitTesting(!isBusy)
        .dropDestination(for: URL.self) { urls, _ in
            guard !isBusy, let url = urls.first else { return false }
            onFile(url)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: Self.acceptedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    onFile(url)
                }
            case .failure:
                break
            }
        }
    }
}
