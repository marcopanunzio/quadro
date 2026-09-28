// PlannerStore su EventKit: Calendario e Promemoria Apple sono l'unica fonte di verità,
// ogni modifica va salvata subito (`commit: true`); l'offline è garantito dallo store locale di EventKit.
import DashboardCore
import EventKit
import Foundation

public final class EventKitPlannerStore: PlannerStore, @unchecked Sendable {
    private let eventStore: EKEventStore
    /// Calendario/fuso usati per le conversioni data <-> `DateComponents` dei promemoria.
    private let calendar: Calendar

    public init() {
        self.eventStore = EKEventStore()
        self.calendar = Calendar.current
    }

    // MARK: - Permessi

    public func authorizationStatus(for kind: PermissionKind) -> PermissionStatus {
        switch kind {
        case .calendar:
            return Self.mapAuthorizationStatus(EKEventStore.authorizationStatus(for: .event))
        case .reminders:
            return Self.mapAuthorizationStatus(EKEventStore.authorizationStatus(for: .reminder))
        case .location, .mailAutomation:
            // Non di competenza di EventKit: nessuno stato reale da riportare.
            return .notDetermined
        }
    }

    public func requestAccess(to kind: PermissionKind) async -> PermissionStatus {
        switch kind {
        case .calendar:
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                return granted ? .granted : .denied
            } catch {
                return .denied
            }
        case .reminders:
            do {
                let granted = try await eventStore.requestFullAccessToReminders()
                return granted ? .granted : .denied
            } catch {
                return .denied
            }
        case .location, .mailAutomation:
            return .notDetermined
        }
    }

    private static func mapAuthorizationStatus(_ status: EKAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .fullAccess: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    private func ensureAccess(for kind: PermissionKind) throws {
        if authorizationStatus(for: kind) == .denied {
            throw PlannerError.accessDenied
        }
    }

    // MARK: - Calendari e liste

    public func calendars() async throws -> [CalendarInfo] {
        try ensureAccess(for: .calendar)
        return eventStore.calendars(for: .event).map(Self.mapCalendarInfo)
    }

    public func taskLists() async throws -> [TaskListInfo] {
        try ensureAccess(for: .reminders)
        let defaultListID = eventStore.defaultCalendarForNewReminders()?.calendarIdentifier
        return eventStore.calendars(for: .reminder).map { list in
            TaskListInfo(
                id: list.calendarIdentifier,
                title: list.title,
                color: EventKitColor.rgb(from: list.cgColor),
                sourceTitle: list.source.title,
                isDefault: list.calendarIdentifier == defaultListID
            )
        }
    }

    private static func mapCalendarInfo(_ cal: EKCalendar) -> CalendarInfo {
        let kind = EventKitCalendarKind.kind(for: cal.type)
        return CalendarInfo(
            id: cal.calendarIdentifier,
            title: cal.title,
            color: EventKitColor.rgb(from: cal.cgColor),
            sourceTitle: cal.source.title,
            kind: kind,
            isWritable: cal.allowsContentModifications && kind != .birthday
        )
    }

    // MARK: - Eventi

    public func events(in interval: DateInterval) async throws -> [CalendarEvent] {
        try ensureAccess(for: .calendar)
        let predicate = eventStore.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
        return eventStore.events(matching: predicate).map(Self.mapEvent)
    }

    public func createEvent(_ draft: EventDraft) async throws -> CalendarEvent {
        try ensureAccess(for: .calendar)
        let ekEvent = EKEvent(eventStore: eventStore)
        let targetCalendar: EKCalendar?
        if let calendarID = draft.calendarID {
            targetCalendar = eventStore.calendar(withIdentifier: calendarID)
        } else {
            targetCalendar = eventStore.defaultCalendarForNewEvents
        }
        guard let targetCalendar else { throw PlannerError.notFound }
        guard Self.mapCalendarInfo(targetCalendar).isWritable else { throw PlannerError.readOnly }
        ekEvent.calendar = targetCalendar
        ekEvent.title = draft.title
        ekEvent.startDate = draft.start
        ekEvent.endDate = draft.end
        ekEvent.isAllDay = draft.isAllDay
        ekEvent.location = draft.location
        ekEvent.notes = draft.notes
        do {
            try eventStore.save(ekEvent, span: .thisEvent, commit: true)
        } catch {
            throw PlannerError.underlying(error.localizedDescription)
        }
        return Self.mapEvent(ekEvent)
    }

    public func updateEvent(_ event: CalendarEvent, span: EditSpan) async throws -> CalendarEvent {
        try ensureAccess(for: .calendar)
        let ekEvent = try findEvent(id: event.id)
        guard Self.mapCalendarInfo(ekEvent.calendar).isWritable else { throw PlannerError.readOnly }
        if event.calendarID != ekEvent.calendar.calendarIdentifier {
            guard let newCalendar = eventStore.calendar(withIdentifier: event.calendarID) else {
                throw PlannerError.notFound
            }
            guard Self.mapCalendarInfo(newCalendar).isWritable else { throw PlannerError.readOnly }
            ekEvent.calendar = newCalendar
        }
        ekEvent.title = event.title
        ekEvent.startDate = event.start
        ekEvent.endDate = event.end
        ekEvent.isAllDay = event.isAllDay
        ekEvent.location = event.location
        ekEvent.notes = event.notes
        do {
            try eventStore.save(ekEvent, span: Self.mapSpan(span), commit: true)
        } catch {
            throw PlannerError.underlying(error.localizedDescription)
        }
        return Self.mapEvent(ekEvent)
    }

    public func deleteEvent(_ event: CalendarEvent, span: EditSpan) async throws {
        try ensureAccess(for: .calendar)
        let ekEvent = try findEvent(id: event.id)
        guard Self.mapCalendarInfo(ekEvent.calendar).isWritable else { throw PlannerError.readOnly }
        do {
            try eventStore.remove(ekEvent, span: Self.mapSpan(span), commit: true)
        } catch {
            throw PlannerError.underlying(error.localizedDescription)
        }
    }

    /// Ritrova l'occorrenza esatta cercando in una finestra attorno a `occurrenceDate`
    /// e confrontando `eventIdentifier` + `occurrenceDate`.
    private func findEvent(id: String) throws -> EKEvent {
        guard let (eventIdentifier, occurrenceDate) = EventOccurrenceID.decode(id) else {
            throw PlannerError.notFound
        }
        let dayLength: TimeInterval = 60 * 60 * 24
        let windowStart = occurrenceDate.addingTimeInterval(-2 * dayLength)
        let windowEnd = occurrenceDate.addingTimeInterval(2 * dayLength)
        let predicate = eventStore.predicateForEvents(withStart: windowStart, end: windowEnd, calendars: nil)
        let candidates = eventStore.events(matching: predicate)
        guard let match = candidates.first(where: {
            $0.eventIdentifier == eventIdentifier && EventOccurrenceID.isSameInstant($0.occurrenceDate, occurrenceDate)
        }) else {
            throw PlannerError.notFound
        }
        return match
    }

    private static func mapSpan(_ span: EditSpan) -> EKSpan {
        switch span {
        case .thisOccurrence: return .thisEvent
        case .futureOccurrences: return .futureEvents
        }
    }

    private static func mapEvent(_ ekEvent: EKEvent) -> CalendarEvent {
        let calendarInfo = mapCalendarInfo(ekEvent.calendar)
        return CalendarEvent(
            id: EventOccurrenceID.encode(eventIdentifier: ekEvent.eventIdentifier, occurrenceDate: ekEvent.occurrenceDate),
            eventIdentifier: ekEvent.eventIdentifier,
            calendarID: ekEvent.calendar.calendarIdentifier,
            title: ekEvent.title ?? "",
            start: ekEvent.startDate,
            end: ekEvent.endDate,
            isAllDay: ekEvent.isAllDay,
            location: ekEvent.location,
            notes: ekEvent.notes,
            isRecurring: ekEvent.hasRecurrenceRules || ekEvent.isDetached,
            hasAttendees: !(ekEvent.attendees?.isEmpty ?? true),
            isOrganizedByMe: ekEvent.organizer?.isCurrentUser ?? true,
            isWritable: calendarInfo.isWritable
        )
    }

    // MARK: - Promemoria

    public func incompleteTasks() async throws -> [TaskItem] {
        try ensureAccess(for: .reminders)
        let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { [self] reminders in
                let tasks = (reminders ?? []).map(mapTask)
                continuation.resume(returning: tasks)
            }
        }
    }

    public func createTask(_ draft: TaskDraft) async throws -> TaskItem {
        try ensureAccess(for: .reminders)
        let targetList: EKCalendar?
        if let listID = draft.listID {
            targetList = eventStore.calendar(withIdentifier: listID)
        } else {
            targetList = eventStore.defaultCalendarForNewReminders()
        }
        guard let targetList else { throw PlannerError.notFound }
        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = targetList
        reminder.title = draft.title
        reminder.notes = draft.notes
        reminder.priority = EventKitPriority.toEventKitPriority(draft.priority)
        applyDue(draft.due, to: reminder)
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            throw PlannerError.underlying(error.localizedDescription)
        }
        return mapTask(reminder)
    }

    public func updateTask(_ task: TaskItem) async throws -> TaskItem {
        try ensureAccess(for: .reminders)
        guard let reminder = eventStore.calendarItem(withIdentifier: task.id) as? EKReminder else {
            throw PlannerError.notFound
        }
        if task.listID != reminder.calendar.calendarIdentifier {
            guard let newList = eventStore.calendar(withIdentifier: task.listID) else {
                throw PlannerError.notFound
            }
            reminder.calendar = newList
        }
        reminder.title = task.title
        reminder.notes = task.notes
        applyDue(task.due, to: reminder)
        reminder.priority = EventKitPriority.toEventKitPriority(task.priority)
        reminder.isCompleted = task.isCompleted
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            throw PlannerError.underlying(error.localizedDescription)
        }
        return mapTask(reminder)
    }

    public func deleteTask(_ task: TaskItem) async throws {
        try ensureAccess(for: .reminders)
        guard let reminder = eventStore.calendarItem(withIdentifier: task.id) as? EKReminder else {
            throw PlannerError.notFound
        }
        do {
            try eventStore.remove(reminder, commit: true)
        } catch {
            throw PlannerError.underlying(error.localizedDescription)
        }
    }

    /// Aggiorna la scadenza tenendo l'avviso coerente. L'app Promemoria per un promemoria con orario crea un avviso
    /// a orario fisso uguale alla scadenza, e Calendario mostra il promemoria all'ora dell'avviso: se l'avviso
    /// restasse al vecchio orario il promemoria apparirebbe nel giorno sbagliato. Gli avvisi relativi (es. "15 minuti
    /// prima") seguono già la scadenza e restano come sono.
    private func applyDue(_ due: TaskDue?, to reminder: EKReminder) {
        let absoluteAlarms = (reminder.alarms ?? []).filter { $0.absoluteDate != nil }
        for alarm in absoluteAlarms {
            reminder.removeAlarm(alarm)
        }
        reminder.dueDateComponents = due.map { EventKitDueDate.toDateComponents($0, calendar: calendar) }
        // Come in Promemoria: una scadenza con orario notifica a quell'ora, salvo avvisi relativi già presenti.
        let hasRelativeAlarms = (reminder.alarms ?? []).contains { $0.absoluteDate == nil }
        if case .dateTime(let date) = due, !hasRelativeAlarms {
            reminder.addAlarm(EKAlarm(absoluteDate: date))
        }
    }

    private func mapTask(_ reminder: EKReminder) -> TaskItem {
        let due = reminder.dueDateComponents.flatMap { EventKitDueDate.toTaskDue($0, calendar: calendar) }
        return TaskItem(
            id: reminder.calendarItemIdentifier,
            listID: reminder.calendar.calendarIdentifier,
            title: reminder.title ?? "",
            notes: reminder.notes,
            due: due,
            priority: EventKitPriority.toTaskPriority(reminder.priority),
            isCompleted: reminder.isCompleted,
            completionDate: reminder.completionDate
        )
    }

    // MARK: - Notifiche

    public func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let box = ObserverBox()
            box.token = NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged,
                object: eventStore,
                queue: nil
            ) { _ in
                continuation.yield(())
            }
            continuation.onTermination = { _ in
                box.removeIfNeeded()
            }
        }
    }
}

/// Contenitore per il token dell'observer: NSObjectProtocol non è Sendable,
/// serve per rimuoverlo in sicurezza dalla closure `onTermination`.
private final class ObserverBox: @unchecked Sendable {
    var token: NSObjectProtocol?

    func removeIfNeeded() {
        if let token {
            NotificationCenter.default.removeObserver(token)
            self.token = nil
        }
    }
}
