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
        // Distances computed once per meeting; online feeds hold thousands of entries.
        return matches
            .map { (meeting: $0, distance: $0.distance(from: location)) }
            .sorted { lhs, rhs in
                switch (lhs.distance, rhs.distance) {
                case let (l?, r?): return l < r
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return (lhs.meeting.weekday, lhs.meeting.time) < (rhs.meeting.weekday, rhs.meeting.time)
                }
            }
            .map { $0.meeting }
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
            if location == nil {
                statusMessage = "Turn on location to see in-person meetings near you. Showing online meetings."
            } else if !meetings.contains(where: { $0.coordinate != nil }) {
                statusMessage = "No listed in-person meetings nearby yet — use the official finders below or join online."
            } else {
                statusMessage = nil
            }
        } catch {
            let descriptor = FetchDescriptor<CachedMeeting>(sortBy: [SortDescriptor(\.lastViewed, order: .reverse)])
            meetings = ((try? context.fetch(descriptor)) ?? []).compactMap(\.meeting)
            statusMessage = "You appear to be offline. Showing \(meetings.count) saved meeting(s)."
        }
        if meetings.isEmpty, let samples = try? await MockMeetingProvider().meetings(near: location, fellowships: Set(Fellowship.allCases)) {
            meetings = samples
            statusMessage = "Couldn't load listings (no connection?). Showing sample meetings."
        }
    }
}
