import DashboardCore
import Foundation
import Testing

@Suite struct DayDateTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }()

    @Test func ordering() {
        #expect(DayDate(year: 2026, month: 9, day: 30) < DayDate(year: 2026, month: 10, day: 1))
    }

    @Test func addingDaysCrossesMonth() {
        let d = DayDate(year: 2026, month: 9, day: 28).adding(days: 4, calendar: calendar)
        #expect(d == DayDate(year: 2026, month: 10, day: 2))
    }

    @Test func roundTripsThroughDate() {
        let d = DayDate(year: 2026, month: 3, day: 29)
        #expect(DayDate(d.startDate(in: calendar), calendar: calendar) == d)
    }
}
