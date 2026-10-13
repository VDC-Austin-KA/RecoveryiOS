import SwiftUI

struct RootTabView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var services = services
        TabView {
            DashboardView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            MeetingsView()
                .tabItem { Label("Meetings", systemImage: "map.fill") }
            AssistantView()
                .tabItem { Label("Assistant", systemImage: "bubble.left.and.text.bubble.right.fill") }
            PlannerView()
                .tabItem { Label("Planner", systemImage: "calendar.day.timeline.left") }
            ToolsView()
                .tabItem { Label("Tools", systemImage: "book.closed.fill") }
        }
        .fullScreenCover(isPresented: $services.showUrgeSupport) {
            UrgeSupportView()
        }
        .onChange(of: scenePhase) { _, phase in
            // Re-lock the private journal whenever the app leaves the foreground.
            if phase == .background { services.journalUnlocked = false }
        }
    }
}
