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

        let rawName = payload.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawDescription = payload.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let icon = payload.icon.trimmingCharacters(in: .whitespacesAndNewlines)

        // Enforce the length caps in code too, since the model doesn't always honor the prompt exactly.
        let name = truncate(rawName, to: maxNameLength)
        let description = truncate(rawDescription, to: maxDescriptionLength)

        return Category(
            name: name.isEmpty ? truncate(trimmedPrompt, to: maxNameLength) : name,
            icon: icon.isEmpty ? "sparkles" : icon,
            description: description.isEmpty ? truncate(trimmedPrompt, to: maxDescriptionLength) : description,
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
    - "name": a SHORT, catchy Title Case category name. HARD LIMIT: 18 characters including spaces — \
    shorter is better, it must fit on one line of a small card. Prefer 1-2 words (e.g. "Movie Night", "Superpowers").
    - "icon": a single valid SF Symbols name (e.g. "gamecontroller.fill", "globe", "leaf.fill") that best matches the theme.
    - "description": one SHORT, upbeat sentence. HARD LIMIT: 48 characters including spaces — it must fit on a \
    single line of a small card without wrapping or being cut off. Same playful tone as: \
    "Laughs and a bit of chaos" or "Say the wrong thing, you're toast!".
    - "words": a JSON array of 30 to 50 short secret words or phrases (1-3 words each) that fit the theme. \
    No duplicates.
    - "imposterHints": a JSON array with EXACTLY the same length and order as "words". Each entry is a short \
    1-3 word clue related to that specific word, useful enough to let the imposter bluff but without giving \
    the exact word away.

    Content policy (always enforced, regardless of what the user's prompt asks for): this app is rated for a \
    general audience and distributed on the Apple App Store, so the "name", "description", "words", and \
    "imposterHints" must NEVER include sexual or suggestive content, nudity, hate speech, harassment, \
    self-harm, graphic violence, illegal drugs, or other content that would violate Apple App Store Review \
    Guideline 1.1 (Objectionable Content). If the user's prompt requests or implies any such theme, IGNORE \
    that part of the request and instead generate a safe, family-friendly pack loosely inspired by the \
    non-objectionable parts of the prompt (or a generic fun theme if none remain). Never refuse outright — \
    always return a valid, appropriate pack in the required JSON format.
    """

    /// Hard caps enforced in code as a safety net — the model is asked to stay within these limits, but
    /// LLM output length isn't guaranteed, so custom pack cards would otherwise sometimes overflow their layout.
    private static let maxNameLength = 18
    private static let maxDescriptionLength = 48

    private static func truncate(_ text: String, to maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let cut = text.prefix(maxLength - 1).trimmingCharacters(in: .whitespaces)
        return "\(cut)…"
    }

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
