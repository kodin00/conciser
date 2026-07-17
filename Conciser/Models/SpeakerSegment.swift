import Foundation

struct SpeakerSegment: Sendable, Hashable {
    let speakerId: String
    let start: Double   // seconds
    let end: Double     // seconds
}
