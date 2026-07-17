import Foundation

struct Verdict: Sendable, Codable, Hashable {
    let summary: String
    let keyPoints: [String]
    let sentiment: String     // "Positive" | "Neutral" | "Negative" | "Mixed"
    let verdictText: String   // overall assessment / call
}
