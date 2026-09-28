import DashboardCore
import Foundation
import Testing

@Suite struct DateRangesTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        c.firstWeekday = 2 // lunedi'
        return c
    }()

    private func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        DateComponents(calendar: calendar, year: year, month: month, day: day, hour: hour, minute: minute).date!
    }

    @Test func weekStartsOnMonday() {
        // 30 settembre 2026 e' un mercoledi'.
        let interval = DateRanges.week(containing: date(year: 2026, month: 9, day: 30), calendar: calendar)
        #expect(interval.start == date(year: 2026, month: 9, day: 28))
        #expect(interval.end == date(year: 2026, month: 10, day: 5))
    }

    @Test func weekAcrossDSTHasTwentyFiveHourDay() {
        // La settimana che contiene il 25 ottobre 2026 (fine ora legale, domenica) va da lunedi' 19
        // a lunedi' 26 ottobre; la durata totale non e' 7*86400 secondi per via del giorno di 25 ore.
        let interval = DateRanges.week(containing: date(year: 2026, month: 10, day: 25), calendar: calendar)
        #expect(interval.start == date(year: 2026, month: 10, day: 19))
        #expect(interval.end == date(year: 2026, month: 10, day: 26))
        let expectedSeconds = 7.0 * 86400 + 3600 // un'ora in piu' per il cambio ora legale
        #expect(interval.duration == expectedSeconds)
    }

    @Test func dayIntervalOnDSTChangeIsTwentyFiveHours() {
        let day = DayDate(year: 2026, month: 10, day: 25)
        let interval = DateRanges.dayInterval(day, calendar: calendar)
        #expect(interval.duration == 25 * 3600)
    }

    @Test func daysInIntervalListsAllDays() {
        let interval = DateRanges.week(containing: date(year: 2026, month: 9, day: 28), calendar: calendar)
        let days = DateRanges.days(in: interval, calendar: calendar)
        #expect(days.count == 7)
        #expect(days.first == DayDate(year: 2026, month: 9, day: 28))
        #expect(days.last == DayDate(year: 2026, month: 10, day: 4))
    }

    @Test func monthGridSeptember2026HasFiveRowsFromAugust31ToOctober4() {
        let grid = DateRanges.monthGrid(containing: date(year: 2026, month: 9, day: 15), calendar: calendar)
        #expect(grid.count == 5)
        #expect(grid.allSatisfy { $0.count == 7 })
        #expect(grid.first?.first == DayDate(year: 2026, month: 8, day: 31))
        #expect(grid.last?.last == DayDate(year: 2026, month: 10, day: 4))
    }

    @Test func gridIntervalMatchesFirstAndLastDayOfGrid() {
        let grid = DateRanges.monthGrid(containing: date(year: 2026, month: 9, day: 15), calendar: calendar)
        let interval = DateRanges.gridInterval(containing: date(year: 2026, month: 9, day: 15), calendar: calendar)
        #expect(DayDate(interval.start, calendar: calendar) == grid.first?.first)
        let lastInstant = calendar.date(byAdding: .second, value: -1, to: interval.end)!
        #expect(DayDate(lastInstant, calendar: calendar) == grid.last?.last)
    }

    @Test func monthIntervalCoversFullCalendarMonth() {
        let interval = DateRanges.monthInterval(containing: date(year: 2026, month: 9, day: 15), calendar: calendar)
        #expect(interval.start == date(year: 2026, month: 9, day: 1))
        #expect(interval.end == date(year: 2026, month: 10, day: 1))
    }
}
