import Foundation
import CoreLocation

protocol MeetingProvider {
    func meetings(near location: CLLocation?, fellowships: Set<Fellowship>) async throws -> [Meeting]
}

// MARK: - Meeting Guide / OMLA
// Live sources (TSML, BMLT, Al-Anon) live in MeetingSources.swift.

/// Tolerant decoder for OMLA records: `day` may be an Int, [Int] or String, and
/// coordinates may be numbers or strings depending on the feed generator.
struct OMLAMeeting: Decodable {
    let name: String
    let slug: String?
    let days: [Int]
    let time: String?
    let endTime: String?
    let location: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let types: [String]
    let conferenceURL: String?
    let notes: String?
    let attendanceOption: String?
    let timeZone: String?

    private enum CodingKeys: String, CodingKey {
        case name, slug, day, time, location, address, city, state, latitude, longitude, types, notes
        case endTime = "end_time"
        case formattedAddress = "formatted_address"
        case conferenceURL = "conference_url"
        case attendanceOption = "attendance_option"
        case timeZone = "timezone"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        slug = try? c.decode(String.self, forKey: .slug)
        if let day = try? c.decode(Int.self, forKey: .day) {
            days = [day]
        } else if let list = try? c.decode([Int].self, forKey: .day) {
            days = list
        } else if let text = try? c.decode(String.self, forKey: .day), let day = Int(text) {
            days = [day]
        } else {
            days = []
        }
        time = try? c.decode(String.self, forKey: .time)
        endTime = try? c.decode(String.self, forKey: .endTime)
        location = try? c.decode(String.self, forKey: .location)
        if let formatted = try? c.decode(String.self, forKey: .formattedAddress) {
            address = formatted
        } else {
            let parts = [CodingKeys.address, .city, .state].compactMap { try? c.decode(String.self, forKey: $0) }
            address = parts.isEmpty ? nil : parts.joined(separator: ", ")
        }
        latitude = Self.double(c, .latitude)
        longitude = Self.double(c, .longitude)
        types = (try? c.decode([String].self, forKey: .types)) ?? []
        conferenceURL = try? c.decode(String.self, forKey: .conferenceURL)
        notes = try? c.decode(String.self, forKey: .notes)
        attendanceOption = try? c.decode(String.self, forKey: .attendanceOption)
        timeZone = try? c.decode(String.self, forKey: .timeZone)
    }

    private static func double(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let value = try? c.decode(Double.self, forKey: key) { return value }
        if let text = try? c.decode(String.self, forKey: key) { return Double(text) }
        return nil
    }

    static func decodeFeed(_ data: Data, fellowship: Fellowship) throws -> [Meeting] {
        try JSONDecoder().decode([OMLAMeeting].self, from: data).flatMap { $0.meetings(fellowship: fellowship) }
    }

    func meetings(fellowship: Fellowship) -> [Meeting] {
        let mode: AttendanceMode
        switch attendanceOption ?? "" {
        case "inactive": return []
        case "online": mode = .online
        case "hybrid": mode = .hybrid
        case "in_person": mode = .inPerson
        default:
            let hasOnline = conferenceURL != nil || types.contains("ONL")
            mode = hasOnline ? (latitude != nil ? .hybrid : .online) : .inPerson
        }
        let baseID = slug ?? name
        return days.filter { (0...6).contains($0) }.map { day in
            Meeting(
                id: "\(fellowship.rawValue)-\(baseID)-\(day)",
                name: name,
                fellowship: fellowship,
                weekday: day,
                time: time ?? "00:00",
                endTime: endTime,
                locationName: location,
                address: address,
                latitude: mode == .online ? nil : latitude,
                longitude: mode == .online ? nil : longitude,
                conferenceURL: conferenceURL.flatMap { URL(string: $0) },
                notes: notes,
                types: types,
                mode: mode,
                timeZone: timeZone
            )
        }
    }
}

// MARK: - Mock

/// Deterministic sample meetings scattered around the user (or San Francisco when location is unknown).
struct MockMeetingProvider: MeetingProvider {
    static let fallbackCenter = CLLocation(latitude: 37.7749, longitude: -122.4194)

    private static let names: [Fellowship: [String]] = [
        .aa: ["Sunrise Serenity Group", "Big Book Study", "Online Daily Reflections", "Keep It Simple"],
        .na: ["Just For Today", "Clean & Serene", "NA Online Recovery Circle"],
        .ha: ["HA Hope Group", "Freedom Fellowship", "HA Virtual Lifeline"],
        .smart: ["SMART Tools for Change", "SMART Recovery Evening", "SMART Online Check-In"],
        .alAnon: ["Al-Anon Courage to Change", "Family Serenity Circle", "Al-Anon Online Hope"],
    ]

    func meetings(near location: CLLocation?, fellowships: Set<Fellowship>) async throws -> [Meeting] {
        let center = (location ?? Self.fallbackCenter).coordinate
        let today = Calendar.current.component(.weekday, from: .now) - 1
        var meetings: [Meeting] = []
        for (fIndex, fellowship) in Fellowship.allCases.enumerated() where fellowships.contains(fellowship) {
            for (index, name) in (Self.names[fellowship] ?? []).enumerated() {
                let seed = Double(fIndex * 7 + index + 1)
                let online = name.contains("Online") || name.contains("Virtual")
                let hour = 7 + (fIndex * 3 + index * 5) % 14
                let minute = index.isMultiple(of: 2) ? 0 : 30
                let latitude: Double? = online ? nil : center.latitude + sin(seed * 1.7) * 0.03
                let longitude: Double? = online ? nil : center.longitude + cos(seed * 1.3) * 0.04
                let address: String? = online ? nil : "\(120 + index * 35) Main Street"
                let zoom: URL? = online ? URL(string: "https://zoom.us/j/0000000000") : nil
                meetings.append(Meeting(
                    id: "mock-\(fellowship.rawValue)-\(index)",
                    name: name,
                    fellowship: fellowship,
                    weekday: (today + index) % 7,
                    time: String(format: "%02d:%02d", hour, minute),
                    endTime: String(format: "%02d:%02d", hour + 1, minute),
                    locationName: online ? nil : "Community Recovery Center",
                    address: address,
                    latitude: latitude,
                    longitude: longitude,
                    conferenceURL: zoom,
                    notes: "Sample meeting — add a Meeting Guide feed URL in Configuration.plist for live listings.",
                    types: online ? ["ONL", "O"] : ["O", "D"],
                    mode: online ? .online : .inPerson
                ))
            }
        }
        return meetings
    }
}
