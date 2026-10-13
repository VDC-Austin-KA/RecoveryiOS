import Foundation
import CryptoKit

/// OpenRouter: the user signs in with their own OpenRouter account (Google/GitHub/email) and the
/// app receives an API key via OAuth PKCE — no copy/paste. Free models (":free") cost nothing.
/// Docs: https://openrouter.ai/docs/use-cases/oauth-pkce
enum OpenRouterAuth {
    static let callbackScheme = "recoveryios"
    static let callbackURL = "recoveryios://openrouter"

    static func makeVerifier() -> String {
        SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }.base64URLEncoded
    }

    static func challenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
    }

    static func authorizationURL(challenge: String) -> URL {
        var components = URLComponents(string: "https://openrouter.ai/auth")!
        components.queryItems = [
            URLQueryItem(name: "callback_url", value: callbackURL),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        return components.url!
    }

    static func code(from callback: URL) -> String? {
        URLComponents(url: callback, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "code" }?.value
    }

    /// Exchanges the one-time code for the user's API key.
    static func exchange(code: String, verifier: String, session: URLSession = .shared) async throws -> String {
        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/auth/keys")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "code": code, "code_verifier": verifier, "code_challenge_method": "S256",
        ])
        let (data, response) = try await session.data(for: request)
        try LLMError.validate(response, data: data)
        struct KeyResponse: Decodable { let key: String }
        return try JSONDecoder().decode(KeyResponse.self, from: data).key
    }
}

private struct OpenRouterModelList: Decodable {
    struct Model: Decodable { let id: String }
    let data: [Model]
}

struct OpenRouterClient: LLMClient {
    let apiKey: String
    var session: URLSession = .shared

    static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    static let modelDefaultsKey = "openRouterModel"
    /// Preferred free chat models; the live model list decides what's actually available.
    static let preferredFreeModels = [
        "google/gemma-4-31b-it:free",
        "nvidia/nemotron-3-super-120b-a12b:free",
        "thinkingmachines/inkling:free",
    ]

    var displayName: String {
        "OpenRouter · \(UserDefaults.standard.string(forKey: Self.modelDefaultsKey) ?? "free model")"
    }

    func complete(system: String, messages: [ChatTurn]) async throws -> String {
        let model = try await Self.resolveModel(session: session)
        let client = OpenAIClient(
            apiKey: apiKey,
            model: model,
            session: session,
            endpoint: Self.endpoint,
            extraHeaders: ["HTTP-Referer": "https://github.com/VDC-Austin-KA/RecoveryiOS", "X-Title": "Recovery"]
        )
        do {
            return try await client.complete(system: system, messages: messages)
        } catch {
            // Free models rotate; re-pick from the live list on the next request.
            UserDefaults.standard.removeObject(forKey: Self.modelDefaultsKey)
            throw error
        }
    }

    static func resolveModel(session: URLSession) async throws -> String {
        if let cached = UserDefaults.standard.string(forKey: modelDefaultsKey) { return cached }
        let (data, _) = try await session.data(from: URL(string: "https://openrouter.ai/api/v1/models")!)
        let free = try JSONDecoder().decode(OpenRouterModelList.self, from: data).data.map(\.id).filter { $0.hasSuffix(":free") }
        let model = preferredFreeModels.first { free.contains($0) } ?? free.first ?? preferredFreeModels[0]
        UserDefaults.standard.set(model, forKey: modelDefaultsKey)
        return model
    }
}

extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
