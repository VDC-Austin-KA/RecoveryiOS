import SwiftUI
import SwiftData

/// High-priority "panic button" screen: grounding exercises, people to call and an AI grounding prompt.
struct UrgeSupportView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \EmergencyContact.name) private var contacts: [EmergencyContact]
    @AppStorage("pathway") private var pathwayRaw = RecoveryPathway.twelveStep.rawValue
    @State private var grounding: String?

    private var pathway: RecoveryPathway { RecoveryPathway(rawValue: pathwayRaw) ?? .twelveStep }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Text("You're not alone.").font(.title.bold())
                        Text("This feeling is temporary. Let's ride it out together.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)

                    peopleCard
                    BoxBreathingView().card()
                    FiveSensesView().card()
                    groundingCard
                    hotlinesCard
                }
                .padding()
            }
            .navigationTitle("Urge Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("I'm OK") { dismiss() }
                }
            }
            .task { await loadGrounding() }
        }
    }

    private var peopleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Reach out", systemImage: "phone.fill").font(.headline)
            if contacts.isEmpty {
                Text("Add your sponsor and trusted people in Tools › Emergency Contacts so they're one tap away.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(contacts.sorted { $0.isSponsor && !$1.isSponsor }) { contact in
                if let url = contact.telURL {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: contact.isSponsor ? "star.circle.fill" : "person.circle.fill")
                                .foregroundStyle(contact.isSponsor ? Color.orange : Color.blue)
                            VStack(alignment: .leading) {
                                Text(contact.name).font(.headline)
                                Text(contact.isSponsor ? "Sponsor · \(contact.phone)" : contact.phone)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "phone.arrow.up.right.fill").foregroundStyle(.green)
                        }
                        .padding(10)
                        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    private var groundingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Grounding guide", systemImage: "sparkles").font(.headline)
            if let grounding {
                Text(grounding).font(.body)
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .card()
    }

    private var hotlinesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("24/7 Help", systemImage: "cross.case.fill").font(.headline)
            ForEach(Hotline.all) { hotline in
                Link(destination: hotline.url) {
                    VStack(alignment: .leading) {
                        Text(hotline.name).font(.subheadline.weight(.semibold))
                        Text(hotline.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }

    private func loadGrounding() async {
        let system = RecoveryPrompts.grounding(for: pathway)
        let ask = [ChatTurn(role: .user, content: "I'm having a strong urge right now. Please help me ground myself.")]
        // Show the offline script instantly, then upgrade to the live model if one responds.
        grounding = MockResponder.reply(system: system, to: ask[0].content)
        let client = services.llmClient
        guard !(client is MockLLMClient) else { return }
        if let live = try? await client.complete(system: system, messages: ask) {
            grounding = live
        }
    }
}

struct BoxBreathingView: View {
    private static let phases: [(label: String, scale: CGFloat)] = [
        ("Breathe in", 1.0), ("Hold", 1.0), ("Breathe out", 0.55), ("Hold", 0.55),
    ]

    @State private var running = false
    @State private var phase = 0
    @State private var secondsLeft = 4

    var body: some View {
        VStack(spacing: 14) {
            Label("Box breathing", systemImage: "square").font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [Color.teal.opacity(0.8), Color.blue.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 170, height: 170)
                    .scaleEffect(running ? Self.phases[phase].scale : 0.55)
                    .animation(.easeInOut(duration: 4), value: phase)
                    .animation(.easeInOut(duration: 4), value: running)
                VStack {
                    Text(running ? Self.phases[phase].label : "Ready")
                        .font(.title3.bold())
                    if running { Text("\(secondsLeft)").font(.title.monospacedDigit()) }
                }
                .foregroundStyle(.white)
            }
            .frame(height: 190)
            Button(running ? "Stop" : "Start 4-4-4-4 breathing") {
                phase = 0
                secondsLeft = 4
                running.toggle()
            }
            .buttonStyle(.bordered)
        }
        .task(id: running) {
            guard running else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                if secondsLeft > 1 {
                    secondsLeft -= 1
                } else {
                    secondsLeft = 4
                    phase = (phase + 1) % Self.phases.count
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: phase)
    }
}

struct FiveSensesView: View {
    private static let steps: [(count: Int, sense: String, icon: String)] = [
        (5, "things you can see", "eye.fill"),
        (4, "things you can touch", "hand.raised.fill"),
        (3, "things you can hear", "ear.fill"),
        (2, "things you can smell", "nose.fill"),
        (1, "thing you can taste", "mouth.fill"),
    ]

    @State private var index = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("5-4-3-2-1 grounding", systemImage: "hand.point.up.left.fill").font(.headline)
            if index < Self.steps.count {
                let step = Self.steps[index]
                HStack(spacing: 14) {
                    Image(systemName: step.icon).font(.largeTitle).foregroundStyle(.teal).frame(width: 56)
                    Text("Name **\(step.count)** \(step.sense).").font(.title3)
                }
                .id(index)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
                HStack {
                    ForEach(0..<Self.steps.count, id: \.self) { dot in
                        Circle().fill(dot <= index ? Color.teal : Color.gray.opacity(0.3)).frame(width: 8, height: 8)
                    }
                    Spacer()
                    Button("Next") { withAnimation { index += 1 } }.buttonStyle(.borderedProminent)
                }
            } else {
                Text("Well done. Notice how your body feels now compared with a few minutes ago.")
                Button("Start again") { withAnimation { index = 0 } }.buttonStyle(.bordered)
            }
        }
    }
}
