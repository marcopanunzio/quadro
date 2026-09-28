import Foundation

/// Una singola occorrenza di un evento.
public struct CalendarEvent: Identifiable, Hashable, Sendable {
    /// Identificativo dell'occorrenza: `eventIdentifier` + inizio originale. Stabile per la UI.
    public var id: String
    /// `EKEvent.eventIdentifier`, condiviso da tutte le occorrenze di una ricorrenza.
    public var eventIdentifier: String
    public var calendarID: String
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var location: String?
    public var notes: String?
    public var isRecurring: Bool
    public var hasAttendees: Bool
    public var isOrganizedByMe: Bool
    /// Deriva dal calendario (`CalendarInfo.isWritable`).
    public var isWritable: Bool

    public init(
        id: String,
        eventIdentifier: String,
        calendarID: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        isRecurring: Bool = false,
        hasAttendees: Bool = false,
        isOrganizedByMe: Bool = true,
        isWritable: Bool = true
    ) {
        self.id = id
        self.eventIdentifier = eventIdentifier
        self.calendarID = calendarID
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.isRecurring = isRecurring
        self.hasAttendees = hasAttendees
        self.isOrganizedByMe = isOrganizedByMe
        self.isWritable = isWritable
    }

    /// Invito organizzato da altri: modificabile solo con avviso (REQ-017).
    public var needsOrganizerWarning: Bool { hasAttendees && !isOrganizedByMe }
}

public struct EventDraft: Hashable, Sendable {
    /// `nil` = calendario predefinito.
    public var calendarID: String?
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var location: String?
    public var notes: String?

    public init(calendarID: String? = nil, title: String, start: Date, end: Date, isAllDay: Bool = false, location: String? = nil, notes: String? = nil) {
        self.calendarID = calendarID
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
    }
}

/// Portata di una modifica su un evento ricorrente (REQ-093).
public enum EditSpan: Sendable {
    case thisOccurrence
    case futureOccurrences
}
