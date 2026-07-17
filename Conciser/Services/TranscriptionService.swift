import Foundation
import WhisperKit

/// NOTE: WhisperKit itself exports a public `WordTiming` struct (word/tokens/start/end/probability,
/// with Float timestamps). That collides by name with our own `Conciser.WordTiming` (Double
/// timestamps) in any file that imports both this module and WhisperKit. To avoid an "ambiguous
/// use of 'WordTiming'" compile error, this file always spells our own model type out as
/// `Conciser.WordTiming` and never writes the bare `WordTiming` identifier.
actor TranscriptionService {
    private let modelName: String
    private var whisperKit: WhisperKit?

    // NOTE: model names must match a folder in argmaxinc/whisperkit-coreml.
    // The turbo folder is "openai_whisper-large-v3_turbo" (underscore, not hyphen,
    // before "turbo"), so the name passed to WhisperKit must be "large-v3_turbo".
    init(model: String = "large-v3_turbo") {
        self.modelName = model
    }

    /// Ensures the model is downloaded (reporting byte-level progress) and loaded.
    /// If the model is already loaded, reports progress(1.0) immediately and returns.
    func loadIfNeeded(progress: @escaping @Sendable (Double) -> Void) async throws {
        if whisperKit != nil {
            progress(1.0)
            return
        }
        let folder = try await WhisperKit.download(variant: modelName) { p in
            progress(p.fractionCompleted)
        }
        let config = WhisperKitConfig(
            model: modelName,
            modelFolder: folder.path,
            prewarm: true,
            load: true
        )
        whisperKit = try await WhisperKit(config)
    }

    /// language: BCP-ish Whisper code like "id" (Indonesian) or "en"; nil = auto-detect.
    /// Returns a flat, time-ordered list of word timings.
    func transcribe(
        samples: [Float],
        language: String?,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> [Conciser.WordTiming] {
        let pipe = try await whisperKitInstance()

        let options = DecodingOptions(
            language: language,
            detectLanguage: language == nil,
            wordTimestamps: true
        )

        let results: [TranscriptionResult] = try await pipe.transcribe(
            audioArray: samples,
            decodeOptions: options,
            callback: { (_: TranscriptionProgress) -> Bool? in
                progress(pipe.progress.fractionCompleted)
                return nil
            }
        )

        var words: [Conciser.WordTiming] = []
        for result in results {
            for word in result.allWords {
                let trimmed = word.word.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                words.append(
                    Conciser.WordTiming(
                        word: trimmed,
                        start: Double(word.start),
                        end: Double(word.end)
                    )
                )
            }
        }

        // Results (and their segments/words) come back in chronological order already,
        // but sort defensively in case multiple TranscriptionResult chunks are involved.
        words.sort { $0.start < $1.start }
        return words
    }

    private func whisperKitInstance() async throws -> WhisperKit {
        try await loadIfNeeded { _ in }
        guard let whisperKit else {
            throw WhisperError.modelsUnavailable("WhisperKit failed to load after loadIfNeeded()")
        }
        return whisperKit
    }
}
