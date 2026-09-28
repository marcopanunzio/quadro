import Foundation

/// Calendario e "adesso" iniettabili, per rendere la logica testabile.
public struct DateContext: Sendable {
    public var calendar: Calendar
    public var now: @Sendable () -> Date

    public init(calendar: Calendar, now: @escaping @Sendable () -> Date) {
        self.calendar = calendar
        self.now = now
    }

    public static func live(firstWeekday: Int = 2) -> DateContext {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "it_IT")
        cal.timeZone = .current
        cal.firstWeekday = firstWeekday
        return DateContext(calendar: cal, now: { Date() })
    }

    public var today: DayDate { DayDate(now(), calendar: calendar) }
}
