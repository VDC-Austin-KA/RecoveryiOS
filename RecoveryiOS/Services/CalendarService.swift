import EventKit

enum CalendarError: LocalizedError {
    case accessDenied
    case noDefaultCalendar

    var errorDescription: String? {
        switch self {
        case .accessDenied: "Calendar access is off. Enable it in Settings › Privacy & Security › Calendars."
        case .noDefaultCalendar: "No default calendar is set on this device."
        }
    }
}

/// One-tap export to the user's default calendar using iOS 17 write-only access.
final class CalendarService {
    private let store = EKEventStore()

    func requestAccess() async throws -> Bool {
        try await store.requestWriteOnlyAccessToEvents()
    }

    @discardableResult
    func addEvent(
        title: String,
        start: Date,
        end: Date,
        notes: String? = nil,
        url: URL? = nil,
        location: String? = nil,
        alertMinutesBefore: Int = 15
    ) async throws -> String {
        guard try await requestAccess() else { throw CalendarError.accessDenied }
        guard let calendar = store.defaultCalendarForNewEvents else { throw CalendarError.noDefaultCalendar }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.notes = notes
        event.url = url
        event.location = location
        event.calendar = calendar
        event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-alertMinutesBefore * 60)))
        try store.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier ?? UUID().uuidString
    }
}
