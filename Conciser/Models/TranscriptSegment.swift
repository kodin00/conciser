import Foundation

struct TranscriptSegment: Identifiable, Sendable, Hashable, Codable {
    let id = UUID()
    let speakerLabel: String   // e.g. "Speaker 1"
    let text: String
    let start: Double
    let end: Double
}
