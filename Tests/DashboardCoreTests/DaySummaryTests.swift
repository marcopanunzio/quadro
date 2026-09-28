import DashboardCore
import Foundation
import Testing

@Suite struct DaySummaryTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        c.firstWeekday = 2
        return c
    }()

    // "Oggi" fisso: 28 settembre 2026, 10:00 Europe/Rome.
    var fixedNow: Date {
        DateComponents(calendar: calendar, year: 2026, month: 9, day: 28, hour: 10, minute: 0).date!
    }

    var context: DateContext {
        let now = fixedNow
        return DateContext(calendar: calendar, now: { now })
    }

    private func time(_ hour: Int, _ minute: Int = 0, day: Int = 28) -> Date {
        DateComponents(calendar: calendar, year: 2026, month: 9, day: day, hour: hour, minute: minute).date!
    }

    private func event(
        id: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        title: String = "evento"
    ) -> CalendarEvent {
        CalendarEvent(id: id, eventIdentifier: id, calendarID: "cal", title: title, start: start, end: end, isAllDay: isAllDay)
    }

    @Test func eventCountIncludesAllDayEventsIntersectingToday() {
        let allDay = event(id: "allday", start: time(0), end: time(0, day: 29), isAllDay: true)
        let timed = event(id: "timed", start: time(8), end: time(9))
        let sections = TaskSections()
        let summary = DaySummary.make(events: [allDay, timed], sections: sections, context: context)
        #expect(summary.eventCount == 2)
    }

    @Test func eventTouchingTodayBoundaryDoesNotCount() {
        // Finisce esattamente a mezzanotte di oggi: non intersaca oggi.
        let yesterday = event(id: "y", start: time(20, day: 27), end: time(0, day: 28))
        let sections = TaskSections()
        let summary = DaySummary.make(events: [yesterday], sections: sections, context: context)
        #expect(summary.eventCount == 0)
    }

    @Test func currentEventIsTheOneInProgress() {
        let inProgress = event(id: "current", start: time(9), end: time(11))
        let later = event(id: "later", start: time(12), end: time(13))
        let sections = TaskSections()
        let summary = DaySummary.make(events: [inProgress, later], sections: sections, context: context)
        #expect(summary.current?.id == "current")
        #expect(summary.next?.id == "later")
    }

    @Test func currentPicksTheOneEndingSoonestWhenOverlapping() {
        let endsSoon = event(id: "endsSoon", start: time(9), end: time(10, 30))
        let endsLater = event(id: "endsLater", start: time(9), end: time(12))
        let sections = TaskSections()
        let summary = DaySummary.make(events: [endsSoon, endsLater], sections: sections, context: context)
        #expect(summary.current?.id == "endsSoon")
    }

    @Test func allDayEventsAreNeverCurrentOrNext() {
        let allDay = event(id: "allday", start: time(0), end: time(0, day: 29), isAllDay: true)
        let sections = TaskSections()
        let summary = DaySummary.make(events: [allDay], sections: sections, context: context)
        #expect(summary.current == nil)
        #expect(summary.next == nil)
        #expect(summary.eventCount == 1)
    }

    @Test func openTaskCountIsOverduePlusToday() {
        let sections = TaskSections(
            overdue: [TaskItem(id: "1", listID: "l", title: "a")],
            today: [TaskItem(id: "2", listID: "l", title: "b"), TaskItem(id: "3", listID: "l", title: "c")],
            toPlan: [TaskItem(id: "4", listID: "l", title: "d")]
        )
        let summary = DaySummary.make(events: [], sections: sections, context: context)
        #expect(summary.openTaskCount == 3)
    }
}
