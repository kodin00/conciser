import Foundation

/// Errors surfaced by `VerdictService`.
enum VerdictError: LocalizedError {
    case emptyAPIKey
    case httpError(status: Int, body: String)
    case missingCandidate
    case decodeFailure(String)

    var errorDescription: String? {
        switch self {
        case .emptyAPIKey:
            return "No Gemini API key is set. Add one in Settings."
        case .httpError(let status, let body):
            let snippet = body.count > 400 ? String(body.prefix(400)) + "…" : body
            return "Gemini request failed (HTTP \(status)): \(snippet)"
        case .missingCandidate:
            return "Gemini returned no usable response."
        case .decodeFailure(let detail):
            return "Could not parse Gemini's response: \(detail)"
        }
    }
}

/// Calls the Google Gemini REST API to produce a structured `Verdict` from a
/// meeting transcript.
struct VerdictService {
    private let endpoint = URL(
        string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    )!

    /// - Parameter language: human name to answer in, e.g. "Indonesian" or "English".
    func generateVerdict(transcript: String, apiKey: String, language: String) async throws -> Verdict {
        guard !apiKey.isEmpty else {
            throw VerdictError.emptyAPIKey
        }

        let prompt = """
        You are an assistant that reviews meeting transcripts. Read the following meeting \
        transcript and produce:
        - a concise summary of what was discussed,
        - a list of the key points raised,
        - the overall sentiment of the meeting,
        - an overall verdict/assessment of the meeting (e.g. was it productive, were decisions \
        made, are there risks or follow-ups).

        Answer entirely in \(language).

        Transcript:
        \(transcript)
        """

        let requestBody = GenerateContentRequest(
            contents: [
                Content(role: "user", parts: [Part(text: prompt)])
            ],
            generationConfig: GenerationConfig(
                responseMimeType: "application/json",
                responseSchema: Self.verdictSchema
            )
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw VerdictError.httpError(status: httpResponse.statusCode, body: body)
        }

        let decoded: GenerateContentResponse
        do {
            decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        } catch {
            throw VerdictError.decodeFailure("unexpected response shape (\(error.localizedDescription))")
        }

        guard let text = decoded.candidates?.first?.content?.parts?.first?.text else {
            throw VerdictError.missingCandidate
        }

        guard let innerData = text.data(using: .utf8) else {
            throw VerdictError.decodeFailure("response text was not valid UTF-8")
        }

        do {
            return try JSONDecoder().decode(Verdict.self, from: innerData)
        } catch {
            throw VerdictError.decodeFailure(error.localizedDescription)
        }
    }

    // MARK: - Response schema

    private static let verdictSchema = ResponseSchema(
        type: "object",
        properties: [
            "summary": ResponseSchema(type: "string", description: "A concise summary of the meeting."),
            "keyPoints": ResponseSchema(
                type: "array",
                description: "The key points raised during the meeting.",
                items: ResponseSchema(type: "string")
            ),
            "sentiment": ResponseSchema(
                type: "string",
                description: "The overall sentiment of the meeting.",
                enumValues: ["Positive", "Neutral", "Negative", "Mixed"]
            ),
            "verdictText": ResponseSchema(
                type: "string",
                description: "An overall verdict/assessment of the meeting."
            )
        ],
        required: ["summary", "keyPoints", "sentiment", "verdictText"]
    )

    // MARK: - Request/response Codable models

    private struct GenerateContentRequest: Encodable {
        let contents: [Content]
        let generationConfig: GenerationConfig
    }

    private struct Content: Encodable {
        let role: String
        let parts: [Part]
    }

    private struct Part: Codable {
        let text: String
    }

    private struct GenerationConfig: Encodable {
        let responseMimeType: String
        let responseSchema: ResponseSchema
    }

    /// A (subset of the) Gemini/OpenAPI Schema object used to describe
    /// `responseSchema`. Recursive, so it must be a class or indirect enum;
    /// a struct with an indirect-boxed dictionary is simplest here.
    private final class ResponseSchema: Encodable {
        let type: String
        let description: String?
        let properties: [String: ResponseSchema]?
        let required: [String]?
        let items: ResponseSchema?
        let enumValues: [String]?

        init(
            type: String,
            description: String? = nil,
            properties: [String: ResponseSchema]? = nil,
            required: [String]? = nil,
            items: ResponseSchema? = nil,
            enumValues: [String]? = nil
        ) {
            self.type = type
            self.description = description
            self.properties = properties
            self.required = required
            self.items = items
            self.enumValues = enumValues
        }

        enum CodingKeys: String, CodingKey {
            case type, description, properties, required, items
            case enumValues = "enum"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encodeIfPresent(properties, forKey: .properties)
            try container.encodeIfPresent(required, forKey: .required)
            try container.encodeIfPresent(items, forKey: .items)
            try container.encodeIfPresent(enumValues, forKey: .enumValues)
        }
    }

    private struct GenerateContentResponse: Decodable {
        let candidates: [Candidate]?
    }

    private struct Candidate: Decodable {
        let content: ResponseContent?
    }

    private struct ResponseContent: Decodable {
        let parts: [Part]?
    }
}
