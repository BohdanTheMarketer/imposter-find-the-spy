import Foundation

/// Generates a custom "Imposter" word pack from a free-text prompt using the OpenAI API.
/// Uses `gpt-4o-mini` — a low-cost model that's more than sufficient for short word-list generation.
enum OpenAIWordPackService {

    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidPrompt
        case network(Error)
        case httpStatus(Int, String)
        case emptyResponse
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return String(localized: "custom_pack.error_missing_key")
            case .invalidPrompt:
                return String(localized: "custom_pack.error_invalid_prompt")
            case .network:
                return String(localized: "custom_pack.error_network")
            case .httpStatus(let code, _):
                if code == 401 {
                    return String(localized: "custom_pack.error_unauthorized")
                }
                if code == 429 {
                    return String(localized: "custom_pack.error_rate_limited")
                }
                return String(localized: "custom_pack.error_network")
            case .emptyResponse, .decodingFailed:
                return String(localized: "custom_pack.error_generation_failed")
            }
        }
    }

    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private static let model = "gpt-4o-mini"

    /// Reads the OpenAI API key injected at build time via `Secrets.xcconfig`.
    /// A "Generate Secrets" build phase writes `GeneratedSecrets.swift` (gitignored) on every build.
    private static var apiKey: String? {
        let key = GeneratedSecrets.openAIAPIKey
        guard !key.isEmpty, !key.contains("your-openai-api-key-here") else {
            return nil
        }
        return key
    }

    static func generatePack(prompt: String) async throws -> Category {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw ServiceError.invalidPrompt
        }
        guard let apiKey else {
            throw ServiceError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: trimmedPrompt)
            ],
            responseFormat: ResponseFormat(type: "json_object"),
            temperature: 0.9
        )

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw ServiceError.decodingFailed
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ServiceError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.emptyResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.httpStatus(httpResponse.statusCode, message)
        }

        let completion: ChatCompletionResponse
        do {
            completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            throw ServiceError.decodingFailed
        }

        guard let content = completion.choices.first?.message.content,
              let contentData = content.data(using: .utf8) else {
            throw ServiceError.emptyResponse
        }

        let payload: GeneratedPackPayload
        do {
            payload = try JSONDecoder().decode(GeneratedPackPayload.self, from: contentData)
        } catch {
            throw ServiceError.decodingFailed
        }

        let cleanedWords = payload.words
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleanedWords.isEmpty else {
            throw ServiceError.emptyResponse
        }

        // Keep hints aligned with words by index (GameEngine looks hints up positionally).
        var hints = payload.imposterHints ?? []
        if hints.count < cleanedWords.count {
            hints.append(contentsOf: Array(repeating: "", count: cleanedWords.count - hints.count))
        } else if hints.count > cleanedWords.count {
            hints = Array(hints.prefix(cleanedWords.count))
        }

        let name = payload.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = payload.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let icon = payload.icon.trimmingCharacters(in: .whitespacesAndNewlines)

        return Category(
            name: name.isEmpty ? trimmedPrompt : name,
            icon: icon.isEmpty ? "sparkles" : icon,
            description: description.isEmpty ? trimmedPrompt : description,
            words: cleanedWords,
            imposterHints: hints,
            isPremium: false,
            isCustom: true
        )
    }

    private static let systemPrompt = """
    You create word packs for "Imposter", a party guessing game similar to Spyfair/Word Wolf. \
    Given a short user prompt describing a theme, generate a themed word pack.

    Respond with ONLY a strict JSON object (no markdown, no commentary) with exactly these keys:
    - "name": a short, catchy Title Case category name (max 24 characters).
    - "icon": a single valid SF Symbols name (e.g. "gamecontroller.fill", "globe", "leaf.fill") that best matches the theme.
    - "description": one short, upbeat sentence (max 90 characters) describing the pack, in the same playful tone as: \
    "Easygoing fun with laughs and a bit of chaos" or "Tasty topics, but say the wrong thing and you're toast!".
    - "words": a JSON array of 30 to 50 short secret words or phrases (1-3 words each) that fit the theme. \
    No duplicates. Keep language appropriate unless the prompt explicitly asks for mature/adult content.
    - "imposterHints": a JSON array with EXACTLY the same length and order as "words". Each entry is a short \
    1-3 word clue related to that specific word, useful enough to let the imposter bluff but without giving \
    the exact word away.
    """

    // MARK: - Request/response models

    private struct ChatCompletionRequest: Encodable {
        let model: String
        let messages: [ChatMessage]
        let responseFormat: ResponseFormat
        let temperature: Double

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature
            case responseFormat = "response_format"
        }
    }

    private struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    private struct ResponseFormat: Encodable {
        let type: String
    }

    private struct ChatCompletionResponse: Decodable {
        struct Choice: Decodable {
            let message: ChatMessage
        }
        let choices: [Choice]
    }

    private struct GeneratedPackPayload: Decodable {
        let name: String
        let icon: String
        let description: String
        let words: [String]
        let imposterHints: [String]?
    }
}
