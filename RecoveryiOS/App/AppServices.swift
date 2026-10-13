import Foundation
import Observation

/// App-wide dependency container, injected through the SwiftUI environment.
@Observable
final class AppServices {
    let configuration: AppConfiguration
    let location = LocationService()
    let calendar = CalendarService()
    let journalCipher = JournalCipher.loadOrCreate()

    var showUrgeSupport = false
    var journalUnlocked = false
    /// Bumped when AI settings change so views re-resolve `llmClient`.
    var settingsRevision = 0

    init(configuration: AppConfiguration = .load()) {
        self.configuration = configuration
    }

    var meetingProvider: any MeetingProvider {
        LiveMeetingProvider.standard(extraFeeds: configuration.meetingFeeds)
    }

    var llmClient: any LLMClient {
        _ = settingsRevision
        return LLMFactory.make(configuration: configuration, preference: AIProviderKind.stored)
    }
}
