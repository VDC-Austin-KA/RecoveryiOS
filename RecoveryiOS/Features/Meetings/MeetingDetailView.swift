import SwiftUI
import SwiftData
import MapKit

struct MeetingDetailView: View {
    let meeting: Meeting
    let distance: CLLocationDistance?

    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var cached: [CachedMeeting]
    @State private var calendarMessage: String?

    init(meeting: Meeting, distance: CLLocationDistance?) {
        self.meeting = meeting
        self.distance = distance
        let id = meeting.id
        _cached = Query(filter: #Predicate<CachedMeeting> { $0.meetingID == id })
    }

    private var isFavorite: Bool { cached.first?.isFavorite ?? false }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(meeting.fellowship.fullName, systemImage: meeting.fellowship.icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(meeting.fellowship.color)
                        Text(meeting.name).font(.title2.bold())
                        Text("\(meeting.dayName)s at \(meeting.formattedTime)").foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Details") {
                    LabeledContent("Format") { Label(meeting.mode.rawValue, systemImage: meeting.mode.icon) }
                    if let distance { LabeledContent("Distance", value: distance.meetingDistanceText) }
                    if let place = meeting.locationName { LabeledContent("Location", value: place) }
                    if let address = meeting.address { LabeledContent("Address", value: address) }
                    if !meeting.types.isEmpty { LabeledContent("Types", value: meeting.types.joined(separator: ", ")) }
                    if let notes = meeting.notes { Text(notes).font(.footnote).foregroundStyle(.secondary) }
                }

                Section {
                    if let url = meeting.conferenceURL {
                        Link(destination: url) { Label("Join online meeting", systemImage: "video.fill") }
                    }
                    if meeting.coordinate != nil {
                        Button { openInMaps() } label: { Label("Directions in Maps", systemImage: "car.fill") }
                    }
                    Button { Task { await addToCalendar() } } label: {
                        Label("Add next meeting to Calendar", systemImage: "calendar.badge.plus")
                    }
                    Button { toggleFavorite() } label: {
                        Label(isFavorite ? "Remove from favorites" : "Save to favorites (offline)",
                              systemImage: isFavorite ? "star.slash" : "star.fill")
                    }
                }

                if let calendarMessage {
                    Section { Text(calendarMessage).font(.footnote) }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task { recordView() }
        }
        .presentationDetents([.medium, .large])
    }

    private func recordView() {
        if let entry = cached.first {
            entry.refresh(with: meeting)
        } else {
            context.insert(CachedMeeting(meeting: meeting))
        }
    }

    private func toggleFavorite() {
        if let entry = cached.first {
            entry.isFavorite.toggle()
        } else {
            context.insert(CachedMeeting(meeting: meeting, isFavorite: true))
        }
    }

    private func openInMaps() {
        guard let coordinate = meeting.coordinate else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = meeting.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault])
    }

    private func addToCalendar() async {
        guard let start = meeting.nextOccurrence() else { return }
        do {
            try await services.calendar.addEvent(
                title: "\(meeting.fellowship.rawValue): \(meeting.name)",
                start: start,
                end: start.addingTimeInterval(60 * 60),
                notes: meeting.notes,
                url: meeting.conferenceURL,
                location: meeting.address ?? meeting.locationName
            )
            calendarMessage = "Added to your calendar for \(start.formatted(date: .abbreviated, time: .shortened))."
        } catch {
            calendarMessage = error.localizedDescription
        }
    }
}
