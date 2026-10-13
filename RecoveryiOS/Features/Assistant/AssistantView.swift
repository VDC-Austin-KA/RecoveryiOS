import SwiftUI
import SwiftData

struct AssistantView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @Query(sort: \ChatMessageRecord.date) private var messages: [ChatMessageRecord]
    @AppStorage("pathway") private var pathwayRaw = RecoveryPathway.twelveStep.rawValue
    @State private var vm = AssistantViewModel()
    @State private var confirmClear = false
    @FocusState private var inputFocused: Bool

    private var pathway: RecoveryPathway { RecoveryPathway(rawValue: pathwayRaw) ?? .twelveStep }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            PathwayHeader(pathway: pathway, providerName: services.llmClient.displayName)
                            if messages.isEmpty { starters }
                            ForEach(messages) { message in
                                MessageBubble(message: message).id(message.id)
                            }
                            if vm.isThinking {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Thinking…").foregroundStyle(.secondary)
                                }
                                .id("thinking")
                            }
                            if let notice = vm.notice {
                                Label(notice, systemImage: "wifi.slash").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: messages.count) {
                        if let last = messages.last?.id {
                            withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                        }
                    }
                    .onChange(of: vm.isThinking) {
                        if vm.isThinking { withAnimation { proxy.scrollTo("thinking", anchor: .bottom) } }
                    }
                }
                inputBar
            }
            .navigationTitle("Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { UrgeToolbarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Recovery pathway", selection: $pathwayRaw) {
                            ForEach(RecoveryPathway.allCases) { path in
                                Label(path.title, systemImage: path.icon).tag(path.rawValue)
                            }
                        }
                        Divider()
                        Button("Clear conversation", role: .destructive) { confirmClear = true }
                    } label: {
                        Label("Pathway", systemImage: pathway.icon)
                    }
                }
            }
            .confirmationDialog("Clear the whole conversation?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear", role: .destructive) {
                    for message in messages { context.delete(message) }
                }
            }
        }
    }

    private var starters: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try asking").font(.caption).foregroundStyle(.secondary)
            ForEach(AssistantViewModel.starters, id: \.self) { starter in
                Button(starter) { send(starter) }
                    .buttonStyle(.bordered)
                    .tint(.teal)
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Share what's on your mind…", text: $vm.draft, axis: .vertical)
                .lineLimit(1...5)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                .focused($inputFocused)
            Button {
                send(vm.draft)
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 34))
            }
            .disabled(vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isThinking)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func send(_ text: String) {
        let history = messages
        let client = services.llmClient
        Task { await vm.send(text, history: history, pathway: pathway, client: client, context: context) }
    }
}

struct PathwayHeader: View {
    let pathway: RecoveryPathway
    let providerName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: pathway.icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.teal.gradient, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(pathway.title).font(.headline)
                Text(pathway.summary).font(.caption).foregroundStyle(.secondary)
                Text(providerName).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .card()
    }
}

struct MessageBubble: View {
    let message: ChatMessageRecord

    var body: some View {
        let isUser = message.role == .user
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(LocalizedStringKey(message.content))
                .padding(12)
                .background(isUser ? Color.teal : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(isUser ? Color.white : Color.primary)
                .textSelection(.enabled)
            if !isUser { Spacer(minLength: 40) }
        }
    }
}
