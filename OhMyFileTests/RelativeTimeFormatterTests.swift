import Foundation
import Testing
@testable import OhMyFile

struct RelativeTimeFormatterTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func unit(secondsAgo: TimeInterval) -> RelativeTimeUnit {
        RelativeTimeFormatter.unit(
            for: now.addingTimeInterval(-secondsAgo),
            now: now
        )
    }

    @Test func underOneMinuteIsJustNow() {
        #expect(unit(secondsAgo: 0) == .justNow)
        #expect(unit(secondsAgo: 59) == .justNow)
    }

    @Test func minutes() {
        #expect(unit(secondsAgo: 60) == .minutes(1))
        #expect(unit(secondsAgo: 3_599) == .minutes(59))
    }

    @Test func hours() {
        #expect(unit(secondsAgo: 3_600) == .hours(1))
        #expect(unit(secondsAgo: 86_399) == .hours(23))
    }

    @Test func days() {
        #expect(unit(secondsAgo: 86_400) == .days(1))
        #expect(unit(secondsAgo: 29 * 86_400) == .days(29))
    }

    @Test func olderThanThirtyDaysFallsBackToDate() {
        let oldDate = now.addingTimeInterval(-30 * 86_400)
        #expect(unit(secondsAgo: 30 * 86_400) == .absolute(oldDate))
    }

    @Test func futureDateIsJustNow() {
        #expect(unit(secondsAgo: -120) == .justNow)
    }
}
