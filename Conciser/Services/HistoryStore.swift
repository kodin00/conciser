import Foundation

/// Plain (non-observable) persistence for meeting history, backed by a single
/// JSON file in the app's sandboxed Application Support directory. Never
/// throws — callers get best-effort behavior with empty/no-op fallbacks.
enum HistoryStore {
    private static let subdirectoryName = "Conciser"
    private static let fileName = "history.json"

    private static var fileURL: URL? {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }

        let directory = appSupport.appendingPathComponent(subdirectoryName, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            print("HistoryStore: failed to create directory: \(error)")
            return nil
        }

        return directory.appendingPathComponent(fileName, isDirectory: false)
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        return encoder
    }

    /// All saved meetings, NEWEST FIRST. Returns [] if none or on any error (never throws).
    static func load() -> [MeetingRecord] {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let records = try decoder.decode([MeetingRecord].self, from: data)
            return records.sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("HistoryStore: failed to load history: \(error)")
            return []
        }
    }

    /// Overwrites the stored list with `records` (expected newest-first). Best-effort; never throws.
    static func save(_ records: [MeetingRecord]) {
        guard let url = fileURL else {
            print("HistoryStore: failed to resolve file URL for save")
            return
        }

        do {
            let data = try encoder.encode(records)
            try data.write(to: url, options: .atomic)
        } catch {
            print("HistoryStore: failed to save history: \(error)")
        }
    }
}
