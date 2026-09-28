import Foundation

/// Intervalli di calendario (settimana, giorno, griglia mensile). Usa sempre l'aritmetica
/// del `Calendar` (mai `86400` secondi fissi) per gestire correttamente l'ora legale.
public enum DateRanges {
    /// Intervallo dei 7 giorni della settimana che contiene `date`, a partire da `calendar.firstWeekday`.
    public static func week(containing date: Date, calendar: Calendar) -> DateInterval {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let firstWeekday = calendar.firstWeekday
        let diff = (weekday - firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: -diff, to: startOfDay)!
        let end = calendar.date(byAdding: .day, value: 7, to: start)!
        return DateInterval(start: start, end: end)
    }

    /// Elenco dei giorni coperti dall'intervallo, un `DayDate` per ciascuno.
    public static func days(in interval: DateInterval, calendar: Calendar) -> [DayDate] {
        var result: [DayDate] = []
        var current = interval.start
        while current < interval.end {
            result.append(DayDate(current, calendar: calendar))
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return result
    }

    /// Intervallo (mezzanotte-mezzanotte) di un singolo giorno.
    public static func dayInterval(_ day: DayDate, calendar: Calendar) -> DateInterval {
        let start = day.startDate(in: calendar)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return DateInterval(start: start, end: end)
    }

    /// Griglia mensile: righe da 7 giorni a partire da `firstWeekday`, che coprono tutto il mese (4-6 righe).
    public static func monthGrid(containing date: Date, calendar: Calendar) -> [[DayDate]] {
        let interval = gridInterval(containing: date, calendar: calendar)
        let allDays = days(in: interval, calendar: calendar)

        var rows: [[DayDate]] = []
        var idx = 0
        while idx < allDays.count {
            let end = min(idx + 7, allDays.count)
            rows.append(Array(allDays[idx..<end]))
            idx += 7
        }
        return rows
    }

    /// Intervallo del mese di calendario che contiene `date`.
    public static func monthInterval(containing date: Date, calendar: Calendar) -> DateInterval {
        let comps = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: comps)!
        let end = calendar.date(byAdding: .month, value: 1, to: start)!
        return DateInterval(start: start, end: end)
    }

    /// Intervallo coperto dalla griglia mensile (dal primo giorno della prima riga all'ultimo dell'ultima).
    public static func gridInterval(containing date: Date, calendar: Calendar) -> DateInterval {
        let monthInt = monthInterval(containing: date, calendar: calendar)
        let gridStart = week(containing: monthInt.start, calendar: calendar).start
        let lastDayInstant = calendar.date(byAdding: .second, value: -1, to: monthInt.end)!
        let gridEnd = week(containing: lastDayInstant, calendar: calendar).end
        return DateInterval(start: gridStart, end: gridEnd)
    }
}
