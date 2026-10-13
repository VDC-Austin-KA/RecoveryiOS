import Foundation

struct ChatTurn: Codable, Hashable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    var role: Role
    var content: String
}

protocol LLMClient {
    var displayName: String { get }
    func complete(system: String, messages: [ChatTurn]) async throws -> String
}

enum LLMError: LocalizedError {
    case http(status: Int, body: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case let .http(status, body): "AI provider returned HTTP \(status): \(body)"
        case .emptyResponse: "AI provider returned an empty response."
        }
    }

    static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw LLMError.http(status: http.statusCode, body: String(decoding: data.prefix(300), as: UTF8.self))
        }
    }
}

enum LLMFactory {
    static func make(configuration: AppConfiguration, preference: AIProviderKind) -> any LLMClient {
        let openAIKey = Keychain.string(for: APIKeyAccount.openAI) ?? configuration.openAIKey
        let anthropicKey = Keychain.string(for: APIKeyAccount.anthropic) ?? configuration.anthropicKey
        switch preference {
        case .mock:
            break
        case .openAI:
            if let openAIKey { return OpenAIClient(apiKey: openAIKey, model: configuration.openAIModel) }
        case .anthropic:
            if let anthropicKey { return AnthropicClient(apiKey: anthropicKey, model: configuration.anthropicModel) }
        case .automatic:
            if let anthropicKey { return AnthropicClient(apiKey: anthropicKey, model: configuration.anthropicModel) }
            if let openAIKey { return OpenAIClient(apiKey: openAIKey, model: configuration.openAIModel) }
        }
        return MockLLMClient()
    }
}

// MARK: - OpenAI

private struct OpenAIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
    }
    let choices: [Choice]
}

struct OpenAIClient: LLMClient {
    let apiKey: String
    let model: String
    var session: URLSession = .shared

    var displayName: String { "OpenAI · \(model)" }

    func complete(system: String, messages: [ChatTurn]) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let turns: [[String: String]] = [["role": "system", "content": system]]
            + messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        let body: [String: Any] = ["model": model, "messages": turns, "temperature": 0.7]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try LLMError.validate(response, data: data)
        let text = try JSONDecoder().decode(OpenAIResponse.self, from: data).choices.first?.message.content ?? ""
        guard !text.isEmpty else { throw LLMError.emptyResponse }
        return text
    }
}

// MARK: - Anthropic

private struct AnthropicResponse: Decodable {
    struct Block: Decodable {
        let type: String
        let text: String?
    }
    let content: [Block]
}

struct AnthropicClient: LLMClient {
    let apiKey: String
    let model: String
    var session: URLSession = .shared

    var displayName: String { "Claude · \(model)" }

    func complete(system: String, messages: [ChatTurn]) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        // The Messages API requires the conversation to open with a user turn.
        let turns = messages.drop { $0.role == .assistant }.map { ["role": $0.role.rawValue, "content": $0.content] }
        let body: [String: Any] = ["model": model, "max_tokens": 1024, "system": system, "messages": Array(turns)]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try LLMError.validate(response, data: data)
        let text = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            .content.compactMap { $0.type == "text" ? $0.text : nil }
            .joined()
        guard !text.isEmpty else { throw LLMError.emptyResponse }
        return text
    }
}

// MARK: - Offline mock

struct MockLLMClient: LLMClient {
    var latency: Duration = .milliseconds(450)

    var displayName: String { "Offline companion" }

    func complete(system: String, messages: [ChatTurn]) async throws -> String {
        try? await Task.sleep(for: latency)
        let lastUser = messages.last { $0.role == .user }?.content ?? ""
        return MockResponder.reply(system: system, to: lastUser)
    }
}
