import Foundation

/// Calcolo delle ore occupate in un giorno, per la visualizzazione della densità.
public enum Density {
    /// Ore occupate nel giorno: unione degli intervalli degli eventi (le sovrapposizioni non
    /// contano due volte), ritagliati sul giorno. Gli eventi all-day sono esclusi.
    public static func busyHours(on day: DayDate, events: [CalendarEvent], calendar: Calendar) -> Double {
        let dayInterval = DateRanges.dayInterval(day, calendar: calendar)

        let clipped: [(start: Date, end: Date)] = events.compactMap { event in
            guard !event.isAllDay else { return nil }
            let start = max(event.start, dayInterval.start)
            let end = min(event.end, dayInterval.end)
            guard start < end else { return nil }
            return (start, end)
        }

        let merged = mergeIntervals(clipped)
        let totalSeconds = merged.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
        return totalSeconds / 3600.0
    }

    private static func mergeIntervals(_ intervals: [(start: Date, end: Date)]) -> [(start: Date, end: Date)] {
        guard !intervals.isEmpty else { return [] }
        let sorted = intervals.sorted { $0.start < $1.start }
        var result: [(start: Date, end: Date)] = [sorted[0]]
        for interval in sorted.dropFirst() {
            let lastIndex = result.count - 1
            if interval.start <= result[lastIndex].end {
                result[lastIndex].end = max(result[lastIndex].end, interval.end)
            } else {
                result.append(interval)
            }
        }
        return result
    }
}
