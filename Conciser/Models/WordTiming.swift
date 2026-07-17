import Foundation

struct WordTiming: Sendable, Hashable {
    let word: String
    let start: Double   // seconds
    let end: Double     // seconds
}
