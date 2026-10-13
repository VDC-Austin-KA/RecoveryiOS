import Foundation
import CoreLocation
import CryptoKit

/// One public meeting listing (an intergroup feed, the NA aggregator, …).
protocol MeetingSource {
    var fellowship: Fellowship { get }
    func meetings(near location: CLLocation?) async throws -> [Meeting]
}

/// Queries every built-in public source concurrently. A failing source never hides the others.
/// HA and SMART Recovery publish no public data; the UI links to their official finders instead.
struct LiveMeetingProvider: MeetingProvider {
    var sources: [any MeetingSource]
    var radiusMeters: CLLocationDistance = 80_000

    static func standard(extraFeeds: [Fellowship: URL] = [:]) -> LiveMeetingProvider {
        var sources: [any MeetingSource] = TSMLSource.aaMetros + [TSMLSource.onlineAA, BMLTSource(), AlAnonSource()]
        for (fellowship, url) in extraFeeds {
            sources.append(TSMLSource(fellowship: fellowship, name: "Custom feed", feedURL: url))
        }
        return LiveMeetingProvider(sources: sources)
    }

    func meetings(near location: CLLocation?, fellowships: Set<Fellowship>) async throws -> [Meeting] {
        let active = sources.filter { fellowships.contains($0.fellowship) }
        var results: [Meeting] = []
        var lastError: Error?
        await withTaskGroup(of: Result<[Meeting], Error>.self) { group in
            for source in active {
                group.addTask {
                    do { return .success(try await source.meetings(near: location)) } catch { return .failure(error) }
                }
            }
            for await outcome in group {
                switch outcome {
                case let .success(meetings): results += meetings
                case let .failure(error): lastError = error
                }
            }
        }
        if results.isEmpty, let lastError { throw lastError }
        guard let location else { return results }
        // Online-only meetings have no coordinates and are always kept.
        return results.filter { ($0.distance(from: location) ?? 0) <= radiusMeters }
    }
}

// MARK: - On-disk cache

