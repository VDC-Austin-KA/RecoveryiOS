import SwiftUI
import AuthenticationServices

/// AI connection options, cheapest first: on-device (free), OpenRouter sign-in (free models),
/// hand-off to the user's Claude/ChatGPT subscription, then optional paid API keys.
struct AIAssistantSettings: View {
    @Environment(AppServices.self) private var services
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @AppStorage(AIProviderKind.storageKey) private var providerRaw = AIProviderKind.automatic.rawValue
    @State private var openRouterSignedIn = Keychain.string(for: APIKeyAccount.openRouter) != nil
    @State private var signingIn = false
    @State private var message: String?
    @State private var anthropicKey = Keychain.string(for: APIKeyAccount.anthropic) ?? ""
    @State private var openAIKey = Keychain.string(for: APIKeyAccount.openAI) ?? ""
    @State private var keysSaved = false

    var body: some View {
        Section {
            Picker("Use", selection: $providerRaw) {
                ForEach(AIProviderKind.allCases) { Text($0.displayName).tag($0.rawValue) }
            }
            LabeledContent("Active now", value: services.llmClient.displayName)
            LabeledContent("Apple Intelligence", value: OnDeviceLLM.status)
        } header: {
            Text("AI assistant")
        } footer: {
            Text("Automatic uses your own key if you added one, then OpenRouter, then Apple Intelligence on this iPhone, and otherwise a private offline companion.")
        }
        .onChange(of: providerRaw) { services.settingsRevision += 1 }

        Section {
            if openRouterSignedIn {
                Label("Signed in to OpenRouter", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                Button("Sign out", role: .destructive) {
                    Keychain.setString(nil, for: APIKeyAccount.openRouter)
                    openRouterSignedIn = false
                    services.settingsRevision += 1
                }
            } else {
                Button {
                    Task { await signInWithOpenRouter() }
                } label: {
                    HStack {
                        Label("Sign in with OpenRouter", systemImage: "person.badge.key.fill")
                        if signingIn { Spacer(); ProgressView() }
                    }
                }
                .disabled(signingIn)
            }
            if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
        } header: {
            Text("Free cloud AI")
        } footer: {
            Text("Create or use a free OpenRouter account (Google, GitHub or email). The app is connected automatically and uses free models — no API key to copy, no card required.")
        }

        Section {
            ForEach(SubscriptionHandoff.allCases) { target in
                Label(target.title, systemImage: target.icon)
            }
        } header: {
            Text("Have Claude Pro or ChatGPT Plus?")
        } footer: {
            Text("Anthropic and OpenAI don't allow other apps to sign in with consumer subscriptions. Instead, tap “Continue in Claude/ChatGPT” in the Assistant's menu: your conversation opens in the official app, running on your own subscription.")
        }

        Section {
            SecureField("Claude API key (sk-ant-…)", text: $anthropicKey)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("OpenAI API key (sk-…)", text: $openAIKey)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button(keysSaved ? "Saved to Keychain ✓" : "Save keys") {
                Keychain.setString(anthropicKey, for: APIKeyAccount.anthropic)
                Keychain.setString(openAIKey, for: APIKeyAccount.openAI)
                services.settingsRevision += 1
                keysSaved = true
            }
            Link("Get a Claude API key", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
            Link("Get an OpenAI API key", destination: URL(string: "https://platform.openai.com/api-keys")!)
        } header: {
            Text("Advanced: your own API key")
        } footer: {
            Text("Optional and billed by the provider. Keys can be filled from your password manager and stay in this iPhone's Keychain.")
        }
        .onChange(of: anthropicKey) { keysSaved = false }
        .onChange(of: openAIKey) { keysSaved = false }
    }

    private func signInWithOpenRouter() async {
        signingIn = true
        message = nil
        defer { signingIn = false }
        let verifier = OpenRouterAuth.makeVerifier()
        do {
            let callback = try await webAuthenticationSession.authenticate(
                using: OpenRouterAuth.authorizationURL(challenge: OpenRouterAuth.challenge(for: verifier)),
                callbackURLScheme: OpenRouterAuth.callbackScheme
            )
            guard let code = OpenRouterAuth.code(from: callback) else { throw URLError(.badServerResponse) }
            let key = try await OpenRouterAuth.exchange(code: code, verifier: verifier)
            Keychain.setString(key, for: APIKeyAccount.openRouter)
            openRouterSignedIn = true
            services.settingsRevision += 1
            message = "Connected. The assistant now uses free OpenRouter models."
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            message = nil
        } catch {
            message = "Sign-in didn't finish: \(error.localizedDescription)"
        }
    }
}
