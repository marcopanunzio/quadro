import DashboardCore
import Foundation
import Testing

@Suite struct DensityTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }()

    let day = DayDate(year: 2026, month: 9, day: 28)

    private func time(_ hour: Int, _ minute: Int = 0, day: Int = 28) -> Date {
        DateComponents(calendar: calendar, year: 2026, month: 9, day: day, hour: hour, minute: minute).date!
    }

    private func event(id: String, start: Date, end: Date, isAllDay: Bool = false) -> CalendarEvent {
        CalendarEvent(id: id, eventIdentifier: id, calendarID: "cal", title: "evento", start: start, end: end, isAllDay: isAllDay)
    }

    @Test func noEventsMeansZeroBusyHours() {
        #expect(Density.busyHours(on: day, events: [], calendar: calendar) == 0)
    }

    @Test func singleEventCountsItsDuration() {
        let e = event(id: "1", start: time(9), end: time(11))
        #expect(Density.busyHours(on: day, events: [e], calendar: calendar) == 2)
    }

    @Test func overlappingEventsAreNotCountedTwice() {
        let a = event(id: "a", start: time(9), end: time(11))
        let b = event(id: "b", start: time(10), end: time(12))
        #expect(Density.busyHours(on: day, events: [a, b], calendar: calendar) == 3)
    }

    @Test func nonOverlappingEventsSum() {
        let a = event(id: "a", start: time(9), end: time(10))
        let b = event(id: "b", start: time(14), end: time(16))
        #expect(Density.busyHours(on: day, events: [a, b], calendar: calendar) == 3)
    }

    @Test func allDayEventsAreExcluded() {
        let allDay = event(id: "allday", start: time(0), end: time(0, day: 29), isAllDay: true)
        #expect(Density.busyHours(on: day, events: [allDay], calendar: calendar) == 0)
    }

    @Test func eventIsClippedToTheDay() {
        // Inizia il giorno prima e finisce il giorno dopo: dentro il giorno conta solo 24 ore.
        let spanning = event(id: "s", start: time(20, day: 27), end: time(4, day: 29))
        #expect(Density.busyHours(on: day, events: [spanning], calendar: calendar) == 24)
    }
}
