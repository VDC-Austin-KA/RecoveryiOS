import Foundation
import SwiftData
import Observation

@Observable
final class AssistantViewModel {
    var draft = ""
    var isThinking = false
    var notice: String?

    static let starters = [
        "I'm feeling an urge right now",
        "Help me with a resentment",
        "Guide me through a nightly review",
        "What can I be grateful for today?",
    ]

    /// Persists the user turn, asks the configured model, and falls back to the offline
    /// responder if the provider fails (no signal, bad key, rate limit…).
    @MainActor
    func send(_ text: String, history: [ChatMessageRecord], pathway: RecoveryPathway, client: any LLMClient, context: ModelContext) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return }
        draft = ""
        context.insert(ChatMessageRecord(role: .user, content: trimmed))
        isThinking = true
        defer { isThinking = false }

        let turns = history.suffix(20).map { ChatTurn(role: $0.role, content: $0.content) }
            + [ChatTurn(role: .user, content: trimmed)]
        let reply: String
        do {
            reply = try await client.complete(system: pathway.systemPrompt, messages: turns)
            notice = nil
        } catch {
            reply = MockResponder.reply(system: pathway.systemPrompt, to: trimmed)
            notice = "Couldn't reach \(client.displayName) — showing an offline response."
        }
        context.insert(ChatMessageRecord(role: .assistant, content: reply))
    }
}
