import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @Query private var profiles: [SobrietyProfile]
    @Query(sort: \PlannerTask.start) private var tasks: [PlannerTask]
    @AppStorage("pathway") private var pathwayRaw = RecoveryPathway.twelveStep.rawValue
    @State private var celebrating: Milestone?
    @State private var editingProfile = false

    private var pathway: RecoveryPathway { RecoveryPathway(rawValue: pathwayRaw) ?? .twelveStep }
    private var todaysTasks: [PlannerTask] { tasks.filter { Calendar.current.isDateInToday($0.start) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let profile = profiles.first {
                        TimelineView(.periodic(from: .now, by: 60)) { timeline in
                            let stats = makeStats(for: profile, at: timeline.date)
                            VStack(spacing: 16) {
                                SobrietyCounterCard(stats: stats)
                                    .onTapGesture { editingProfile = true }
                                MilestoneStrip(stats: stats)
                            }
                        }
                    }

                    Button {
                        services.showUrgeSupport = true
                    } label: {
                        Label("I'm having an urge", systemImage: "lifepreserver.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityHint("Opens grounding exercises and emergency contacts")

                    DailyInspirationCard(pathway: pathway)
                    TodayPlanCard(tasks: todaysTasks)
                }
                .padding()
            }
            .navigationTitle(greeting)
            .task { ensureProfile() }
            .onChange(of: profiles.first?.startDate) { checkMilestones() }
            .sheet(item: $celebrating) { MilestoneCelebrationView(milestone: $0) }
            .sheet(isPresented: $editingProfile) {
                if let profile = profiles.first {
                    NavigationStack { SobrietySettingsView(profile: profile) }
                }
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private func makeStats(for profile: SobrietyProfile, at date: Date) -> SobrietyStats {
        SobrietyStats(start: profile.startDate, now: date, dailySpend: profile.dailySpend, dailyHours: profile.dailyHours)
    }

    private func ensureProfile() {
        if profiles.isEmpty {
            context.insert(SobrietyProfile())
        }
        checkMilestones()
    }

    private func checkMilestones() {
        guard let profile = profiles.first else { return }
        let stats = makeStats(for: profile, at: .now)
        // Forget celebrations above the current count (e.g. after a counter reset).
        profile.celebratedMilestones = profile.celebratedMilestones.filter { $0 <= stats.days }
        let fresh = stats.unlocked.filter { !profile.celebratedMilestones.contains($0.days) }
        guard let top = fresh.last else { return }
        profile.celebratedMilestones += fresh.map(\.days)
        celebrating = top
    }
}

struct SobrietyCounterCard: View {
    let stats: SobrietyStats

    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sober for")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(stats.days)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(stats.days == 1 ? "day" : "days")
                    .font(.title2.weight(.semibold))
            }
            .foregroundStyle(.white)

            HStack(spacing: 10) {
                StatPill(value: "\(stats.totalHours)", label: "hours")
                StatPill(value: stats.moneySaved.formatted(.currency(code: currencyCode).precision(.fractionLength(0))), label: "saved")
                StatPill(value: stats.hoursReclaimed.formatted(.number.precision(.fractionLength(0))), label: "hrs reclaimed")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [.teal, .blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double-tap to edit your sobriety date and savings")
    }
}

private struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct MilestoneStrip: View {
    let stats: SobrietyStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let next = stats.nextMilestone {
                HStack {
                    Text("Next: \(next.title)").font(.headline)
                    Spacer()
                    Text("\(next.days - stats.days) days to go").font(.subheadline).foregroundStyle(.secondary)
                }
                ProgressView(value: stats.progressToNext).tint(.teal)
            } else {
                Text("Every milestone unlocked — incredible.").font(.headline)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Milestone.all) { milestone in
                        let unlocked = milestone.days <= stats.days
                        VStack(spacing: 6) {
                            Image(systemName: milestone.icon)
                                .font(.title2)
                                .frame(width: 52, height: 52)
                                .background(unlocked ? Color.yellow.opacity(0.3) : Color.gray.opacity(0.15), in: Circle())
                                .foregroundStyle(unlocked ? Color.orange : Color.gray)
                            Text(milestone.title).font(.caption2)
                        }
                        .opacity(unlocked ? 1 : 0.55)
                        .accessibilityLabel("\(milestone.title), \(unlocked ? "unlocked" : "locked")")
                    }
                }
            }
        }
        .card()
    }
}

struct DailyInspirationCard: View {
    let pathway: RecoveryPathway

    var body: some View {
        let quote = InspirationEngine.quote()
        VStack(alignment: .leading, spacing: 12) {
            Label("Daily Inspiration", systemImage: "quote.opening").font(.headline)
            Text("“\(quote.text)”").font(.body.italic())
            Text("— \(quote.author)").font(.footnote).foregroundStyle(.secondary)
            Divider()
            Label(InspirationEngine.affirmation(pathway: pathway), systemImage: "sparkles")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.teal)
            Divider()
            ForEach(InspirationEngine.mediaPicks()) { media in
                Link(destination: media.url) {
                    HStack {
                        Image(systemName: media.icon).frame(width: 28).foregroundStyle(.indigo)
                        VStack(alignment: .leading) {
                            Text(media.title).font(.subheadline.weight(.semibold))
                            Text(media.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "play.circle.fill").foregroundStyle(.indigo)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }
}

struct TodayPlanCard: View {
    let tasks: [PlannerTask]

    var body: some View {
        let done = tasks.filter(\.isCompleted).count
        HStack(spacing: 16) {
            ProgressRing(progress: tasks.isEmpty ? 0 : Double(done) / Double(tasks.count), lineWidth: 8)
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Plan").font(.headline)
                if tasks.isEmpty {
                    Text("Nothing planned yet — try the AI planner in the Planner tab.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("\(done) of \(tasks.count) complete").font(.subheadline).foregroundStyle(.secondary)
                    if let next = tasks.first(where: { !$0.isCompleted && $0.end > .now }) {
                        Text("Next: \(next.title) at \(next.start.formatted(date: .omitted, time: .shortened))")
                            .font(.footnote)
                    }
                }
            }
            Spacer()
        }
        .card()
    }
}

struct MilestoneCelebrationView: View {
    let milestone: Milestone
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: milestone.icon)
                .font(.system(size: 96))
                .foregroundStyle(.orange)
                .scaleEffect(appeared ? 1 : 0.4)
                .rotationEffect(.degrees(appeared ? 0 : -30))
                .animation(.spring(response: 0.6, dampingFraction: 0.5), value: appeared)
            Text("🎉 \(milestone.title)!")
                .font(.largeTitle.bold())
            Text("You've reached a new milestone. Every day you chose recovery counts — take a moment to feel proud.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
            Button("Keep going") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
        .onAppear { appeared = true }
        .sensoryFeedback(.success, trigger: appeared)
        .presentationDetents([.medium, .large])
    }
}
