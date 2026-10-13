import SwiftUI
import SwiftData

@main
struct RecoveryApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(services)
        }
        .modelContainer(for: [
            SobrietyProfile.self,
            CachedMeeting.self,
            PlannerTask.self,
            JournalEntry.self,
            ChatMessageRecord.self,
            EmergencyContact.self,
        ])
    }
}
