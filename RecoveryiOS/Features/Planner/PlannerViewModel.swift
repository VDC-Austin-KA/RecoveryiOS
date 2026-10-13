import Foundation
import SwiftData
import Observation

@Observable
final class PlannerViewModel {
    var selectedDate = Date.now
    var planInput = ""
    var preview: [PlannedItem] = []
    var coachNotes: String?
    var isPlanning = false
    var syncMessage: String?

    @MainActor
    func generatePlan(client: any LLMClient, pathway: RecoveryPathway) async {
        preview = ScheduleAssistant.plan(from: planInput, on: selectedDate)
        isPlanning = true
        defer { isPlanning = false }
        let summary = preview
            .map { "\($0.start.formatted(date: .omitted, time: .shortened)) – \($0.title) [\($0.category.rawValue)]" }
            .joined(separator: "\n")
        let prompt = ChatTurn(role: .user, content: "Here is my plan for the day:\n\(summary)\n\nMy original notes: \(planInput)")
        do {
            coachNotes = try await client.complete(system: ScheduleAssistant.systemPrompt(for: pathway), messages: [prompt])
        } catch {
            coachNotes = MockResponder.scheduleTips
        }
    }

    @discardableResult
    func acceptPreview(into context: ModelContext) -> [PlannerTask] {
        let tasks = preview.map {
            PlannerTask(title: $0.title, start: $0.start, durationMinutes: $0.durationMinutes, category: $0.category, priority: $0.priority)
        }
        tasks.forEach { context.insert($0) }
        preview = []
        planInput = ""
        return tasks
    }

    /// Exports tasks that aren't in the calendar yet; already-synced tasks are skipped.
    @MainActor
    func sync(_ tasks: [PlannerTask], calendar: CalendarService) async {
        var added = 0
        do {
            for task in tasks where task.calendarEventID == nil {
                task.calendarEventID = try await calendar.addEvent(
                    title: task.title,
                    start: task.start,
                    end: task.end,
                    notes: task.notes.isEmpty ? "Planned in Recovery · \(task.category.rawValue)" : task.notes
                )
                added += 1
            }
            syncMessage = added == 0 ? "Everything here is already in your calendar." : "Added \(added) item(s) to your calendar."
        } catch {
            syncMessage = error.localizedDescription
        }
    }
}
