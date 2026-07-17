import Foundation

enum TranscriptMerger {
    /// Assigns each word to the speaker segment with which it overlaps most in time,
    /// then coalesces consecutive same-speaker words into TranscriptSegments.
    /// Speaker ids are remapped to friendly "Speaker N" labels in order of first appearance.
    static func merge(words: [WordTiming], speakers: [SpeakerSegment]) -> [TranscriptSegment] {
        guard !words.isEmpty else { return [] }

        // 1. Assign each word to a raw speakerId.
        var rawSpeakerIds: [String] = []
        rawSpeakerIds.reserveCapacity(words.count)

        if speakers.isEmpty {
            rawSpeakerIds = Array(repeating: "Speaker 1", count: words.count)
        } else {
            for word in words {
                rawSpeakerIds.append(assignSpeaker(for: word, speakers: speakers))
            }
        }

        // 2. Build a stable "raw id" -> "Speaker N" map, in order of first appearance.
        var friendlyLabel: [String: String] = [:]
        var nextSpeakerNumber = 1
        var friendlySpeakerIds: [String] = []
        friendlySpeakerIds.reserveCapacity(words.count)

        for rawId in rawSpeakerIds {
            if let label = friendlyLabel[rawId] {
                friendlySpeakerIds.append(label)
            } else {
                let label = "Speaker \(nextSpeakerNumber)"
                friendlyLabel[rawId] = label
                nextSpeakerNumber += 1
                friendlySpeakerIds.append(label)
            }
        }

        // 3. Coalesce consecutive words with the same assigned speaker.
        var segments: [TranscriptSegment] = []
        var currentLabel = friendlySpeakerIds[0]
        var currentWords: [WordTiming] = [words[0]]

        func flush() {
            guard let first = currentWords.first, let last = currentWords.last else { return }
            let text = currentWords.map { $0.word }.joined(separator: " ")
            segments.append(
                TranscriptSegment(
                    speakerLabel: currentLabel,
                    text: text,
                    start: first.start,
                    end: last.end
                )
            )
        }

        for index in 1..<words.count {
            let label = friendlySpeakerIds[index]
            if label == currentLabel {
                currentWords.append(words[index])
            } else {
                flush()
                currentLabel = label
                currentWords = [words[index]]
            }
        }
        flush()

        return segments
    }

    /// Finds the speakerId whose segment overlaps the word the most in time.
    /// Falls back to the nearest segment by midpoint distance if there is no overlap.
    private static func assignSpeaker(for word: WordTiming, speakers: [SpeakerSegment]) -> String {
        var bestSpeakerId: String?
        var bestOverlap: Double = 0

        for segment in speakers {
            let overlap = max(0, min(word.end, segment.end) - max(word.start, segment.start))
            if overlap > bestOverlap {
                bestOverlap = overlap
                bestSpeakerId = segment.speakerId
            }
        }

        if let bestSpeakerId {
            return bestSpeakerId
        }

        // No segment overlaps this word (e.g. it falls in a gap) — fall back to the
        // segment whose midpoint is closest to the word's midpoint.
        let wordMidpoint = (word.start + word.end) / 2
        var nearestSpeakerId = speakers[0].speakerId
        var nearestDistance = Double.greatestFiniteMagnitude

        for segment in speakers {
            let segmentMidpoint = (segment.start + segment.end) / 2
            let distance = abs(segmentMidpoint - wordMidpoint)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestSpeakerId = segment.speakerId
            }
        }

        return nearestSpeakerId
    }

    /// Maximum character length a paragraph is allowed to grow to before a new
    /// one is started, even without a qualifying pause. Keeps long unbroken
    /// stretches of speech readable.
    private static let maxParagraphLength = 240

    /// Groups words into readable paragraphs by pauses (no speaker labels).
    /// speakerLabel is "" for every segment. Starts a new segment when the silent
    /// gap before a word exceeds `pauseThreshold` seconds (default ~1.2) or the
    /// running segment gets long (e.g. > ~240 chars) so paragraphs stay readable.
    static func segmentsByPause(words: [WordTiming], pauseThreshold: Double = 1.2) -> [TranscriptSegment] {
        guard !words.isEmpty else { return [] }

        var segments: [TranscriptSegment] = []
        var currentWords: [WordTiming] = [words[0]]
        var currentLength = words[0].word.count

        func flush() {
            guard let first = currentWords.first, let last = currentWords.last else { return }
            let text = currentWords.map { $0.word }.joined(separator: " ")
            segments.append(
                TranscriptSegment(
                    speakerLabel: "",
                    text: text,
                    start: first.start,
                    end: last.end
                )
            )
        }

        for index in 1..<words.count {
            let word = words[index]
            let previous = words[index - 1]
            let gap = word.start - previous.end

            if gap > pauseThreshold || currentLength > maxParagraphLength {
                flush()
                currentWords = [word]
                currentLength = word.word.count
            } else {
                currentWords.append(word)
                currentLength += word.word.count + 1
            }
        }
        flush()

        return segments
    }
}
