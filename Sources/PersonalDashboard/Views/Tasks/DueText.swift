import DashboardCore
import Foundation

/// Formattazione pura della scadenza di un task per la riga (TASK-014).
enum DueText {
    static func string(for due: TaskDue?, context: DateContext) -> String {
        guard let due else { return "nessuna data" }
        let calendar = context.calendar
        let today = context.today

        switch due {
        case .dateTime(let date):
            let day = DayDate(date, calendar: calendar)
            let time = timeFormatter(calendar: calendar).string(from: date)
            if day == today {
                return date < context.now() ? "oggi, \(time)" : time
            }
            return "\(weekdayDayMonth(day, calendar: calendar)), \(time)"
        case .day(let day):
            if day == today { return "oggi, senza ora" }
            if day == today.adding(days: 1, calendar: calendar) { return "domani, senza ora" }
            let label = weekdayDayMonth(day, calendar: calendar)
            return day < today ? label : "\(label), senza ora"
        }
    }

    private static func weekdayDayMonth(_ day: DayDate, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: day.startDate(in: calendar))
    }

    private static func timeFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}