/// Feeds are 1–13 MB, so each download is kept in Caches and reused until `maxAge`;
/// when the network fails a stale copy is returned, which keeps meetings available offline.
enum FeedCache {
    static let headers = [
        // Some intergroup servers reject non-browser user agents (HTTP 406/404).
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Accept": "application/json, text/javascript, text/html;q=0.9, */*;q=0.8",
    ]

    static func fileURL(for url: URL) -> URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MeetingFeeds", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest)
    }

    static func data(from url: URL, maxAge: TimeInterval, session: URLSession = .shared) async throws -> Data {
        let file = fileURL(for: url)
        if let modified = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) < maxAge,
           let cached = try? Data(contentsOf: file) {
            return cached
        }
        do {
            var request = URLRequest(url: url, timeoutInterval: 60)
            for (field, value) in headers { request.setValue(value, forHTTPHeaderField: field) }
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            try? data.write(to: file, options: .atomic)
            return data
        } catch {
            if let stale = try? Data(contentsOf: file) { return stale }
            throw error
        }
    }
}

// MARK: - AA: Meeting Guide / TSML feeds

/// A 12 Step Meeting List (TSML) feed. Many intergroups publish a hashed cache file
/// (`tsml-cache-<hash>.json`) whose name changes; when `discoveryPage` is set the current
/// name is read from that page, falling back to the last known URL.
struct TSMLSource: MeetingSource {
    let fellowship: Fellowship
    let name: String
    let feedURL: URL
    var discoveryPage: URL?
    /// Regional feeds are only downloaded when the user is within `regionRadius` of this point.
    var center: CLLocationCoordinate2D?
    var regionRadius: CLLocationDistance = 150_000
    var maxAge: TimeInterval = 24 * 3600

    static let onlineAA = TSMLSource(
        fellowship: .aa,
        name: "Online Intergroup of AA",
        feedURL: URL(string: "https://data.aa-intergroup.org/6436f5a3f03fdecef8459055.json")!
    )

    static let aaMetros: [TSMLSource] = [
        TSMLSource(fellowship: .aa, name: "New York Intergroup",
                   feedURL: URL(string: "https://www.nyintergroup.org/wp-content/tsml-cache-7fd5dcc047.json?1791566961")!,
                   discoveryPage: URL(string: "https://www.nyintergroup.org/meetings/"),
                   center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)),
        TSMLSource(fellowship: .aa, name: "Austin Intergroup",
                   feedURL: URL(string: "https://austinaa.org/wp-content/tsml-cache-65d589c8a4.json")!,
                   discoveryPage: URL(string: "https://austinaa.org/meetings/"),
                   center: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431)),
        TSMLSource(fellowship: .aa, name: "Phoenix Intergroup",
                   feedURL: URL(string: "https://aaphoenix.org/wp-content/tsml-cache-42de28e160.json?1791461337")!,
                   discoveryPage: URL(string: "https://aaphoenix.org/meetings/"),
                   center: CLLocationCoordinate2D(latitude: 33.4484, longitude: -112.0740)),
        TSMLSource(fellowship: .aa, name: "Greater Seattle Intergroup",
                   feedURL: URL(string: "https://www.seattleaa.org/wp-admin/admin-ajax.php?action=meetings")!,
                   center: CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)),
        TSMLSource(fellowship: .aa, name: "San Francisco & Marin Intergroup",
                   feedURL: URL(string: "https://sheets.code4recovery.org/storage/aasfmarin.json")!,
                   center: CLLocationCoordinate2D(latitude: 37.8, longitude: -122.45)),
    ]

    func meetings(near location: CLLocation?) async throws -> [Meeting] {
        if let center {
            guard let location,
                  location.distance(from: CLLocation(latitude: center.latitude, longitude: center.longitude)) <= regionRadius
            else { return [] }
        }
        let url = await currentFeedURL()
        let data: Data
        do {
            data = try await FeedCache.data(from: url, maxAge: maxAge)
        } catch {
            guard url != feedURL else { throw error }
            data = try await FeedCache.data(from: feedURL, maxAge: maxAge)
        }
        return try OMLAMeeting.decodeFeed(data, fellowship: fellowship)
    }

    private func currentFeedURL() async -> URL {
        guard let discoveryPage,
              let html = try? await FeedCache.data(from: discoveryPage, maxAge: 3 * 86_400)
        else { return feedURL }
        return Self.cacheURL(inHTML: String(decoding: html, as: UTF8.self), base: discoveryPage) ?? feedURL
    }

    static func cacheURL(inHTML html: String, base: URL) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: #"[^"'\s=]*tsml-cache-[0-9a-f]+\.json[^"'\s<>]*"#) else { return nil }
        let ns = html as NSString
        guard let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let raw = ns.substring(with: match.range)
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "&amp;", with: "&")
        return URL(string: raw, relativeTo: base)?.absoluteURL
    }
}

// MARK: - NA: BMLT aggregator

/// Narcotics Anonymous meetings worldwide via the BMLT aggregator, queried by location
/// (negative `geo_width` = widen the radius until ~100 meetings are found).
struct BMLTSource: MeetingSource {
    let fellowship: Fellowship = .na

    static let fields = [
        "id_bigint", "meeting_name", "weekday_tinyint", "start_time", "time_zone", "latitude", "longitude",
        "location_text", "location_street", "location_municipality", "location_province",
        "virtual_meeting_link", "venue_type", "comments",
    ].joined(separator: ",")

    func meetings(near location: CLLocation?) async throws -> [Meeting] {
        guard let location else { return [] }
        var components = URLComponents(string: "https://aggregator.bmltenabled.org/main_server/client_interface/json/")!
        components.queryItems = [
            URLQueryItem(name: "switcher", value: "GetSearchResults"),
            URLQueryItem(name: "lat_val", value: String(format: "%.2f", location.coordinate.latitude)),
            URLQueryItem(name: "long_val", value: String(format: "%.2f", location.coordinate.longitude)),
            URLQueryItem(name: "geo_width", value: "-100"),
            URLQueryItem(name: "data_field_key", value: Self.fields),
        ]
        let data = try await FeedCache.data(from: components.url!, maxAge: 6 * 3600)
        return try Self.decode(data)
    }

    static func decode(_ data: Data) throws -> [Meeting] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }
        return rows.compactMap { row -> Meeting? in
            func value(_ key: String) -> String? {
                if let text = row[key] as? String { return text.isEmpty ? nil : text }
                return (row[key] as? NSNumber)?.stringValue
            }
            // BMLT weekday: 1 = Sunday … 7 = Saturday.
            guard let name = value("meeting_name"),
                  let bmltDay = value("weekday_tinyint").flatMap({ Int($0) }), (1...7).contains(bmltDay)
            else { return nil }
            let time = String((value("start_time") ?? "00:00").prefix(5))
            let mode: AttendanceMode
            switch value("venue_type") {
            case "2": mode = .online
            case "3": mode = .hybrid
            default: mode = .inPerson
            }
            let address = [value("location_street"), value("location_municipality"), value("location_province")]
                .compactMap { $0 }
                .joined(separator: ", ")
            return Meeting(
                id: "NA-\(value("id_bigint") ?? "\(name)-\(bmltDay)-\(time)")",
                name: name,
                fellowship: .na,
                weekday: bmltDay - 1,
                time: time,
                endTime: nil,
                locationName: value("location_text"),
                address: address.isEmpty ? nil : address,
                latitude: mode == .online ? nil : value("latitude").flatMap { Double($0) },
                longitude: mode == .online ? nil : value("longitude").flatMap { Double($0) },
                conferenceURL: value("virtual_meeting_link").flatMap { URL(string: $0) },
                notes: value("comments"),
                types: [],
                mode: mode,
                timeZone: value("time_zone")
            )
        }
    }
}

// MARK: - Al-Anon

/// Al-Anon's official meeting finder data (a JSONP store-locator file, ~13 MB, refreshed weekly).
/// Day/time are free text such as "Thursday 5:30 PM", so they are parsed from the record's strings.
struct AlAnonSource: MeetingSource {
    let fellowship: Fellowship = .alAnon
    static let url = URL(string: "https://cdn.storelocatorwidgets.com/json/cba0758378166b88cf39e82d3f2d02af")!
    var radiusMeters: CLLocationDistance = 80_000

    func meetings(near location: CLLocation?) async throws -> [Meeting] {
        guard let location else { return [] }
        let data = try await FeedCache.data(from: Self.url, maxAge: 7 * 86_400)
        return try Self.decode(data, near: location, radius: radiusMeters)
    }

    private static let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

    static func decode(_ data: Data, near location: CLLocation, radius: CLLocationDistance) throws -> [Meeting] {
        let text = String(decoding: data, as: UTF8.self)
        guard let open = text.firstIndex(of: "{"), let close = text.lastIndex(of: "}"), open < close,
              let root = try JSONSerialization.jsonObject(with: Data(text[open...close].utf8)) as? [String: Any],
              let stores = root["stores"] as? [[String: Any]]
        else { throw URLError(.cannotParseResponse) }
        let regex = try NSRegularExpression(
            pattern: #"(sunday|monday|tuesday|wednesday|thursday|friday|saturday)\s+(\d{1,2}):(\d{2})\s*([ap])\.?m"#,
            options: .caseInsensitive
        )

        func number(_ any: Any?) -> Double? {
            if let value = any as? NSNumber { return value.doubleValue }
            return (any as? String).flatMap { Double($0) }
        }

        var meetings: [Meeting] = []
        for (index, store) in stores.enumerated() {
            guard let info = store["data"] as? [String: Any],
                  let lat = number(info["map_lat"]), let lng = number(info["map_lng"]),
                  location.distance(from: CLLocation(latitude: lat, longitude: lng)) <= radius
            else { continue }
            let name = (info["description"] as? String) ?? (store["name"] as? String) ?? "Al-Anon meeting"
            let storeID = (store["storeid"] as? String) ?? (store["storeid"] as? NSNumber)?.stringValue ?? "\(index)"
            var seen = Set<String>()
            for case let field as String in info.values {
                let ns = field as NSString
                for match in regex.matches(in: field, range: NSRange(location: 0, length: ns.length)) {
                    guard let day = weekdays.firstIndex(of: ns.substring(with: match.range(at: 1)).lowercased()),
                          var hour = Int(ns.substring(with: match.range(at: 2))),
                          let minute = Int(ns.substring(with: match.range(at: 3))), hour <= 12, minute < 60
                    else { continue }
                    let pm = ns.substring(with: match.range(at: 4)).lowercased() == "p"
                    if pm, hour < 12 { hour += 12 }
                    if !pm, hour == 12 { hour = 0 }
                    let time = String(format: "%02d:%02d", hour, minute)
                    guard seen.insert("\(day)-\(time)").inserted else { continue }
                    meetings.append(Meeting(
                        id: "alanon-\(storeID)-\(day)-\(time)",
                        name: name,
                        fellowship: .alAnon,
                        weekday: day,
                        time: time,
                        endTime: nil,
                        locationName: store["name"] as? String,
                        address: info["address"] as? String,
                        latitude: lat,
                        longitude: lng,
                        conferenceURL: nil,
                        notes: nil,
                        types: [],
                        mode: .inPerson
                    ))
                }
            }
        }
        return meetings
    }
}
