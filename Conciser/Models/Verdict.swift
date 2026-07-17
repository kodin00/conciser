import Foundation

struct Verdict: Sendable, Codable, Hashable {
    let summary: String
    let keyPoints: [String]
    let verdictText: String   // overall assessment / call
}
