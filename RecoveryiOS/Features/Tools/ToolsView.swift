import SwiftUI
import SwiftData

struct ToolsView: View {
    @Environment(AppServices.self) private var services

    var body: some View {
        NavigationStack {
            List {
                Section("Recovery work") {
                    NavigationLink { JournalLockGate { StepWorkListView() } } label: {
                        Label("12-Step Work", systemImage: "stairs")
                    }
                    NavigationLink { JournalLockGate { NightlyInventoryView() } } label: {
                        Label("Nightly Inventory", systemImage: "moon.stars.fill")
                    }
                    NavigationLink { JournalLockGate { GratitudeJournalView() } } label: {
                        Label("Gratitude Journal", systemImage: "heart.text.square.fill")
                    }
                    NavigationLink { JournalLockGate { JournalHistoryView() } } label: {
                        Label("Journal History", systemImage: "book.fill")
                    }
                }

                Section("Support") {
                    NavigationLink { EmergencyContactsView() } label: {
                        Label("Sponsor & Emergency Contacts", systemImage: "person.crop.circle.badge.exclamationmark")
                    }
                    Button {
                        services.showUrgeSupport = true
                    } label: {
                        Label("Urge Support", systemImage: "lifepreserver.fill").foregroundStyle(.red)
                    }
                }

                Section("Settings") {
                    NavigationLink { SettingsView() } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }

                Section {
                    Text("Recovery is a peer-support companion, not a substitute for medical or mental-health care. If you are in danger, call 911 or text/call 988.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Tools & Journal")
            .toolbar { ToolbarItem(placement: .topBarLeading) { UrgeToolbarButton() } }
        }
    }
}

/// Requires Face ID / passcode before showing journal content when the privacy lock is on.
struct JournalLockGate<Content: View>: View {
    @Environment(AppServices.self) private var services
    @AppStorage("journalLockEnabled") private var lockEnabled = true
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if !lockEnabled || services.journalUnlocked {
            content
        } else {
            ContentUnavailableView {
                Label("Journal Locked", systemImage: "lock.fill")
            } description: {
                Text("Your entries are encrypted on this device.")
            } actions: {
                Button("Unlock") {
                    Task { services.journalUnlocked = await JournalLock.authenticate() }
                }
                .buttonStyle(.borderedProminent)
            }
            .task { services.journalUnlocked = await JournalLock.authenticate() }
        }
    }
}

// MARK: - Step work

struct RecoveryStep: Identifiable, Hashable {
    let number: Int
    let principle: String
    let theme: String
    let prompts: [String]

    var id: Int { number }

