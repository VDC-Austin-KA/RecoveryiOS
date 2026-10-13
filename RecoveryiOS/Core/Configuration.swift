import Foundation

/// Runtime configuration. Environment variables (Xcode scheme / CI) win over
/// `Configuration.plist`; empty values and `YOUR_…` placeholders count as unset.
struct AppConfiguration {
    var openAIKey: String?
    var anthropicKey: String?
    var openAIModel = "gpt-4o-mini"
    var anthropicModel = "claude-sonnet-5-5"
    var meetingFeeds: [Fellowship: URL] = [:]

    static func load(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppConfiguration {
        var plist: [String: Any] = [:]
        if let url = bundle.url(forResource: "Configuration", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            plist = dict
        }

        func value(_ key: String) -> String? {
            let raw = environment[key] ?? (plist[key] as? String)
            guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty, !trimmed.hasPrefix("YOUR_") else { return nil }
            return trimmed
        }

        var config = AppConfiguration(openAIKey: value("OPENAI_API_KEY"), anthropicKey: value("ANTHROPIC_API_KEY"))
        if let model = value("OPENAI_MODEL") { config.openAIModel = model }
        if let model = value("ANTHROPIC_MODEL") { config.anthropicModel = model }
        for fellowship in Fellowship.allCases {
            if let raw = value(fellowship.feedConfigKey), let url = URL(string: raw) {
                config.meetingFeeds[fellowship] = url
            }
        }
        return config
    }
}

enum AIProviderKind: String, CaseIterable, Identifiable {
    case automatic, anthropic, openAI, mock

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: "Automatic"
        case .anthropic: "Anthropic (Claude)"
        case .openAI: "OpenAI"
        case .mock: "Offline companion"
        }
    }

    static let storageKey = "aiProvider"

    static var stored: AIProviderKind {
        AIProviderKind(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .automatic
    }
}

enum APIKeyAccount {
    static let openAI = "OPENAI_API_KEY"
    static let anthropic = "ANTHROPIC_API_KEY"
}
