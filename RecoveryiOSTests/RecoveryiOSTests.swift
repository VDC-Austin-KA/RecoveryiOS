import XCTest
import CoreLocation
import CryptoKit
@testable import RecoveryiOS

final class SobrietyStatsTests: XCTestCase {
    func testCountsDaysSavingsAndMilestones() {
        let start = Date(timeIntervalSince1970: 0)
        let stats = SobrietyStats(start: start, now: start.addingTimeInterval(10 * 86_400), dailySpend: 15, dailyHours: 2)
        XCTAssertEqual(stats.days, 10)
        XCTAssertEqual(stats.totalHours, 240)
        XCTAssertEqual(stats.moneySaved, 150, accuracy: 0.001)
        XCTAssertEqual(stats.hoursReclaimed, 20, accuracy: 0.001)
        XCTAssertEqual(stats.unlocked.map(\.days), [1, 7])
        XCTAssertEqual(stats.nextMilestone?.days, 30)
        XCTAssertEqual(stats.progressToNext, 3.0 / 23.0, accuracy: 0.0001)
    }

    func testFutureStartDateClampsToZero() {
        let now = Date()
        let stats = SobrietyStats(start: now.addingTimeInterval(86_400), now: now, dailySpend: 10, dailyHours: 1)
        XCTAssertEqual(stats.days, 0)
        XCTAssertEqual(stats.moneySaved, 0)
        XCTAssertTrue(stats.unlocked.isEmpty)
    }
}

final class MeetingGuideDecodingTests: XCTestCase {
    func testDecodesOMLAFeedVariants() throws {
        let json = """
        [
          {"name": "Morning Serenity", "slug": "morning-serenity", "day": [1, 3], "time": "07:00",
           "location": "St. Mark's", "formatted_address": "1 Main St, Austin, TX",
           "latitude": "30.2672", "longitude": -97.7431, "types": ["O", "D"]},
          {"name": "Online Hope", "slug": "online-hope", "day": 0, "time": "19:30",
           "conference_url": "https://zoom.us/j/123", "types": ["ONL"], "attendance_option": "online"},
          {"name": "Closed Group", "day": "5", "time": "12:00", "attendance_option": "inactive"}
        ]
        """
        let meetings = try MeetingGuideProvider.decode(Data(json.utf8), fellowship: .aa)
        XCTAssertEqual(meetings.count, 3, "two days for the first meeting, one online, inactive skipped")
        XCTAssertEqual(meetings[0].latitude, 30.2672)
        XCTAssertEqual(meetings[0].weekday, 1)
        XCTAssertEqual(meetings[1].weekday, 3)
        XCTAssertEqual(meetings[0].mode, .inPerson)
        XCTAssertEqual(meetings[2].mode, .online)
        XCTAssertNil(meetings[2].coordinate)
        XCTAssertEqual(meetings[2].conferenceURL?.absoluteString, "https://zoom.us/j/123")
        XCTAssertEqual(Set(meetings.map(\.id)).count, meetings.count, "ids must be unique per day")
    }

    func testMockProviderHonorsFellowshipFilter() async throws {
        let meetings = try await MockMeetingProvider().meetings(near: nil, fellowships: [.smart, .ha])
        XCTAssertFalse(meetings.isEmpty)
        XCTAssertTrue(meetings.allSatisfy { $0.fellowship == .smart || $0.fellowship == .ha })
        XCTAssertTrue(meetings.contains { $0.mode == .online })
    }

    func testNextOccurrenceLandsOnMeetingWeekday() throws {
        let meeting = Meeting(id: "x", name: "Test", fellowship: .na, weekday: 2, time: "18:45", endTime: nil,
                              locationName: nil, address: nil, latitude: nil, longitude: nil,
                              conferenceURL: nil, notes: nil, types: [], mode: .inPerson)
        let next = try XCTUnwrap(meeting.nextOccurrence())
        let parts = Calendar.current.dateComponents([.weekday, .hour, .minute], from: next)
        XCTAssertEqual(parts.weekday, 3) // Calendar: 1 = Sunday; OMLA 2 = Tuesday
        XCTAssertEqual(parts.hour, 18)
        XCTAssertEqual(parts.minute, 45)
        XCTAssertGreaterThan(next, Date())
    }
}

final class ScheduleAssistantTests: XCTestCase {
    func testParsesTimes() {
        XCTAssertEqual(ScheduleAssistant.parseTime("AA meeting at 7:30pm")?.hour, 19)
        XCTAssertEqual(ScheduleAssistant.parseTime("AA meeting at 7:30pm")?.minute, 30)
        XCTAssertEqual(ScheduleAssistant.parseTime("lunch at noon")?.hour, 12)
        XCTAssertEqual(ScheduleAssistant.parseTime("standup 10:15")?.hour, 10)
        XCTAssertEqual(ScheduleAssistant.parseTime("12am")?.hour, 0)
        XCTAssertNil(ScheduleAssistant.parseTime("work on step 4"))
    }

