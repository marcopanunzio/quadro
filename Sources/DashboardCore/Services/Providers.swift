import Foundation

public enum PermissionKind: String, Sendable, CaseIterable {
    case calendar
    case reminders
    case location
    case mailAutomation
}

public enum PermissionStatus: Sendable {
    case notDetermined
    case granted
    case denied
}

public enum PlannerError: Error, Sendable, Equatable {
    case accessDenied
    case notFound
    case readOnly
    case underlying(String)
}

/// Accesso a Calendario e Promemoria Apple. Implementazione reale su EventKit, mock per test e `--mock`.
public protocol PlannerStore: AnyObject, Sendable {
    func authorizationStatus(for kind: PermissionKind) -> PermissionStatus
    /// Solo `.calendar` e `.reminders`.
    func requestAccess(to kind: PermissionKind) async -> PermissionStatus

    func calendars() async throws -> [CalendarInfo]
    func taskLists() async throws -> [TaskListInfo]

    /// Occorrenze che intersecano l'intervallo, di tutti i calendari (anche compleanni).
    func events(in interval: DateInterval) async throws -> [CalendarEvent]
    func createEvent(_ draft: EventDraft) async throws -> CalendarEvent
    /// Salva modifiche a titolo, orari, calendario, luogo, note.
    func updateEvent(_ event: CalendarEvent, span: EditSpan) async throws -> CalendarEvent
    func deleteEvent(_ event: CalendarEvent, span: EditSpan) async throws

    /// Tutti i promemoria non completati di tutte le liste.
    func incompleteTasks() async throws -> [TaskItem]
    func createTask(_ draft: TaskDraft) async throws -> TaskItem
    func updateTask(_ task: TaskItem) async throws -> TaskItem
    func deleteTask(_ task: TaskItem) async throws

    /// Emette quando i dati cambiano fuori dall'app (EKEventStoreChanged, REQ-013).
    func changes() -> AsyncStream<Void>
}

public protocol LocationProvider: Sendable {
    func authorizationStatus() -> PermissionStatus
    /// Chiede il permesso se necessario. Precisione ridotta.
    func currentCoordinate() async throws -> Coordinate
}

public protocol WeatherProvider: Sendable {
    func weather(at coordinate: Coordinate, unit: TemperatureUnit) async throws -> WeatherSnapshot
    func searchPlaces(named query: String) async throws -> [Place]
}

public protocol MailProvider: Sendable {
    /// `nil` se Mail.app non è in esecuzione: non va mai avviata (REQ-042).
    func unreadSummary() async throws -> MailSummary?
}
