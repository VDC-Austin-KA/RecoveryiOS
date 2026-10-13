import Foundation
import SwiftData

@Model
final class SobrietyProfile {
    var startDate: Date
    var dailySpend: Double
    var dailyHours: Double
    var celebratedMilestones: [Int]

    init(startDate: Date = .now, dailySpend: Double = 20, dailyHours: Double = 3, celebratedMilestones: [Int] = []) {
        self.startDate = startDate
        self.dailySpend = dailySpend
        self.dailyHours = dailyHours
        self.celebratedMilestones = celebratedMilestones
    }
}

/// Offline cache of meetings the user viewed or favorited. The meeting is stored as JSON
/// so schema changes to `Meeting` never require a SwiftData migration.
@Model
final class CachedMeeting {
    @Attribute(.unique) var meetingID: String
    var payload: Data
    var isFavorite: Bool
    var lastViewed: Date

    init(meeting: Meeting, isFavorite: Bool = false) {
        meetingID = meeting.id
        payload = (try? JSONEncoder().encode(meeting)) ?? Data()
        self.isFavorite = isFavorite
        lastViewed = .now
    }

    var meeting: Meeting? { try? JSONDecoder().decode(Meeting.self, from: payload) }

    func refresh(with meeting: Meeting) {
        payload = (try? JSONEncoder().encode(meeting)) ?? payload
        lastViewed = .now
    }
}

enum TaskCategory: String, CaseIterable, Identifiable, Codable {
    case reflection = "Reflection"
    case meeting = "Meeting"
    case stepWork = "Step Work"
    case sponsor = "Sponsor"
    case selfCare = "Self-Care"
    case work = "Work/School"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .reflection: "sunrise.fill"
        case .meeting: "person.3.fill"
        case .stepWork: "stairs"
        case .sponsor: "phone.fill"
        case .selfCare: "heart.fill"
        case .work: "briefcase.fill"
        case .other: "circle.grid.2x2.fill"
        }
    }

    var isRecoveryCommitment: Bool {
        switch self {
        case .reflection, .meeting, .stepWork, .sponsor: true
        default: false
        }
    }
}

@Model
final class PlannerTask {
    var id: UUID
    var title: String
    var start: Date
    var durationMinutes: Int
    var categoryRaw: String
    /// 0 = low, 1 = normal, 2 = high.
    var priority: Int
    var isCompleted: Bool
    var calendarEventID: String?
    var notes: String

    init(title: String, start: Date, durationMinutes: Int = 30, category: TaskCategory = .other, priority: Int = 1, notes: String = "") {
        id = UUID()
        self.title = title
        self.start = start
        self.durationMinutes = durationMinutes
        categoryRaw = category.rawValue
        self.priority = priority
        isCompleted = false
        calendarEventID = nil
        self.notes = notes
    }

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var end: Date { start.addingTimeInterval(Double(durationMinutes) * 60) }
}

enum JournalKind: String, CaseIterable, Codable {
    case inventory
    case gratitude
    case stepWork

    var title: String {
        switch self {
        case .inventory: "Nightly Inventory"
        case .gratitude: "Gratitude"
        case .stepWork: "Step Work"
        }
    }

    var icon: String {
        switch self {
        case .inventory: "moon.stars.fill"
        case .gratitude: "heart.text.square.fill"
        case .stepWork: "stairs"
        }
    }
}

/// Journal entries are stored AES-GCM encrypted (`sealedBody`); see `JournalCipher`.
@Model
final class JournalEntry {
    var date: Date
    var kindRaw: String
    /// Step number for step-work entries, 0 otherwise.
    var step: Int
    /// 1 (struggling) … 5 (great); 0 when not recorded.
    var mood: Int
    var sealedBody: Data

    init(kind: JournalKind, step: Int = 0, mood: Int = 0, sealedBody: Data, date: Date = .now) {
        self.date = date
        kindRaw = kind.rawValue
        self.step = step
        self.mood = mood
        self.sealedBody = sealedBody
    }

    var kind: JournalKind { JournalKind(rawValue: kindRaw) ?? .inventory }
}

@Model
final class ChatMessageRecord {
    var id: UUID
    var roleRaw: String
    var content: String
    var date: Date

    init(role: ChatTurn.Role, content: String, date: Date = .now) {
        id = UUID()
        roleRaw = role.rawValue
        self.content = content
        self.date = date
    }

    var role: ChatTurn.Role { ChatTurn.Role(rawValue: roleRaw) ?? .assistant }
}

@Model
final class EmergencyContact {
    var name: String
    var phone: String
    var isSponsor: Bool

    init(name: String, phone: String, isSponsor: Bool = false) {
        self.name = name
        self.phone = phone
        self.isSponsor = isSponsor
    }

    var telURL: URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        return URL(string: "tel:\(digits)")
    }
}
