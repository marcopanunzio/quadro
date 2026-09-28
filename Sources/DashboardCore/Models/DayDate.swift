import Foundation

/// Un giorno di calendario senza ora né fuso (es. la scadenza di un promemoria "solo data").
public struct DayDate: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    /// Mezzanotte di questo giorno nel fuso del calendario.
    public func startDate(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public func adding(days: Int, calendar: Calendar) -> DayDate {
        DayDate(calendar.date(byAdding: .day, value: days, to: startDate(in: calendar))!, calendar: calendar)
    }

    public static func < (lhs: DayDate, rhs: DayDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
