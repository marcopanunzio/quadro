// Solo funzioni pure di mapping: nessun permesso, nessun accesso a EventKit reale.
import CoreGraphics
@testable import DashboardServices
import DashboardCore
import EventKit
import Foundation
import Testing

@Suite struct EventOccurrenceIDTests {
    @Test func roundTrip() {
        let date = Date(timeIntervalSince1970: 1_790_000_000.5)
        let id = EventOccurrenceID.encode(eventIdentifier: "ABC-123", occurrenceDate: date)
        let decoded = EventOccurrenceID.decode(id)
        #expect(decoded?.eventIdentifier == "ABC-123")
        #expect(decoded.map { EventOccurrenceID.isSameInstant($0.occurrenceDate, date) } == true)
    }

    @Test func roundTripWithPipeInIdentifier() {
        // eventIdentifier reali non contengono "|", ma il decode deve comunque essere robusto:
        // si divide sull'ultimo separatore, quindi la parte identificativa resta intatta.
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let weirdIdentifier = "strano|id-con-pipe"
        let id = EventOccurrenceID.encode(eventIdentifier: weirdIdentifier, occurrenceDate: date)
        let decoded = EventOccurrenceID.decode(id)
        #expect(decoded?.eventIdentifier == weirdIdentifier)
        #expect(decoded.map { EventOccurrenceID.isSameInstant($0.occurrenceDate, date) } == true)
    }

    @Test func roundTripWithUnicodeIdentifier() {
        let date = Date(timeIntervalSince1970: 1_650_000_000)
        let identifier = "événement-日本語-🎉"
        let id = EventOccurrenceID.encode(eventIdentifier: identifier, occurrenceDate: date)
        let decoded = EventOccurrenceID.decode(id)
        #expect(decoded?.eventIdentifier == identifier)
    }

    @Test func decodeInvalidReturnsNil() {
        #expect(EventOccurrenceID.decode("nessun-separatore") == nil)
        #expect(EventOccurrenceID.decode("id|non-un-numero") == nil)
    }
}

@Suite struct EventKitPriorityTests {
    @Test(arguments: [
        (1, TaskPriority.high), (2, .high), (3, .high), (4, .high),
        (5, .medium),
        (6, .low), (7, .low), (8, .low), (9, .low),
        (0, .none),
    ])
    func eventKitToTaskPriority(raw: Int, expected: TaskPriority) {
        #expect(EventKitPriority.toTaskPriority(raw) == expected)
    }

    @Test func outOfRangeMapsToNone() {
        #expect(EventKitPriority.toTaskPriority(10) == .none)
        #expect(EventKitPriority.toTaskPriority(-1) == .none)
    }

    @Test(arguments: [
        (TaskPriority.high, 1), (.medium, 5), (.low, 9), (.none, 0),
    ])
    func taskPriorityToEventKit(priority: TaskPriority, expected: Int) {
        #expect(EventKitPriority.toEventKitPriority(priority) == expected)
    }
}

