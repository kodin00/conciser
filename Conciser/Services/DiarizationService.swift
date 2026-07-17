import Foundation
import FluidAudio

actor DiarizationService {
    private var manager: DiarizerManager?

    init() {}

    /// samples: 16 kHz mono Float32. Returns speaker segments over time.
    func diarize(samples: [Float]) async throws -> [SpeakerSegment] {
        let diarizer = try await diarizerInstance()

        let result = try diarizer.performCompleteDiarization(
            samples,
            sampleRate: Int(conciserTargetSampleRate)
        )

        let segments = result.segments
            .map { segment in
                SpeakerSegment(
                    speakerId: segment.speakerId,
                    start: Double(segment.startTimeSeconds),
                    end: Double(segment.endTimeSeconds)
                )
            }
            .sorted { $0.start < $1.start }

        return segments
    }

    private func diarizerInstance() async throws -> DiarizerManager {
        if let manager {
            return manager
        }

        let loadedModels = try await DiarizerModels.downloadIfNeeded()
        let newManager = DiarizerManager()
        // `initialize(models:)` takes ownership of `loadedModels` (a `consuming` parameter);
        // the manager retains what it needs internally, so we only need to cache the manager.
        newManager.initialize(models: loadedModels)

        manager = newManager
        return newManager
    }
}
