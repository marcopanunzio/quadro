// Funzioni pure di mapping tra i tipi EventKit e i modelli di DashboardCore.
// Isolate qui per essere testabili senza permessi né dati reali.
import CoreGraphics
import DashboardCore
import EventKit
import Foundation

/// Compone/scompone l'id di un'occorrenza: `eventIdentifier` + `occurrenceDate`.
enum EventOccurrenceID {
    /// L'`eventIdentifier` di EventKit non contiene mai `|`, ma per sicurezza si divide sull'ultimo separatore.
    static func encode(eventIdentifier: String, occurrenceDate: Date) -> String {
        "\(eventIdentifier)|\(occurrenceDate.timeIntervalSince1970)"
    }

    static func decode(_ id: String) -> (eventIdentifier: String, occurrenceDate: Date)? {
        guard let separatorRange = id.range(of: "|", options: .backwards) else { return nil }
        let eventIdentifier = String(id[..<separatorRange.lowerBound])
        let timestampPart = String(id[separatorRange.upperBound...])
        guard !eventIdentifier.isEmpty, let timestamp = TimeInterval(timestampPart) else { return nil }
        return (eventIdentifier, Date(timeIntervalSince1970: timestamp))
    }

    /// Tolleranza per confrontare due istanti derivati dallo stesso id (arrotondamenti in andata/ritorno).
    static func isSameInstant(_ lhs: Date, _ rhs: Date, tolerance: TimeInterval = 0.001) -> Bool {
        abs(lhs.timeIntervalSince1970 - rhs.timeIntervalSince1970) < tolerance
    }
}

/// Conversione priorità EventKit (0-9) <-> `TaskPriority`.
enum EventKitPriority {
    static func toTaskPriority(_ raw: Int) -> TaskPriority {
        switch raw {
        case 1...4: return .high
        case 5: return .medium
        case 6...9: return .low
        default: return .none
        }
    }

    static func toEventKitPriority(_ priority: TaskPriority) -> Int {
        switch priority {
        case .high: return 1
        case .medium: return 5
        case .low: return 9
        case .none: return 0
        }
    }
}

/// Conversione tra `TaskDue` e `DateComponents` (`dueDateComponents` di `EKReminder`).
enum EventKitDueDate {
    static func toTaskDue(_ components: DateComponents, calendar: Calendar) -> TaskDue? {
        guard let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }
        if components.hour != nil {
            guard let date = calendar.date(from: components) else { return nil }
            return .dateTime(date)
        }
        return .day(DayDate(year: year, month: month, day: day))
    }

    static func toDateComponents(_ due: TaskDue, calendar: Calendar) -> DateComponents {
        switch due {
        case .day(let dayDate):
            var components = DateComponents()
            components.year = dayDate.year
            components.month = dayDate.month
            components.day = dayDate.day
            return components
        case .dateTime(let date):
            return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        }
    }

    /// Nuova data di un avviso a orario fisso quando la scadenza passa da `old` a `new`.
    /// Tra due orari si sposta della stessa differenza; se una delle due è solo giorno si sposta
    /// degli stessi giorni mantenendo l'ora dell'avviso.
    static func shiftedAlarmDate(_ alarmDate: Date, from old: TaskDue, to new: TaskDue, calendar: Calendar) -> Date {
        if case .dateTime(let oldDate) = old, case .dateTime(let newDate) = new {
            return alarmDate.addingTimeInterval(newDate.timeIntervalSince(oldDate))
        }
        let oldDay = day(of: old, calendar: calendar).startDate(in: calendar)
        let newDay = day(of: new, calendar: calendar).startDate(in: calendar)
        let days = calendar.dateComponents([.day], from: oldDay, to: newDay).day ?? 0
        return calendar.date(byAdding: .day, value: days, to: alarmDate) ?? alarmDate
    }

    private static func day(of due: TaskDue, calendar: Calendar) -> DayDate {
        switch due {
        case .day(let day): day
        case .dateTime(let date): DayDate(date, calendar: calendar)
        }
    }
}

/// Mapping del tipo di calendario EventKit.
enum EventKitCalendarKind {
    static func kind(for type: EKCalendarType) -> CalendarInfo.Kind {
        switch type {
        case .birthday: return .birthday
        case .subscription: return .subscription
        default: return .standard
        }
    }
}

/// Conversione colore `CGColor` -> `RGB` in sRGB.
enum EventKitColor {
    static func rgb(from cgColor: CGColor?) -> RGB {
        guard let cgColor else { return RGB(r: 0, g: 0, b: 0) }
        guard let srgbSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = cgColor.converted(to: srgbSpace, intent: .defaultIntent, options: nil),
              let components = converted.components, components.count >= 3
        else {
            let fallback = cgColor.components ?? [0, 0, 0]
            return RGB(
                r: Double(fallback[0]),
                g: fallback.count > 1 ? Double(fallback[1]) : Double(fallback[0]),
                b: fallback.count > 2 ? Double(fallback[2]) : Double(fallback[0])
            )
        }
        return RGB(r: Double(components[0]), g: Double(components[1]), b: Double(components[2]))
    }
}
