import Foundation

/// Le tre sezioni della lista task: ogni promemoria (non completato) sta in una sola sezione.
public struct TaskSections: Equatable, Sendable {
    public var overdue: [TaskItem]
    public var today: [TaskItem]
    public var toPlan: [TaskItem]

    public init(overdue: [TaskItem] = [], today: [TaskItem] = [], toPlan: [TaskItem] = []) {
        self.overdue = overdue
        self.today = today
        self.toPlan = toPlan
    }
}

public enum TaskClassifier {
    /// Classifica i task non completati in Scaduti / Oggi / Da pianificare.
    /// Priorità: Scaduti > Da pianificare > Oggi. I `.dateTime` futuri oltre oggi non compaiono
    /// in nessuna sezione (si vedono solo nel calendario).
    public static func sections(for tasks: [TaskItem], context: DateContext) -> TaskSections {
        let now = context.now()
        let today = context.today
        let calendar = context.calendar

        var overdue: [TaskItem] = []
        var todaySection: [TaskItem] = []
        var toPlan: [TaskItem] = []

        for task in tasks where !task.isCompleted {
            switch task.due {
            case .dateTime(let date):
                if date < now {
                    overdue.append(task)
                } else if DayDate(date, calendar: calendar) == today {
                    todaySection.append(task)
                }
            case .day(let day):
                if day < today {
                    overdue.append(task)
                } else {
                    toPlan.append(task)
                }
            case nil:
                toPlan.append(task)
            }
        }

        overdue.sort { effectiveDeadline($0, calendar: calendar) < effectiveDeadline($1, calendar: calendar) }

        todaySection.sort { a, b in
            guard case .dateTime(let da) = a.due, case .dateTime(let db) = b.due else { return false }
            return da < db
        }

        toPlan.sort { a, b in
            switch (a.due, b.due) {
            case (.some(.day(let ga)), .some(.day(let gb))):
                return ga < gb
            case (.some(.day), .none):
                return true
            case (.none, .some(.day)):
                return false
            case (.none, .none):
                if a.priority != b.priority { return a.priority.rawValue > b.priority.rawValue }
                return a.title.localizedStandardCompare(b.title) == .orderedAscending
            default:
                return false
            }
        }

        return TaskSections(overdue: overdue, today: todaySection, toPlan: toPlan)
    }

    /// Scadenza effettiva per l'ordinamento: un `.day` vale come inizio giornata.
    private static func effectiveDeadline(_ task: TaskItem, calendar: Calendar) -> Date {
        switch task.due! {
        case .dateTime(let date): return date
        case .day(let day): return day.startDate(in: calendar)
        }
    }
}
