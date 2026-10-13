import SwiftUI
import SwiftData

struct PlannerView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @Query(sort: \PlannerTask.start) private var allTasks: [PlannerTask]
    @State private var vm = PlannerViewModel()
    @State private var showingEditor = false
    @State private var showingAIPlanner = false

    private var dayTasks: [PlannerTask] {
        allTasks.filter { Calendar.current.isDate($0.start, inSameDayAs: vm.selectedDate) }
    }

    var body: some View {
        let tasks = dayTasks
        NavigationStack {
            List {
                Section {
                    DatePicker("Day", selection: $vm.selectedDate, displayedComponents: .date)
                    DayProgressHeader(tasks: tasks)
                }

                Section("Timeline") {
                    if tasks.isEmpty {
                        ContentUnavailableView {
                            Label("No plan yet", systemImage: "calendar.badge.plus")
                        } description: {
                            Text("Describe your day and the AI planner will build a recovery-first schedule.")
                        } actions: {
                            Button("Plan my day with AI") { showingAIPlanner = true }
                                .buttonStyle(.borderedProminent)
                        }
                    } else {
                        ForEach(tasks) { task in
                            TaskRow(task: task)
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(tasks[index]) }
                        }
                    }
                }

                if let message = vm.syncMessage {
                    Section { Label(message, systemImage: "calendar") .font(.footnote) }
                }
            }
            .navigationTitle("Planner")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { UrgeToolbarButton() }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.sync(tasks, calendar: services.calendar) }
                    } label: {
                        Label("Sync to Calendar", systemImage: "calendar.badge.checkmark")
                    }
                    .disabled(tasks.isEmpty)
                    Menu {
                        Button { showingAIPlanner = true } label: { Label("AI plan my day", systemImage: "wand.and.stars") }
                        Button { showingEditor = true } label: { Label("Add task", systemImage: "plus") }
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) { TaskEditorView(day: vm.selectedDate) }
            .sheet(isPresented: $showingAIPlanner) { AIPlanSheet(vm: vm) }
        }
    }
}

struct DayProgressHeader: View {
    let tasks: [PlannerTask]

    var body: some View {
        let done = tasks.filter(\.isCompleted).count
        let recovery = tasks.filter { $0.category.isRecoveryCommitment }
        let recoveryDone = recovery.filter(\.isCompleted).count
        HStack(spacing: 20) {
            ZStack {
                ProgressRing(progress: ratio(done, tasks.count), lineWidth: 10, tint: .teal)
                    .frame(width: 76, height: 76)
                ProgressRing(progress: ratio(recoveryDone, recovery.count), lineWidth: 8, tint: .orange)
                    .frame(width: 50, height: 50)
            }
            VStack(alignment: .leading, spacing: 6) {
                Label("\(done)/\(tasks.count) tasks done", systemImage: "circle.fill")
                    .foregroundStyle(.teal)
                Label("\(recoveryDone)/\(recovery.count) recovery commitments", systemImage: "circle.fill")
                    .foregroundStyle(.orange)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 6)
    }

    private func ratio(_ part: Int, _ whole: Int) -> Double {
        whole == 0 ? 0 : Double(part) / Double(whole)
    }
}

struct TaskRow: View {
    @Bindable var task: PlannerTask

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Text(task.start, format: .dateTime.hour().minute())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                RoundedRectangle(cornerRadius: 1)
                    .fill(task.category.color.opacity(0.5))
                    .frame(width: 3)
                    .frame(minHeight: 24)
            }
            .frame(width: 58)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Label(task.category.rawValue, systemImage: task.category.icon)
                        .font(.caption)
                        .foregroundStyle(task.category.color)
                    if task.priority >= 2 {
                        Text("Priority").font(.caption2.bold()).foregroundStyle(.red)
                    }
                    if task.calendarEventID != nil {
                        Image(systemName: "calendar.badge.checkmark").font(.caption).foregroundStyle(.green)
                    }
                }
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                Text("\(task.durationMinutes) min").font(.caption2).foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation { task.isCompleted.toggle() }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")
            .sensoryFeedback(.success, trigger: task.isCompleted)
        }
    }
}

struct TaskEditorView: View {
    let day: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var start = Date.now
    @State private var duration = 30
    @State private var category: TaskCategory = .stepWork
    @State private var priority = 1

    var body: some View {
        NavigationStack {
            Form {
                TextField("What do you want to do?", text: $title)
                DatePicker("Start", selection: $start)
                Stepper("Duration: \(duration) min", value: $duration, in: 5...480, step: 5)
                Picker("Category", selection: $category) {
                    ForEach(TaskCategory.allCases) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                }
                Picker("Priority", selection: $priority) {
                    Text("Low").tag(0)
                    Text("Normal").tag(1)
                    Text("High").tag(2)
                }
                .pickerStyle(.segmented)
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(PlannerTask(title: title, start: start, durationMinutes: duration, category: category, priority: priority))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                // Default to the next half hour on the selected day.
                let calendar = Calendar.current
                let now = Date.now
                let minute = calendar.component(.minute, from: now) < 30 ? 30 : 0
                let hour = calendar.component(.hour, from: now) + (minute == 0 ? 1 : 0)
                start = calendar.date(bySettingHour: min(hour, 23), minute: minute, second: 0, of: day) ?? day
            }
        }
    }
}

struct AIPlanSheet: View {
    @Bindable var vm: PlannerViewModel
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("pathway") private var pathwayRaw = RecoveryPathway.twelveStep.rawValue

    private var pathway: RecoveryPathway { RecoveryPathway(rawValue: pathwayRaw) ?? .twelveStep }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $vm.planInput)
                        .frame(minHeight: 110)
                } header: {
                    Text("Describe your day")
                } footer: {
                    Text("e.g. “Work 9am-5pm, gym after, AA meeting at 7:30pm, call sponsor”. Recovery anchors you leave out are added automatically.")
                }

                Section {
                    Button {
                        Task { await vm.generatePlan(client: services.llmClient, pathway: pathway) }
                    } label: {
                        HStack {
                            Label("Build my recovery-first plan", systemImage: "wand.and.stars")
                            if vm.isPlanning { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(vm.isPlanning)
                }

                if !vm.preview.isEmpty {
                    Section("Suggested schedule") {
                        ForEach(vm.preview) { item in
                            HStack {
                                Text(item.start, format: .dateTime.hour().minute())
                                    .font(.caption.monospacedDigit())
                                    .frame(width: 64, alignment: .leading)
                                Image(systemName: item.category.icon).foregroundStyle(item.category.color)
                                Text(item.title)
                                Spacer()
                                if item.priority >= 2 { Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red) }
                            }
                        }
                        .onDelete { vm.preview.remove(atOffsets: $0) }
                    }
                }

                if let notes = vm.coachNotes {
                    Section("Coach notes") { Text(LocalizedStringKey(notes)) }
                }

                if !vm.preview.isEmpty {
                    Section {
                        Button("Add to Planner") {
                            vm.acceptPreview(into: context)
                            dismiss()
                        }
                        Button("Add & Sync to Apple Calendar") {
                            let tasks = vm.acceptPreview(into: context)
                            let calendar = services.calendar
                            Task { await vm.sync(tasks, calendar: calendar) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("AI Day Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }
}