    static let all: [RecoveryStep] = [
        RecoveryStep(number: 1, principle: "Honesty", theme: "Admitting I couldn't manage my addiction on my own.",
                     prompts: ["When did I first notice I'd lost control?", "What has my using cost me?", "What does 'unmanageable' look like in my life?"]),
        RecoveryStep(number: 2, principle: "Hope", theme: "Coming to believe that something greater than myself could help restore balance.",
                     prompts: ["Where have I seen others recover?", "What gives me hope today?", "What might 'a power greater than myself' mean to me?"]),
        RecoveryStep(number: 3, principle: "Surrender", theme: "Deciding to trust that care and guidance, as I understand it.",
                     prompts: ["What am I still trying to control?", "What would letting go look like this week?", "What does trust feel like in my body?"]),
        RecoveryStep(number: 4, principle: "Courage", theme: "Taking a searching, honest inventory of myself.",
                     prompts: ["Who or what do I resent, and why?", "What fears drive my choices?", "What patterns show up in my relationships?"]),
        RecoveryStep(number: 5, principle: "Integrity", theme: "Sharing that inventory honestly with myself, my Higher Power and another person.",
                     prompts: ["What am I most afraid to share?", "Who is a safe person to hear my inventory?", "How did I feel after sharing?"]),
        RecoveryStep(number: 6, principle: "Willingness", theme: "Becoming ready to let go of my defects of character.",
                     prompts: ["Which defects still feel useful to me?", "What would I be like without them?", "Where am I unwilling, and why?"]),
        RecoveryStep(number: 7, principle: "Humility", theme: "Humbly asking for help removing my shortcomings.",
                     prompts: ["What does humility mean to me (not humiliation)?", "Which shortcoming showed up today?", "How can I practice the opposite trait?"]),
        RecoveryStep(number: 8, principle: "Love", theme: "Listing those I've harmed and becoming willing to make amends.",
                     prompts: ["Who have I harmed, including myself?", "What was the harm?", "Where do I feel resistance to making amends?"]),
        RecoveryStep(number: 9, principle: "Justice", theme: "Making direct amends wherever possible, unless it would cause harm.",
                     prompts: ["Which amends am I ready for?", "What do I need to say — and what do I need to change?", "Could this amend harm anyone? Talk it over with your sponsor."]),
        RecoveryStep(number: 10, principle: "Perseverance", theme: "Continuing a daily inventory and promptly admitting when I'm wrong.",
                     prompts: ["Where was I selfish, dishonest, resentful or afraid today?", "Do I owe anyone an apology?", "What did I do well today?"]),
        RecoveryStep(number: 11, principle: "Spiritual awareness", theme: "Seeking connection through prayer, meditation or reflection.",
                     prompts: ["What practice helps me feel connected?", "What guidance am I seeking today?", "When did I feel at peace this week?"]),
        RecoveryStep(number: 12, principle: "Service", theme: "Carrying the message to others and practicing these principles in all my affairs.",
                     prompts: ["How can I be of service this week?", "Who might benefit from hearing my story?", "Where can I practice these principles at home or work?"]),
    ]
}

struct StepWorkListView: View {
    @Query(filter: #Predicate<JournalEntry> { $0.kindRaw == "stepWork" }) private var entries: [JournalEntry]

    var body: some View {
        List(RecoveryStep.all) { step in
            let count = entries.filter { $0.step == step.number }.count
            NavigationLink { StepDetailView(step: step) } label: {
                HStack(spacing: 12) {
                    Text("\(step.number)")
                        .font(.headline.monospacedDigit())
                        .frame(width: 34, height: 34)
                        .background(Color.purple.opacity(count > 0 ? 0.3 : 0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.principle).font(.headline)
                        Text(step.theme).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer()
                    if count > 0 { Text("\(count)").font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
        .navigationTitle("12-Step Work")
    }
}

struct StepDetailView: View {
    let step: RecoveryStep
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @Query private var entries: [JournalEntry]
    @State private var draft = ""

    init(step: RecoveryStep) {
        self.step = step
        let number = step.number
        _entries = Query(
            filter: #Predicate<JournalEntry> { $0.kindRaw == "stepWork" && $0.step == number },
            sort: \JournalEntry.date,
            order: .reverse
        )
    }

    var body: some View {
        Form {
            Section {
                Text(step.theme)
            } header: {
                Text("Step \(step.number) · \(step.principle)")
            }
            Section("Reflection prompts") {
                ForEach(step.prompts, id: \.self) { prompt in
                    Button {
                        draft += (draft.isEmpty ? "" : "\n\n") + prompt + "\n"
                    } label: {
                        Label(prompt, systemImage: "text.bubble")
                    }
                }
            }
            Section("Write") {
                TextEditor(text: $draft).frame(minHeight: 160)
                Button("Save encrypted entry") { save() }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if !entries.isEmpty {
                Section("Previous entries") {
                    ForEach(entries) { JournalEntryRow(entry: $0) }
                        .onDelete { offsets in
                            for index in offsets { context.delete(entries[index]) }
                        }
                }
            }
        }
        .navigationTitle("Step \(step.number)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() {
        guard let sealed = try? services.journalCipher.seal(draft) else { return }
        context.insert(JournalEntry(kind: .stepWork, step: step.number, sealedBody: sealed))
        draft = ""
    }
}

// MARK: - Nightly inventory & gratitude

struct NightlyInventoryView: View {
    private static let questions = [
        "Was I resentful, selfish, dishonest or afraid today?",
        "Do I owe anyone an apology?",
        "Did I keep something to myself that I should share with someone?",
        "Was I kind and loving toward all?",
        "What could I have done better?",
        "What went well today?",
    ]

    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var answers = Array(repeating: "", count: NightlyInventoryView.questions.count)
    @State private var mood = 3
    @State private var saved = false

    var body: some View {
        Form {
            Section("How was today?") {
                Picker("Mood", selection: $mood) {
                    ForEach(1...5, id: \.self) { Text(Self.moodEmoji($0)).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            ForEach(Self.questions.indices, id: \.self) { index in
                Section(Self.questions[index]) {
                    TextField("Your answer", text: $answers[index], axis: .vertical).lineLimit(2...6)
                }
            }
            Section {
                Button("Save encrypted review") { save() }
                    .disabled(answers.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty })
            }
        }
        .navigationTitle("Nightly Inventory")
        .sensoryFeedback(.success, trigger: saved)
    }

    static func moodEmoji(_ value: Int) -> String {
        ["😞", "😕", "😐", "🙂", "😄"][max(1, min(value, 5)) - 1]
    }

    private func save() {
        let body = zip(Self.questions, answers)
            .filter { !$0.1.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { "\($0.0)\n\($0.1)" }
            .joined(separator: "\n\n")
        guard let sealed = try? services.journalCipher.seal(body) else { return }
        context.insert(JournalEntry(kind: .inventory, mood: mood, sealedBody: sealed))
        saved = true
        dismiss()
    }
}

struct GratitudeJournalView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<JournalEntry> { $0.kindRaw == "gratitude" }, sort: \JournalEntry.date, order: .reverse)
    private var entries: [JournalEntry]
    @State private var items = ["", "", ""]

    var body: some View {
        Form {
            Section {
                ForEach(items.indices, id: \.self) { index in
                    TextField("I'm grateful for…", text: $items[index])
                }
                Button("Save gratitude list") { save() }
                    .disabled(items.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty })
            } header: {
                Text("Three good things today")
            } footer: {
                Text("Be specific — \"the sunrise on my walk\" beats \"nature\".")
            }
            if !entries.isEmpty {
                Section("Recent") {
                    ForEach(entries.prefix(10)) { JournalEntryRow(entry: $0) }
                }
            }
        }
        .navigationTitle("Gratitude")
    }

    private func save() {
        let body = items
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { "• \($0)" }
            .joined(separator: "\n")
        guard let sealed = try? services.journalCipher.seal(body) else { return }
        context.insert(JournalEntry(kind: .gratitude, sealedBody: sealed))
        items = ["", "", ""]
    }
}

struct JournalHistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView("No entries yet", systemImage: "book", description: Text("Your encrypted journal entries will appear here."))
            }
            ForEach(entries) { JournalEntryRow(entry: $0) }
                .onDelete { offsets in
                    for index in offsets { context.delete(entries[index]) }
                }
        }
        .navigationTitle("Journal History")
    }
}

struct JournalEntryRow: View {
    let entry: JournalEntry
    @Environment(AppServices.self) private var services

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(entry.kind == .stepWork ? "Step \(entry.step)" : entry.kind.title, systemImage: entry.kind.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if entry.mood > 0 { Text(NightlyInventoryView.moodEmoji(entry.mood)) }
                Spacer()
                Text(entry.date, format: .dateTime.month().day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(services.journalCipher.openOrPlaceholder(entry.sealedBody))
                .font(.subheadline)
                .lineLimit(6)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Contacts

struct EmergencyContactsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \EmergencyContact.name) private var contacts: [EmergencyContact]
    @State private var name = ""
    @State private var phone = ""
    @State private var isSponsor = false

    var body: some View {
        List {
            Section("My people") {
                ForEach(contacts) { contact in
                    HStack {
                        Image(systemName: contact.isSponsor ? "star.circle.fill" : "person.circle.fill")
                            .foregroundStyle(contact.isSponsor ? Color.orange : Color.blue)
                        VStack(alignment: .leading) {
                            Text(contact.name)
                            Text(contact.phone).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let url = contact.telURL {
                            Link(destination: url) { Image(systemName: "phone.fill") }
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(contacts[index]) }
                }
            }
            Section("Add contact") {
                TextField("Name", text: $name)
                TextField("Phone", text: $phone).keyboardType(.phonePad)
                Toggle("This is my sponsor", isOn: $isSponsor)
                Button("Add") {
                    context.insert(EmergencyContact(name: name, phone: phone, isSponsor: isSponsor))
                    name = ""
                    phone = ""
                    isSponsor = false
                }
                .disabled(name.isEmpty || phone.filter(\.isNumber).count < 3)
            }
            Section("24/7 hotlines") {
                ForEach(Hotline.all) { hotline in
                    Link(destination: hotline.url) {
                        VStack(alignment: .leading) {
                            Text(hotline.name)
                            Text(hotline.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Contacts")
    }
}