@Suite struct EventKitDueDateTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }()

    @Test func dayOnlyComponentsMapToDay() {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 28
        let due = EventKitDueDate.toTaskDue(components, calendar: calendar)
        #expect(due == .day(DayDate(year: 2026, month: 9, day: 28)))
    }

    @Test func componentsWithHourMapToDateTime() {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 28
        components.hour = 14
        components.minute = 30
        let due = EventKitDueDate.toTaskDue(components, calendar: calendar)
        guard case .dateTime(let date) = due else {
            Issue.record("atteso .dateTime")
            return
        }
        let readBack = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        #expect(readBack.year == 2026)
        #expect(readBack.month == 9)
        #expect(readBack.day == 28)
        #expect(readBack.hour == 14)
        #expect(readBack.minute == 30)
    }

    @Test func missingDateComponentsMapToNil() {
        var components = DateComponents()
        components.hour = 10
        #expect(EventKitDueDate.toTaskDue(components, calendar: calendar) == nil)
    }

    @Test func dayMapsBackToYearMonthDayOnly() {
        let due = TaskDue.day(DayDate(year: 2027, month: 1, day: 5))
        let components = EventKitDueDate.toDateComponents(due, calendar: calendar)
        #expect(components.year == 2027)
        #expect(components.month == 1)
        #expect(components.day == 5)
        #expect(components.hour == nil)
        #expect(components.minute == nil)
    }

    @Test func dateTimeMapsBackToYearThroughMinute() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 12, day: 24, hour: 18, minute: 45))!
        let due = TaskDue.dateTime(date)
        let components = EventKitDueDate.toDateComponents(due, calendar: calendar)
        #expect(components.year == 2026)
        #expect(components.month == 12)
        #expect(components.day == 24)
        #expect(components.hour == 18)
        #expect(components.minute == 45)
    }

    @Test func fullRoundTripDayThenBack() {
        let original = TaskDue.day(DayDate(year: 2026, month: 3, day: 15))
        let components = EventKitDueDate.toDateComponents(original, calendar: calendar)
        let roundTripped = EventKitDueDate.toTaskDue(components, calendar: calendar)
        #expect(roundTripped == original)
    }

    @Test func fullRoundTripDateTimeThenBack() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9, minute: 15))!
        let original = TaskDue.dateTime(date)
        let components = EventKitDueDate.toDateComponents(original, calendar: calendar)
        let roundTripped = EventKitDueDate.toTaskDue(components, calendar: calendar)
        #expect(roundTripped == original)
    }
}

@Suite struct EventKitCalendarKindTests {
    @Test func birthday() {
        #expect(EventKitCalendarKind.kind(for: .birthday) == .birthday)
    }

    @Test func subscription() {
        #expect(EventKitCalendarKind.kind(for: .subscription) == .subscription)
    }

    @Test(arguments: [EKCalendarType.local, .calDAV, .exchange])
    func standard(type: EKCalendarType) {
        #expect(EventKitCalendarKind.kind(for: type) == .standard)
    }
}

@Suite struct EventKitColorTests {
    @Test func convertsSRGBRed() {
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        let color = CGColor(colorSpace: srgb, components: [1, 0, 0, 1])!
        let rgb = EventKitColor.rgb(from: color)
        #expect(abs(rgb.r - 1) < 0.001)
        #expect(abs(rgb.g - 0) < 0.001)
        #expect(abs(rgb.b - 0) < 0.001)
    }

    @Test func convertsFromDeviceRGB() {
        let deviceSpace = CGColorSpaceCreateDeviceRGB()
        let color = CGColor(colorSpace: deviceSpace, components: [0, 1, 0, 1])!
        let rgb = EventKitColor.rgb(from: color)
        #expect(rgb.g > 0.9)
    }

    @Test func nilColorMapsToBlack() {
        let rgb = EventKitColor.rgb(from: nil)
        #expect(rgb == RGB(r: 0, g: 0, b: 0))
    }
}

@Suite struct AlarmShiftTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    @Test func timeToTimeKeepsOffset() {
        let shifted = EventKitDueDate.shiftedAlarmDate(date(28, 14, 45), from: .dateTime(date(28, 15)), to: .dateTime(date(29, 10)), calendar: calendar)
        #expect(shifted == date(29, 9, 45))
    }

    @Test func dayToDayKeepsAlarmTime() {
        let shifted = EventKitDueDate.shiftedAlarmDate(
            date(28, 9),
            from: .day(DayDate(year: 2026, month: 9, day: 28)),
            to: .day(DayDate(year: 2026, month: 9, day: 29)),
            calendar: calendar
        )
        #expect(shifted == date(29, 9))
    }

    @Test func timeToDayMovesByDays() {
        let shifted = EventKitDueDate.shiftedAlarmDate(date(28, 15), from: .dateTime(date(28, 15)), to: .day(DayDate(year: 2026, month: 9, day: 30)), calendar: calendar)
        #expect(shifted == date(30, 15))
    }
}
