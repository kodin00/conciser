import SwiftUI
import AppKit

/// Renders a merged transcript as a scrollable list of speaker-labeled
/// segments, plus a "Copy transcript" action.
struct TranscriptView: View {
    let segments: [TranscriptSegment]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Transcript")
                    .font(.title3.bold())
                Spacer()
                Button {
                    copyTranscript()
                } label: {
                    Label("Copy transcript", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(segments) { segment in
                        TranscriptRow(segment: segment, color: color(for: segment.speakerLabel))
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func copyTranscript() {
        let text = segments.map { segment in
            segment.speakerLabel.isEmpty ? segment.text : "\(segment.speakerLabel): \(segment.text)"
        }.joined(separator: "\n\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// A stable, deterministic color per distinct speaker label. Avoids
    /// `Hasher`, whose per-process random seed would otherwise reshuffle
    /// colors for the same speaker across app launches (e.g. when reopening
    /// a saved meeting from history).
    private func color(for speakerLabel: String) -> Color {
        let palette: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo, .brown]
        let hash = speakerLabel.utf8.reduce(0) { $0 &+ Int($1) }
        return palette[hash % palette.count]
    }
}

private struct TranscriptRow: View {
    let segment: TranscriptSegment
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if !segment.speakerLabel.isEmpty {
                    Text(segment.speakerLabel)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(color, in: Capsule())
                }

                Text(timestamp(segment.start))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Text(segment.text)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func timestamp(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
