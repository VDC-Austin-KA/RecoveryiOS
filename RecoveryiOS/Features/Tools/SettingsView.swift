import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppServices.self) private var services
    @Query private var profiles: [SobrietyProfile]
    @AppStorage("pathway") private var pathwayRaw = RecoveryPathway.twelveStep.rawValue
    @AppStorage(AIProviderKind.storageKey) private var providerRaw = AIProviderKind.automatic.rawValue
    @AppStorage("journalLockEnabled") private var journalLockEnabled = true
    @State private var openAIKey = Keychain.string(for: APIKeyAccount.openAI) ?? ""
    @State private var anthropicKey = Keychain.string(for: APIKeyAccount.anthropic) ?? ""
    @State private var keysSaved = false

    var body: some View {
        Form {
            if let profile = profiles.first {
                Section("Sobriety") {
                    NavigationLink { SobrietySettingsView(profile: profile) } label: {
                        LabeledContent("Sober since", value: profile.startDate.formatted(date: .abbreviated, time: .omitted))
                    }
                }
            }

            Section {
                Picker("Pathway", selection: $pathwayRaw) {
                    ForEach(RecoveryPathway.allCases) { path in
                        VStack(alignment: .leading) {
                            Text(path.title)
                            Text(path.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(path.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Recovery pathway")
            } footer: {
                Text("Shapes the AI assistant's language, daily affirmations and grounding prompts.")
            }

            Section {
                Picker("Provider", selection: $providerRaw) {
                    ForEach(AIProviderKind.allCases) { Text($0.displayName).tag($0.rawValue) }
                }
                SecureField("Anthropic API key", text: $anthropicKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("OpenAI API key", text: $openAIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(keysSaved ? "Saved to Keychain ✓" : "Save keys") {
                    Keychain.setString(anthropicKey, for: APIKeyAccount.anthropic)
                    Keychain.setString(openAIKey, for: APIKeyAccount.openAI)
                    services.settingsRevision += 1
                    keysSaved = true
                }
                LabeledContent("Active", value: services.llmClient.displayName)
            } header: {
                Text("AI assistant (bring your own key)")
            } footer: {
                Text("Keys are stored in the iOS Keychain on this device only. With no key, a private offline companion answers instead.")
            }
            .onChange(of: providerRaw) { services.settingsRevision += 1 }
            .onChange(of: anthropicKey) { keysSaved = false }
            .onChange(of: openAIKey) { keysSaved = false }

            Section {
                Toggle("Require Face ID for journal", isOn: $journalLockEnabled)
            } header: {
                Text("Privacy")
            } footer: {
                Text("Journal entries are always encrypted with AES-GCM using a key kept in the Keychain.")
            }

            Section("Meeting data") {
                ForEach(Fellowship.allCases) { fellowship in
                    LabeledContent(fellowship.fullName, value: services.configuration.meetingFeeds[fellowship] == nil ? "Sample data" : "Live feed")
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
            }
        }
        .navigationTitle("Settings")
    }
}

struct SobrietySettingsView: View {
    @Bindable var profile: SobrietyProfile
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    var body: some View {
        Form {
            Section("Sobriety date") {
                DatePicker("Sober since", selection: $profile.startDate, in: ...Date.now)
            }
            Section {
                TextField("Daily spend", value: $profile.dailySpend, format: .currency(code: currencyCode))
                    .keyboardType(.decimalPad)
                Stepper(value: $profile.dailyHours, in: 0...24, step: 0.5) {
                    Text("Hours per day: \(profile.dailyHours.formatted(.number.precision(.fractionLength(0...1))))")
                }
            } header: {
                Text("Savings calculator")
            } footer: {
                Text("Roughly how much money and time a typical using day cost you.")
            }
            Section {
                Button("Reset counter to now", role: .destructive) { confirmReset = true }
            } footer: {
                Text("A reset is a fresh start, not a failure. Your journal and plans are kept.")
            }
        }
        .navigationTitle("Sobriety")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
        .confirmationDialog("Reset your sobriety date to now?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                profile.startDate = .now
                profile.celebratedMilestones = []
            }
        }
    }
}
