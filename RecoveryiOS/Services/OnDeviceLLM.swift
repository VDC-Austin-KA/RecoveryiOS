import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple Intelligence's on-device model (iOS 26+, Apple Intelligence-capable iPhones):
/// free, private, works offline, no account needed.
enum OnDeviceLLM {
    static func makeClient() -> (any LLMClient)? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable {
            return AppleIntelligenceClient()
        }
        #endif
        return nil
    }

    static var status: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return "Ready"
            case .unavailable(.deviceNotEligible): return "Not supported on this iPhone"
            case .unavailable(.appleIntelligenceNotEnabled): return "Turn on Apple Intelligence in iOS Settings"
            case .unavailable(.modelNotReady): return "Model is still downloading"
            case .unavailable: return "Unavailable"
            @unknown default: return "Unavailable"
            }
        }
        #endif
        return "Requires iOS 26"
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
struct AppleIntelligenceClient: LLMClient {
    var displayName: String { "Apple Intelligence (on-device)" }

    func complete(system: String, messages: [ChatTurn]) async throws -> String {
        // The on-device context window is small, so only recent turns are included.
        let recent = messages.suffix(8)
        let history = recent.dropLast()
            .map { "\($0.role == .user ? "User" : "Companion"): \($0.content)" }
            .joined(separator: "\n\n")
        let latest = recent.last?.content ?? ""
        let prompt = history.isEmpty ? latest : "Conversation so far:\n\(history)\n\nUser: \(latest)"
        let session = LanguageModelSession(instructions: system)
        return try await session.respond(to: prompt).content
    }
}
#endif
