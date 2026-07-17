import Foundation
import SwiftUI

@MainActor
@Observable
final class AppViewModel {
    var stage: ProcessingStage = .idle
    /// nil ⇒ indeterminate spinner; a value 0...1 ⇒ determinate progress bar.
    var progress: Double? = nil
    var segments: [TranscriptSegment] = []
    var verdict: Verdict?
    var fileName: String?
    /// "id" Indonesian, "en" English, "" auto-detect.
    var selectedLanguage: String
    var errorMessage: String?
    /// Set when a long-running operation (processing or verdict) begins, and
    /// cleared once it settles. Drives the elapsed-time display in the UI.
    var processingStartedAt: Date? = nil

    /// Persisted meeting history, newest first.
    var records: [MeetingRecord] = []
    /// The currently selected history entry, if any.
    var selectedRecordID: MeetingRecord.ID? = nil
    /// True while the user is composing a brand-new transcription (drop zone
    /// or in-progress pipeline) rather than viewing a saved record.
    var isComposingNew: Bool = false

    private let transcriptionService = TranscriptionService()
    private let diarizationService = DiarizationService()
    private let verdictService = VerdictService()

    init() {
        selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "id"
        records = HistoryStore.load()
        selectedRecordID = records.first?.id
        isComposingNew = records.isEmpty
    }

    var transcriptText: String {
        segments.map { segment in
            segment.speakerLabel.isEmpty ? segment.text : "\(segment.speakerLabel): \(segment.text)"
        }.joined(separator: "\n\n")
    }

    var hasTranscript: Bool {
        !segments.isEmpty
    }

    var selectedRecord: MeetingRecord? {
        records.first { $0.id == selectedRecordID }
    }

    func startNew() {
        isComposingNew = true
        selectedRecordID = nil
        fileName = nil
        stage = .idle
        progress = nil
        errorMessage = nil
    }

    func select(_ id: MeetingRecord.ID) {
        selectedRecordID = id
        isComposingNew = false
    }

    func delete(_ id: MeetingRecord.ID) {
        records.removeAll { $0.id == id }
        HistoryStore.save(records)
        if selectedRecordID == id {
            selectedRecordID = records.first?.id
            isComposingNew = records.isEmpty
        }
    }

    func process(url: URL) async {
        // Pick up the latest language/speaker preference in case Settings changed it.
        selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "id"
        let identifySpeakers = UserDefaults.standard.object(forKey: "identifySpeakers") as? Bool ?? true

        fileName = url.lastPathComponent
        errorMessage = nil
        verdict = nil
        segments = []
        processingStartedAt = Date()

        do {
            stage = .extracting
            progress = nil
            let samples = try await AudioExtractor.extractSamples(from: url)

            let language: String? = selectedLanguage.isEmpty ? nil : selectedLanguage

            stage = .downloadingModels
            progress = 0
            try await transcriptionService.loadIfNeeded { fraction in
                Task { @MainActor in self.progress = fraction }
            }

            stage = .transcribing
            progress = 0

            let merged: [TranscriptSegment]
            if identifySpeakers {
                async let wordsTask: [Conciser.WordTiming] = transcriptionService.transcribe(
                    samples: samples,
                    language: language
                ) { fraction in
                    Task { @MainActor in self.progress = fraction }
                }
                async let speakersTask = diarizationService.diarize(samples: samples)

                let words = try await wordsTask

                stage = .diarizing
                progress = nil
                let speakers = try await speakersTask

                stage = .merging
                progress = nil
                merged = TranscriptMerger.merge(words: words, speakers: speakers)
            } else {
                let words = try await transcriptionService.transcribe(
                    samples: samples,
                    language: language
                ) { fraction in
                    Task { @MainActor in self.progress = fraction }
                }

                stage = .merging
                progress = nil
                merged = TranscriptMerger.segmentsByPause(words: words)
            }

            segments = merged

            let record = MeetingRecord(
                fileName: url.lastPathComponent,
                languageCode: selectedLanguage,
                identifiedSpeakers: identifySpeakers,
                segments: merged
            )
            records.insert(record, at: 0)
            HistoryStore.save(records)
            selectedRecordID = record.id
            isComposingNew = false

            stage = .ready
            progress = nil
            processingStartedAt = nil
        } catch {
            stage = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
            progress = nil
            processingStartedAt = nil
        }
    }

    func runVerdict() async {
        guard var record = selectedRecord else { return }

        guard let apiKey = UserDefaults.standard.string(forKey: "geminiApiKey"), !apiKey.isEmpty else {
            errorMessage = "No Gemini API key is set. Add one in Settings."
            return
        }

        let languageName: String
        switch record.languageCode {
        case "id":
            languageName = "Indonesian"
        case "en":
            languageName = "English"
        default:
            languageName = "the transcript's language"
        }

        do {
            stage = .verdicting
            processingStartedAt = Date()
            let result = try await verdictService.generateVerdict(
                transcript: record.transcriptText,
                apiKey: apiKey,
                language: languageName
            )
            record.verdict = result
            if let index = records.firstIndex(where: { $0.id == record.id }) {
                records[index] = record
            }
            HistoryStore.save(records)
            stage = .done
            processingStartedAt = nil
        } catch {
            stage = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
            processingStartedAt = nil
        }
    }

    func reset() {
        stage = .idle
        progress = nil
        segments = []
        verdict = nil
        fileName = nil
        errorMessage = nil
        processingStartedAt = nil
    }
}
