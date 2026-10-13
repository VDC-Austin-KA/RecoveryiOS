import Foundation

/// Hands the conversation to the official Claude or ChatGPT app/site, where it runs on the user's
/// own Pro/Plus subscription. Third-party apps may not sign in with consumer subscriptions
/// (Anthropic prohibits routing requests through Free/Pro/Max credentials), so this is the
/// supported way to use a subscription. The prompt is also copied in case the link only opens the app.
enum SubscriptionHandoff: String, CaseIterable, Identifiable {
    case claude
    case chatGPT

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claude: "Continue in Claude"
        case .chatGPT: "Continue in ChatGPT"
        }
    }

    var icon: String {
        switch self {
        case .claude: "sparkles"
        case .chatGPT: "bubble.left.and.bubble.right"
        }
    }

    /// Universal link: opens the installed app when present, otherwise the website.
    func url(prompt: String) -> URL {
        var components = URLComponents(string: self == .claude ? "https://claude.ai/new" : "https://chatgpt.com/")!
        // Links break well before model limits; the full prompt is on the clipboard anyway.
        components.queryItems = [URLQueryItem(name: "q", value: String(prompt.prefix(1_800)))]
        return components.url!
    }

    static func prompt(pathway: RecoveryPathway, history: [ChatTurn]) -> String {
        let transcript = history.suffix(6)
            .map { "\($0.role == .user ? "Me" : "Companion"): \($0.content)" }
            .joined(separator: "\n\n")
        let intro = """
        Please act as my supportive, non-judgmental, trauma-informed recovery companion \
        (approach: \(pathway.title)). Keep replies short and practical.
        """
        guard !transcript.isEmpty else { return intro + "\n\nI'd like some support today." }
        return intro + "\n\nHere's our conversation so far — please continue from my last message:\n\n" + transcript
    }
}
