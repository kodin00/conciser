import Foundation

enum ProcessingStage: Equatable, Sendable {
    case idle
    case extracting
    case downloadingModels
    case transcribing
    case diarizing
    case merging
    case ready         // transcript available
    case verdicting
    case done
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .extracting, .downloadingModels, .transcribing, .diarizing, .merging, .verdicting: return true
        default: return false
        }
    }
    var label: String {
        switch self {
        case .idle: return "Idle"
        case .extracting: return "Extracting audio…"
        case .downloadingModels: return "Downloading model…"
        case .transcribing: return "Transcribing…"
        case .diarizing: return "Identifying speakers…"
        case .merging: return "Merging…"
        case .ready: return "Transcript ready"
        case .verdicting: return "Generating verdict…"
        case .done: return "Done"
        case .failed(let m): return "Error: \(m)"
        }
    }

    /// A one-line explanation of what's happening during this stage, shown
    /// under the label while the app is busy. Empty for non-busy stages.
    var detail: String {
        switch self {
        case .extracting:
            return "Reading and converting the audio from your file."
        case .downloadingModels:
            return "First-time setup — downloading the speech model. This happens only once."
        case .transcribing:
            return "Converting speech to text. This is the longest step and grows with the recording's length."
        case .diarizing:
            return "Transcription is done — now working out who spoke when. Almost there."
        case .merging:
            return "Assembling the final transcript."
        case .verdicting:
            return "Summarizing the conversation with Gemini."
        case .idle, .ready, .done, .failed:
            return ""
        }
    }
}
