import Foundation
import CoreLocation

enum Fellowship: String, CaseIterable, Identifiable, Codable, Hashable {
    case aa = "AA"
    case na = "NA"
    case ha = "HA"
    case smart = "SMART"
    case alAnon = "Al-Anon"

    var id: String { rawValue }

    var fullName: String {
        switch self {
        case .aa: "Alcoholics Anonymous"
        case .na: "Narcotics Anonymous"
        case .ha: "Heroin Anonymous"
        case .smart: "SMART Recovery"
        case .alAnon: "Al-Anon Family Groups"
        }
    }

    var feedConfigKey: String {
        switch self {
        case .aa: "MEETING_FEED_AA"
        case .na: "MEETING_FEED_NA"
        case .ha: "MEETING_FEED_HA"
        case .smart: "MEETING_FEED_SMART"
        case .alAnon: "MEETING_FEED_ALANON"
        }
    }

    /// Official web meeting finder (HA and SMART publish no machine-readable data).
    var officialFinderURL: URL {
        switch self {
        case .aa: URL(string: "https://www.aa.org/find-aa-resources")!
        case .na: URL(string: "https://www.na.org/meetingsearch/")!
        case .ha: URL(string: "https://heroinanonymous.org/meetings/")!
        case .smart: URL(string: "https://meetings.smartrecovery.org/meetings/")!
        case .alAnon: URL(string: "https://al-anon.org/al-anon-meetings/find-an-al-anon-meeting/")!
        }
    }

    var icon: String {
        switch self {
        case .aa: "a.circle.fill"
        case .na: "n.circle.fill"
        case .ha: "h.circle.fill"
        case .smart: "brain.head.profile"
        case .alAnon: "figure.2.and.child.holdinghands"
        }
    }
}

enum AttendanceMode: String, Codable, CaseIterable, Identifiable {
    case inPerson = "In-Person"
    case online = "Virtual"
    case hybrid = "Hybrid"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .inPerson: "person.3.fill"
        case .online: "video.fill"
        case .hybrid: "person.crop.rectangle.stack.fill"
        }
    }
}

/// A single weekly meeting occurrence (OMLA meetings with several days are split per day).
struct Meeting: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var fellowship: Fellowship
    /// OMLA convention: 0 = Sunday … 6 = Saturday.
    var weekday: Int
    /// 24h "HH:mm".
    var time: String
    var endTime: String?
    var locationName: String?
    var address: String?
    var latitude: Double?
    var longitude: Double?
    var conferenceURL: URL?
    var notes: String?
    var types: [String]
    var mode: AttendanceMode
    /// IANA zone the meeting time is expressed in (online meetings span the globe); nil = local.
    var timeZone: String? = nil

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(from location: CLLocation?) -> CLLocationDistance? {
        guard let location, let latitude, let longitude else { return nil }
        return location.distance(from: CLLocation(latitude: latitude, longitude: longitude))
    }

    var dayName: String {
        let symbols = Calendar.current.weekdaySymbols
        return symbols[((weekday % 7) + 7) % 7]
    }

    var hourMinute: (hour: Int, minute: Int) {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        return (parts.first ?? 0, parts.count > 1 ? parts[1] : 0)
    }

    var formattedTime: String {
        var components = DateComponents()
        components.hour = hourMinute.hour
        components.minute = hourMinute.minute
        guard let date = Calendar.current.date(from: components) else { return time }
        let formatted = date.formatted(date: .omitted, time: .shortened)
        return timeZoneLabel.map { "\(formatted) \($0)" } ?? formatted
    }

    /// Abbreviation of the meeting's time zone when it differs from the device's.
    var timeZoneLabel: String? {
        guard let timeZone, let zone = TimeZone(identifier: timeZone),
              zone.secondsFromGMT() != TimeZone.current.secondsFromGMT() else { return nil }
        return zone.abbreviation()
    }

    var isToday: Bool {
        Calendar.current.component(.weekday, from: .now) == weekday + 1
    }

    func nextOccurrence(after date: Date = .now, calendar: Calendar = .current) -> Date? {
        var components = DateComponents()
        components.weekday = weekday + 1
        components.hour = hourMinute.hour
        components.minute = hourMinute.minute
        var calendar = calendar
        if let timeZone, let zone = TimeZone(identifier: timeZone) { calendar.timeZone = zone }
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
    }
}

enum RecoveryPathway: String, CaseIterable, Identifiable, Codable {
    case twelveStep
    case mindfulness
    case gratitude
    case selfManagement

    var id: String { rawValue }

    var title: String {
        switch self {
        case .twelveStep: "12-Step Framework"
        case .mindfulness: "Mindfulness & Spiritual Openness"
        case .gratitude: "Positive Energy & Gratitude"
        case .selfManagement: "Self-Management (SMART/CBT)"
        }
    }

    var icon: String {
        switch self {
        case .twelveStep: "stairs"
        case .mindfulness: "leaf.fill"
        case .gratitude: "sun.max.fill"
        case .selfManagement: "brain.head.profile"
        }
    }

    var summary: String {
        switch self {
        case .twelveStep: "Step work prompts, inventory tools and literature guidance."
        case .mindfulness: "Present-moment awareness, meditation and spiritual openness."
        case .gratitude: "Strength-based optimism, gratitude practice and affirmations."
        case .selfManagement: "Evidence-based tools: urge surfing, ABCs, cost-benefit analysis."
        }
    }

    /// Tag embedded in system prompts so the offline responder can tailor its replies.
    var marker: String { "[PATHWAY:\(rawValue)]" }

    var systemPrompt: String { RecoveryPrompts.system(for: self) }
}

struct Milestone: Identifiable, Hashable {
    let days: Int
    let title: String
    let icon: String

    var id: Int { days }

    static let all: [Milestone] = [
        Milestone(days: 1, title: "24 Hours", icon: "sunrise.fill"),
        Milestone(days: 7, title: "1 Week", icon: "7.circle.fill"),
        Milestone(days: 30, title: "30 Days", icon: "calendar"),
        Milestone(days: 60, title: "60 Days", icon: "leaf.fill"),
        Milestone(days: 90, title: "90 Days", icon: "star.fill"),
        Milestone(days: 180, title: "6 Months", icon: "flame.fill"),
        Milestone(days: 270, title: "9 Months", icon: "sparkles"),
        Milestone(days: 365, title: "1 Year", icon: "medal.fill"),
        Milestone(days: 730, title: "2 Years", icon: "trophy.fill"),
        Milestone(days: 1825, title: "5 Years", icon: "crown.fill"),
    ]
}

struct SobrietyStats {
    let start: Date
    let now: Date
    let dailySpend: Double
    let dailyHours: Double

    private var interval: TimeInterval { max(0, now.timeIntervalSince(start)) }

    var days: Int {
        max(0, Calendar.current.dateComponents([.day], from: start, to: now).day ?? 0)
    }

    var totalHours: Int { Int(interval / 3600) }
    var moneySaved: Double { interval / 86_400 * dailySpend }
    var hoursReclaimed: Double { interval / 86_400 * dailyHours }
    var unlocked: [Milestone] { Milestone.all.filter { $0.days <= days } }
    var nextMilestone: Milestone? { Milestone.all.first { $0.days > days } }

    var progressToNext: Double {
        guard let next = nextMilestone else { return 1 }
        let previous = unlocked.last?.days ?? 0
        return Double(days - previous) / Double(next.days - previous)
    }
}
