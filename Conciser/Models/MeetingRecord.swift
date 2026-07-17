import Foundation

/// A single persisted meeting: its source transcript, metadata, and (once
/// generated) the Gemini verdict. Stored to disk via `HistoryStore`.
struct MeetingRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var createdAt: Date
    var fileName: String
    var languageCode: String       // "id" / "en" / "" (auto)
    var identifiedSpeakers: Bool
    var segments: [TranscriptSegment]
    var verdict: Verdict?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        fileName: String,
        languageCode: String,
        identifiedSpeakers: Bool,
        segments: [TranscriptSegment],
        verdict: Verdict? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.fileName = fileName
        self.languageCode = languageCode
        self.identifiedSpeakers = identifiedSpeakers
        self.segments = segments
        self.verdict = verdict
    }

    /// "Speaker: text" per segment (just text when the segment has no speaker label), joined by blank lines.
    var transcriptText: String {
        segments
            .map { segment in
                segment.speakerLabel.isEmpty ? segment.text : "\(segment.speakerLabel): \(segment.text)"
            }
            .joined(separator: "\n\n")
    }

    /// Filename without path, used as the sidebar title. If empty, "Untitled".
    var displayTitle: String {
        let name = (fileName as NSString).lastPathComponent
        return name.isEmpty ? "Untitled" : name
    }

    /// Human date like "Jul 17, 2026 · 2:30 PM" (use DateFormatter, .medium date + .short time).
    var displaySubtitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    /// Count of distinct non-empty speaker labels.
    var speakerCount: Int {
        Set(segments.map(\.speakerLabel).filter { !$0.isEmpty }).count
    }

    /// Total duration in seconds = last segment's end (0 if empty).
    var duration: Double {
        segments.last?.end ?? 0
    }
}