    func testBuildsRecoveryFirstPlan() {
        let day = Date()
        let plan = ScheduleAssistant.plan(from: "Work 9am-5pm, AA meeting at 7:30pm, call sponsor", on: day)
        let meeting = plan.first { $0.category == .meeting }
        XCTAssertEqual(meeting.map { Calendar.current.component(.hour, from: $0.start) }, 19)
        XCTAssertEqual(meeting?.priority, 2)
        XCTAssertTrue(plan.contains { $0.category == .sponsor })
        XCTAssertTrue(plan.contains { $0.category == .reflection }, "morning/evening anchors are added")
        XCTAssertEqual(plan.filter { $0.category == .meeting }.count, 1, "no duplicate meeting anchor when one is planned")
        XCTAssertEqual(plan.map(\.start), plan.map(\.start).sorted())
        XCTAssertTrue(plan.allSatisfy { Calendar.current.isDate($0.start, inSameDayAs: day) })
    }

    func testCategorizes() {
        XCTAssertEqual(ScheduleAssistant.categorize("Big Book study"), .stepWork)
        XCTAssertEqual(ScheduleAssistant.categorize("morning meditation"), .reflection)
        XCTAssertEqual(ScheduleAssistant.categorize("gym"), .selfCare)
        XCTAssertEqual(ScheduleAssistant.categorize("buy groceries"), .other)
    }
}

final class AIAndConfigTests: XCTestCase {
    func testMockLLMTailorsToPathwayAndMode() async throws {
        let client = MockLLMClient(latency: .zero)
        let smart = try await client.complete(system: RecoveryPathway.selfManagement.systemPrompt,
                                              messages: [ChatTurn(role: .user, content: "I have a craving")])
        XCTAssertTrue(smart.contains("DISARM"))
        let grounding = try await client.complete(system: RecoveryPrompts.grounding(for: .twelveStep),
                                                  messages: [ChatTurn(role: .user, content: "help")])
        XCTAssertTrue(grounding.contains("five things"))
        let crisis = try await client.complete(system: RecoveryPathway.gratitude.systemPrompt,
                                               messages: [ChatTurn(role: .user, content: "I want to kill myself")])
        XCTAssertTrue(crisis.contains("988"))
    }

    func testEveryPathwayPromptIsTraumaInformed() {
        for pathway in RecoveryPathway.allCases {
            XCTAssertTrue(pathway.systemPrompt.contains("trauma-informed"))
            XCTAssertTrue(pathway.systemPrompt.contains(pathway.marker))
        }
    }

    func testConfigurationPrefersEnvironmentAndIgnoresPlaceholders() {
        let config = AppConfiguration.load(
            bundle: Bundle(for: AIAndConfigTests.self),
            environment: [
                "OPENAI_API_KEY": " sk-test ",
                "ANTHROPIC_API_KEY": "YOUR_ANTHROPIC_API_KEY",
                "MEETING_FEED_NA": "https://example.org/na.json",
            ]
        )
        XCTAssertEqual(config.openAIKey, "sk-test")
        XCTAssertNil(config.anthropicKey)
        XCTAssertEqual(config.meetingFeeds[.na]?.host, "example.org")
        XCTAssertNil(config.meetingFeeds[.aa])
    }

    func testFactoryFallsBackToMock() {
        let client = LLMFactory.make(configuration: AppConfiguration(), preference: .mock)
        XCTAssertTrue(client is MockLLMClient)
    }

    func testInspirationRotatesDaily() {
        let today = Date()
        let tomorrow = today.addingTimeInterval(86_400)
        XCTAssertNotEqual(InspirationEngine.quote(for: today), InspirationEngine.quote(for: tomorrow))
        XCTAssertEqual(InspirationEngine.mediaPicks(for: today).count, 2)
    }
}

final class JournalCipherTests: XCTestCase {
    func testRoundTripAndTamperDetection() throws {
        let cipher = JournalCipher(key: SymmetricKey(size: .bits256))
        let sealed = try cipher.seal("Grateful for a clear morning ☀️")
        XCTAssertFalse(String(decoding: sealed, as: UTF8.self).contains("Grateful"))
        XCTAssertEqual(try cipher.open(sealed), "Grateful for a clear morning ☀️")

        var bytes = Array(sealed)
        bytes[bytes.count - 1] ^= 0xFF
        let tampered = Data(bytes)
        XCTAssertThrowsError(try cipher.open(tampered))

        let otherKey = JournalCipher(key: SymmetricKey(size: .bits256))
        XCTAssertThrowsError(try otherKey.open(sealed))
    }
}
