import Foundation

struct PlannedItem: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var start: Date
    var durationMinutes: Int
    var category: TaskCategory
    var priority: Int
}

/// Turns free-form notes ("work 9am-5pm, AA meeting at 7:30pm, call sponsor") into a
/// prioritized day plan, then adds recovery anchors the user didn't mention.
/// The LLM is only used for coaching notes on top, so planning works fully offline.
enum ScheduleAssistant {
    static func plan(from text: String, on day: Date, calendar: Calendar = .current) -> [PlannedItem] {
        let dayStart = calendar.startOfDay(for: day)
        let fragments = text
            .components(separatedBy: CharacterSet(charactersIn: "\n,;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var items: [PlannedItem] = []
        var cursor = at(9, 0, dayStart, calendar)
        for fragment in fragments {
            let category = categorize(fragment)
            let start: Date
            if let time = parseTime(fragment) {
                start = at(time.hour, time.minute, dayStart, calendar)
            } else {
                start = cursor
            }
            let duration = defaultDuration(for: category)
            items.append(PlannedItem(
                title: capitalized(fragment),
                start: start,
                durationMinutes: duration,
                category: category,
                priority: category.isRecoveryCommitment ? 2 : 1
            ))
            cursor = max(cursor, start.addingTimeInterval(Double(duration + 15) * 60))
        }

        addAnchors(to: &items, dayStart: dayStart, calendar: calendar)
        return items.sorted { $0.start < $1.start }
    }

    static func addAnchors(to items: inout [PlannedItem], dayStart: Date, calendar: Calendar) {
        func has(_ category: TaskCategory, where test: (Int) -> Bool = { _ in true }) -> Bool {
            items.contains { $0.category == category && test(calendar.component(.hour, from: $0.start)) }
        }
        if !has(.reflection, where: { $0 < 11 }) {
            items.append(PlannedItem(title: "Morning reflection & intention", start: at(7, 0, dayStart, calendar), durationMinutes: 15, category: .reflection, priority: 2))
        }
        if !has(.meeting) {
            items.append(PlannedItem(title: "Recovery meeting (in person or online)", start: at(19, 0, dayStart, calendar), durationMinutes: 60, category: .meeting, priority: 2))
        }
        if !has(.stepWork) {
            items.append(PlannedItem(title: "Step work / recovery reading", start: at(17, 30, dayStart, calendar), durationMinutes: 30, category: .stepWork, priority: 1))
        }
        if !has(.selfCare) {
            items.append(PlannedItem(title: "Walk, stretch or movement", start: at(12, 30, dayStart, calendar), durationMinutes: 20, category: .selfCare, priority: 1))
        }
        if !has(.reflection, where: { $0 >= 18 }) {
            items.append(PlannedItem(title: "Nightly inventory & gratitude", start: at(21, 30, dayStart, calendar), durationMinutes: 15, category: .reflection, priority: 2))
        }
    }

    static func parseTime(_ text: String) -> (hour: Int, minute: Int)? {
        let lower = text.lowercased()
        if lower.contains("noon") { return (12, 0) }
        if lower.contains("midnight") { return (0, 0) }
        guard let regex = try? NSRegularExpression(pattern: #"\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b"#) else { return nil }
        let ns = lower as NSString
        for match in regex.matches(in: lower, range: NSRange(location: 0, length: ns.length)) {
            func group(_ index: Int) -> String? {
                let range = match.range(at: index)
                return range.location == NSNotFound ? nil : ns.substring(with: range)
            }
            let minute = group(2).flatMap { Int($0) }
            let meridiem = group(3)
            // A bare number ("step 4") is not a time; require minutes or am/pm.
            guard minute != nil || meridiem != nil,
                  var hour = group(1).flatMap({ Int($0) }),
                  hour <= 23, (minute ?? 0) < 60 else { continue }
            if meridiem == "pm", hour < 12 { hour += 12 }
            if meridiem == "am", hour == 12 { hour = 0 }
            return (hour, minute ?? 0)
        }
        return nil
    }

    static func categorize(_ text: String) -> TaskCategory {
        let lower = text.lowercased()
        let table: [(TaskCategory, [String])] = [
            (.meeting, ["meeting", "fellowship", "home group", "smart recovery", "al-anon"]),
            (.sponsor, ["sponsor", "mentor", "sponsee"]),
            (.stepWork, ["step", "inventory", "big book", "literature", "workbook", "amends"]),
            (.reflection, ["meditat", "pray", "reflect", "journal", "gratitude"]),
            (.selfCare, ["gym", "walk", "yoga", "exercise", "workout", "sleep", "nap", "lunch", "dinner", "breakfast", "therapy", "doctor", "rest", "bath"]),
            (.work, ["work", "school", "class", "shift", "office", "study", "meeting with"]),
        ]
        for (category, keywords) in table where keywords.contains(where: { lower.contains($0) }) {
            return category
        }
        return .other
    }

    static func defaultDuration(for category: TaskCategory) -> Int {
        switch category {
        case .meeting: 60
        case .stepWork: 45
        case .reflection: 15
        case .sponsor: 20
        case .selfCare: 45
        case .work: 240
        case .other: 30
        }
    }

    static func systemPrompt(for pathway: RecoveryPathway) -> String {
        RecoveryPrompts.schedule(for: pathway)
    }

    private static func at(_ hour: Int, _ minute: Int, _ dayStart: Date, _ calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) ?? dayStart
    }

    private static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}
