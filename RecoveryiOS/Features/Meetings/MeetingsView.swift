import SwiftUI
import SwiftData
import MapKit

struct MeetingsView: View {
    private enum DisplayMode: String, CaseIterable, Identifiable {
        case map = "Map"
        case list = "List"
        var id: String { rawValue }
    }

    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<CachedMeeting> { $0.isFavorite }, sort: \CachedMeeting.lastViewed, order: .reverse)
    private var favorites: [CachedMeeting]
    @State private var vm = MeetingsViewModel()
    @State private var display: DisplayMode = .map
    @State private var selectedID: String?
    @State private var detail: Meeting?
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        let location = services.location.location
        let results = vm.filtered(location: location)
        NavigationStack {
            VStack(spacing: 0) {
                MeetingFilterBar(vm: vm)
                Picker("Display", selection: $display) {
                    ForEach(DisplayMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                if let message = vm.statusMessage {
                    Label(message, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                switch display {
                case .map: mapView(results)
                case .list: listView(results, location: location)
                }
            }
            .navigationTitle("Meetings")
            .searchable(text: $vm.searchText, prompt: "Search meetings or places")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { UrgeToolbarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    if vm.isLoading { ProgressView() }
                }
            }
            .task { services.location.start() }
            .task(id: location == nil) { await reload() }
            .onChange(of: selectedID) { _, id in
                detail = results.first { $0.id == id }
            }
            .sheet(item: $detail, onDismiss: { selectedID = nil }) { meeting in
                MeetingDetailView(meeting: meeting, distance: meeting.distance(from: location))
            }
        }
    }

    private func reload() async {
        await vm.load(provider: services.meetingProvider, location: services.location.location, context: context)
    }

    private func mapView(_ results: [Meeting]) -> some View {
        let pins = results.compactMap { meeting in meeting.coordinate.map { MeetingPin(meeting: meeting, coordinate: $0) } }
        return Map(position: $position, selection: $selectedID) {
            UserAnnotation()
            ForEach(pins) { pin in
                Marker(pin.meeting.name, systemImage: pin.meeting.fellowship.icon, coordinate: pin.coordinate)
                    .tint(pin.meeting.fellowship.color)
                    .tag(pin.id)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .overlay(alignment: .bottom) {
            let virtualCount = results.filter { $0.coordinate == nil }.count
            if virtualCount > 0 {
                Button {
                    vm.modeFilter = .online
                    display = .list
                } label: {
                    Label("\(virtualCount) virtual meeting(s) — view list", systemImage: "video.fill")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                }
                .padding(.bottom, 12)
            }
        }
    }

    private func listView(_ results: [Meeting], location: CLLocation?) -> some View {
        List {
            let favoriteMeetings = favorites.compactMap(\.meeting)
            if !favoriteMeetings.isEmpty {
                Section("Favorites (available offline)") {
                    ForEach(favoriteMeetings) { meeting in
                        Button { detail = meeting } label: {
                            MeetingRow(meeting: meeting, distance: meeting.distance(from: location))
                        }
                    }
                }
            }
            let resultsTitle: String = results.isEmpty ? "No meetings match your filters" : "\(results.count) meetings"
            Section(resultsTitle) {
                ForEach(results) { meeting in
                    Button { detail = meeting } label: {
                        MeetingRow(meeting: meeting, distance: meeting.distance(from: location))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .buttonStyle(.plain)
        .refreshable { await reload() }
    }
}

private struct MeetingPin: Identifiable {
    let meeting: Meeting
    let coordinate: CLLocationCoordinate2D
    var id: String { meeting.id }
}

struct MeetingFilterBar: View {
    @Bindable var vm: MeetingsViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Fellowship.allCases) { fellowship in
                    let selected = vm.selectedFellowships.contains(fellowship)
                    Button {
                        vm.toggle(fellowship)
                    } label: {
                        Text(fellowship.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selected ? fellowship.color : Color.gray.opacity(0.15), in: Capsule())
                            .foregroundStyle(selected ? Color.white : Color.primary)
                    }
                    .accessibilityLabel(fellowship.fullName)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
                Divider().frame(height: 22)
                Menu {
                    Picker("Format", selection: $vm.modeFilter) {
                        Text("Any format").tag(AttendanceMode?.none)
                        Text("In-Person").tag(AttendanceMode?.some(.inPerson))
                        Text("Virtual").tag(AttendanceMode?.some(.online))
                    }
                } label: {
                    Label(vm.modeFilter?.rawValue ?? "Format", systemImage: vm.modeFilter?.icon ?? "line.3.horizontal.decrease.circle")
                        .font(.subheadline)
                }
                Toggle("Today", isOn: $vm.todayOnly)
                    .toggleStyle(.button)
                    .font(.subheadline)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

struct MeetingRow: View {
    let meeting: Meeting
    let distance: CLLocationDistance?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: meeting.fellowship.icon)
                .font(.title2)
                .foregroundStyle(meeting.fellowship.color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(meeting.name).font(.headline)
                Text("\(meeting.fellowship.rawValue) · \(meeting.dayName) \(meeting.formattedTime)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Label(meeting.mode.rawValue, systemImage: meeting.mode.icon)
                    if let distance {
                        Text("· \(distance.meetingDistanceText)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let address = meeting.address {
                    Text(address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if meeting.isToday {
                Text("Today")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.2), in: Capsule())
            }
        }
        .contentShape(Rectangle())
    }
}

extension CLLocationDistance {
    var meetingDistanceText: String {
        Measurement(value: self, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
}
