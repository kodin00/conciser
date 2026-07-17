import AVFoundation
import CoreMedia
import Foundation

/// Target sample rate (Hz) required by both WhisperKit and FluidAudio.
let conciserTargetSampleRate: Double = 16000

enum AudioExtractorError: LocalizedError {
    case noAudioTrack
    case cannotStartAccess
    case readerInitFailed(String)
    case readerFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "The selected file does not contain an audio track."
        case .cannotStartAccess:
            return "Could not access the selected file. Please try dropping it again."
        case .readerInitFailed(let reason):
            return "Failed to prepare audio for reading: \(reason)"
        case .readerFailed(let reason):
            return "Failed while reading audio samples: \(reason)"
        }
    }
}

enum AudioExtractor {
    /// Extracts the first audio track from a video or audio file and returns
    /// 16 kHz mono Float32 PCM samples in [-1, 1].
    static func extractSamples(from url: URL) async throws -> [Float] {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let asset = AVURLAsset(url: url)

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else {
            throw AudioExtractorError.noAudioTrack
        }

        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw AudioExtractorError.readerInitFailed(error.localizedDescription)
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: conciserTargetSampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
        ]

        let trackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        trackOutput.alwaysCopiesSampleData = false

        guard reader.canAdd(trackOutput) else {
            throw AudioExtractorError.readerInitFailed("Cannot attach audio track output to reader.")
        }
        reader.add(trackOutput)

        guard reader.startReading() else {
            let reason = reader.error?.localizedDescription ?? "Unknown reader error."
            throw AudioExtractorError.readerFailed(reason)
        }

        var samples: [Float] = []

        while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }

            let length = CMBlockBufferGetDataLength(blockBuffer)
            guard length > 0 else { continue }

            let floatCount = length / MemoryLayout<Float>.size
            var buffer = [Float](repeating: 0, count: floatCount)

            let status = buffer.withUnsafeMutableBytes { rawBuffer -> OSStatus in
                CMBlockBufferCopyDataBytes(
                    blockBuffer,
                    atOffset: 0,
                    dataLength: length,
                    destination: rawBuffer.baseAddress!
                )
            }

            if status == noErr {
                samples.append(contentsOf: buffer)
            }
        }

        if reader.status == .failed {
            let reason = reader.error?.localizedDescription ?? "Unknown reader error."
            throw AudioExtractorError.readerFailed(reason)
        }

        return samples
    }
}
