import Foundation

/// Riepilogo della barra superiore per il giorno corrente.
public struct DaySummary: Equatable, Sendable {
    public var current: CalendarEvent?
    public var next: CalendarEvent?
    public var eventCount: Int
    public var openTaskCount: Int

    public init(current: CalendarEvent? = nil, next: CalendarEvent? = nil, eventCount: Int = 0, openTaskCount: Int = 0) {
        self.current = current
        self.next = next
        self.eventCount = eventCount
        self.openTaskCount = openTaskCount
    }

    /// Costruisce il riepilogo a partire dagli eventi (già filtrati sui calendari visibili) e dalle sezioni task.
    public static func make(events: [CalendarEvent], sections: TaskSections, context: DateContext) -> DaySummary {
        let now = context.now()
        let today = context.today
        let todayInterval = DateRanges.dayInterval(today, calendar: context.calendar)

        // Eventi che intersecano oggi (gli estremi che si toccano non contano).
        let todaysEvents = events.filter { $0.start < todayInterval.end && $0.end > todayInterval.start }

        let currentCandidates = todaysEvents.filter { !$0.isAllDay && $0.start <= now && now < $0.end }
        let current = currentCandidates.min { $0.end < $1.end }

        let nextCandidates = todaysEvents.filter { !$0.isAllDay && $0.start > now }
        let next = nextCandidates.min { $0.start < $1.start }

        return DaySummary(
            current: current,
            next: next,
            eventCount: todaysEvents.count,
            openTaskCount: sections.overdue.count + sections.today.count
        )
    }
}
