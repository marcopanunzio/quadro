import Foundation

/// Scadenza di un promemoria: solo giorno oppure giorno e ora.
public enum TaskDue: Hashable, Sendable {
    case day(DayDate)
    case dateTime(Date)
}

public enum TaskPriority: Int, Hashable, Sendable, CaseIterable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3
}

/// Un promemoria Apple (DEC-005).
public struct TaskItem: Identifiable, Hashable, Sendable {
    /// `EKReminder.calendarItemIdentifier`.
    public var id: String
    public var listID: String
    public var title: String
    public var notes: String?
    public var due: TaskDue?
    public var priority: TaskPriority
    public var isCompleted: Bool
    public var completionDate: Date?

    public init(
        id: String,
        listID: String,
        title: String,
        notes: String? = nil,
        due: TaskDue? = nil,
        priority: TaskPriority = .none,
        isCompleted: Bool = false,
        completionDate: Date? = nil
    ) {
        self.id = id
        self.listID = listID
        self.title = title
        self.notes = notes
        self.due = due
        self.priority = priority
        self.isCompleted = isCompleted
        self.completionDate = completionDate
    }
}

public struct TaskDraft: Hashable, Sendable {
    /// `nil` = lista predefinita.
    public var listID: String?
    public var title: String
    public var due: TaskDue?
    public var priority: TaskPriority
    public var notes: String?

    public init(listID: String? = nil, title: String, due: TaskDue? = nil, priority: TaskPriority = .none, notes: String? = nil) {
        self.listID = listID
        self.title = title
        self.due = due
        self.priority = priority
        self.notes = notes
    }
}
