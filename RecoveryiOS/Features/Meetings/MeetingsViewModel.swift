import Foundation
import CoreLocation
import SwiftData
import Observation

@Observable
final class MeetingsViewModel {
    var meetings: [Meeting] = []
    var selectedFellowships: Set<Fellowship> = Set(Fellowship.allCases)
    var modeFilter: AttendanceMode?
    var todayOnly = false
    var searchText = ""
    var isLoading = false
    var statusMessage: String?

    func filtered(location: CLLocation?) -> [Meeting] {
        let matches = meetings.filter { meeting in
            guard selectedFellowships.contains(meeting.fellowship) else { return false }
            // Hybrid meetings satisfy both the in-person and the virtual filter.
            if let modeFilter, meeting.mode != modeFilter, meeting.mode != .hybrid { return false }
            if todayOnly, !meeting.isToday { return false }
            if !searchText.isEmpty {
                let haystack = "\(meeting.name) \(meeting.locationName ?? "") \(meeting.address ?? "")"
                if !haystack.localizedCaseInsensitiveContains(searchText) { return false }
            }
            return true
        }
        return matches.sorted { lhs, rhs in
            switch (lhs.distance(from: location), rhs.distance(from: location)) {
            case let (l?, r?): return l < r
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return (lhs.weekday, lhs.time) < (rhs.weekday, rhs.time)
            }
        }
    }

    func toggle(_ fellowship: Fellowship) {
        if selectedFellowships.contains(fellowship) {
            selectedFellowships.remove(fellowship)
        } else {
            selectedFellowships.insert(fellowship)
        }
    }

    /// Loads live/mock meetings; on failure (e.g. no connectivity) falls back to the SwiftData cache.
    @MainActor
    func load(provider: any MeetingProvider, location: CLLocation?, context: ModelContext) async {
        isLoading = true
        defer { isLoading = false }
        do {
            meetings = try await provider.meetings(near: location, fellowships: Set(Fellowship.allCases))
            statusMessage = provider is MockMeetingProvider
                ? "Showing sample meetings. Add Meeting Guide feed URLs in Configuration.plist for live listings."
                : nil
        } catch {
            let descriptor = FetchDescriptor<CachedMeeting>(sortBy: [SortDescriptor(\.lastViewed, order: .reverse)])
            meetings = ((try? context.fetch(descriptor)) ?? []).compactMap(\.meeting)
            statusMessage = "You appear to be offline. Showing \(meetings.count) saved meeting(s)."
        }
    }
}
