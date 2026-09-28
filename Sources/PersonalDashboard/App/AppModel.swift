import AppKit
import DashboardCore
import DashboardServices
import Foundation
import Observation

enum Selection: Hashable {
    case event(String)
    case task(String)
}

enum WeatherState {
    case idle
    case loaded(WeatherSnapshot)
    /// Nessuna posizione disponibile e nessuna città impostata.
    case noLocation
    case failed
}

enum MailState: Equatable {
    case unknown
    /// Mail.app non è aperta: non la avviamo (REQ-042).
    case closed
    case notAuthorized
    case loaded(MailSummary)
    case failed
}

/// Eliminazione differita (DEC-020): l'elemento sparisce subito, EventKit viene toccato solo allo scadere.
struct PendingDeletion: Identifiable {
    enum Item {
        case event(CalendarEvent, EditSpan)
        case task(TaskItem)
    }

    let id = UUID()
    let item: Item
    let title: String
}

/// Stato e azioni dell'app. Le view leggono da qui e chiamano i metodi; niente accesso diretto ai servizi.
@MainActor
@Observable
final class AppModel {
    static let deletionDelay: Duration = .seconds(5)

    let deps: Dependencies
    let settingsStore: SettingsStore

    // MARK: Stato

    private(set) var calendarAccess: PermissionStatus = .notDetermined
    private(set) var remindersAccess: PermissionStatus = .notDetermined
    private(set) var locationAccess: PermissionStatus = .notDetermined

    private(set) var calendars: [CalendarInfo] = []
    private(set) var taskLists: [TaskListInfo] = []
    /// Eventi dell'intervallo caricato (vista corrente + prossimi 7 giorni per i compleanni).
    private(set) var events: [CalendarEvent] = []
    /// Promemoria non completati.
    private(set) var tasks: [TaskItem] = []
    /// Completati in questa sessione: restano visibili barrati nella loro sezione finché non cambia giorno.
    private(set) var recentlyCompleted: [String: TaskItem] = [:]

    var viewMode: CalendarViewMode {
        didSet { if viewMode != oldValue { Task { await reloadEvents() } } }
    }
    /// Data di riferimento del periodo mostrato.
    private(set) var anchorDate: Date
    var selection: Selection?

    private(set) var pendingDeletion: PendingDeletion?
    private(set) var weather: WeatherState = .idle
    private(set) var weatherPlaceName: String?
    private(set) var mail: MailState = .unknown
    var errorMessage: String?

    /// Incrementati dai comandi di menu (⌘N, ⌘⇧N); le view osservano il cambio con `onChange`.
    var quickAddFocusRequest = 0
    var newEventRequest = 0

    /// Aggiornato ogni 30 s: le proprietà derivate che dipendono dall'ora lo leggono per ricalcolarsi.
    private(set) var now = Date()

    private var started = false
    private var deletionTask: Task<Void, Never>?
    private var reloadTask: Task<Void, Never>?
    private var accentCache: [String: AccentName] = [:]

    init(deps: Dependencies, settingsStore: SettingsStore) {
        self.deps = deps
        self.settingsStore = settingsStore
        self.viewMode = settingsStore.settings.defaultView
        self.anchorDate = Date()
    }

    var settings: AppSettings {
        get { settingsStore.settings }
        set {
            let themeChanged = newValue.themeID != settingsStore.settings.themeID
            settingsStore.settings = newValue
            if themeChanged { accentCache.removeAll() }
        }
    }

    var context: DateContext {
        var context = DateContext.live(firstWeekday: settings.firstWeekday)
        let now = self.now
        context.now = { now }
        return context
    }

    var calendar: Calendar { context.calendar }
    var today: DayDate { DayDate(now, calendar: calendar) }

    // MARK: Avvio e caricamento

    func start() async {
        guard !started else { return }
        started = true
        await requestAccessIfNeeded()
        await reload()
        listenForChanges()
        startTimers()
        Task { await refreshWeather() }
        Task { await refreshMail() }
    }

    func requestAccessIfNeeded() async {
        calendarAccess = deps.planner.authorizationStatus(for: .calendar)
        if calendarAccess == .notDetermined {
            calendarAccess = await deps.planner.requestAccess(to: .calendar)
        }
        remindersAccess = deps.planner.authorizationStatus(for: .reminders)
        if remindersAccess == .notDetermined {
            remindersAccess = await deps.planner.requestAccess(to: .reminders)
        }
        locationAccess = deps.location.authorizationStatus()
    }

    /// Da chiamare quando l'app torna attiva: l'utente potrebbe aver cambiato i permessi in Impostazioni di Sistema.
    func refreshPermissions() async {
        let calendar = deps.planner.authorizationStatus(for: .calendar)
        let reminders = deps.planner.authorizationStatus(for: .reminders)
        let changed = calendar != calendarAccess || reminders != remindersAccess
        calendarAccess = calendar
        remindersAccess = reminders
        locationAccess = deps.location.authorizationStatus()
        if changed { await reload() }
    }

    func reload() async {
        if calendarAccess == .granted {
            do {
                calendars = try await deps.planner.calendars()
                events = try await deps.planner.events(in: fetchInterval)
            } catch {
                report(error)
            }
        }
        if remindersAccess == .granted {
            do {
                taskLists = try await deps.planner.taskLists()
                tasks = try await deps.planner.incompleteTasks()
            } catch {
                report(error)
            }
        }
        accentCache.removeAll()
    }

    func reloadEvents() async {
        guard calendarAccess == .granted else { return }
        do {
            events = try await deps.planner.events(in: fetchInterval)
        } catch {
            report(error)
        }
    }

    private func listenForChanges() {
        let stream = deps.planner.changes()
        Task { [weak self] in
            for await _ in stream {
                self?.scheduleReload()
            }
        }
    }

    /// Le notifiche di EventKit arrivano a raffiche: si ricarica una volta sola.
    private func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await reload()
        }
    }

    private func startTimers() {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                self?.tick()
            }
        }
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30 * 60))
                await self?.refreshWeather()
            }
        }
        Task { [weak self] in
            while !Task.isCancelled {
                let interval = self?.settings.mailRefreshInterval ?? 180
                try? await Task.sleep(for: .seconds(max(interval, 30)))
                await self?.refreshMail()
            }
        }
    }

    private func tick() {
        let previousDay = today
        now = Date()
        if today != previousDay {
            recentlyCompleted.removeAll()
            Task { await reload() }
        }
    }

    // MARK: Periodo visibile

    var visibleInterval: DateInterval {
        switch viewMode {
        case .day: DateRanges.dayInterval(DayDate(anchorDate, calendar: calendar), calendar: calendar)
        case .week: DateRanges.week(containing: anchorDate, calendar: calendar)
        case .month: DateRanges.gridInterval(containing: anchorDate, calendar: calendar)
        }
    }

    /// Colonne delle viste giorno e settimana.
    var visibleDays: [DayDate] {
        DateRanges.days(in: viewMode == .day ? visibleInterval : DateRanges.week(containing: anchorDate, calendar: calendar), calendar: calendar)
            .prefix(viewMode == .day ? 1 : 7)
            .map { $0 }
    }

    /// Righe della vista mese.
    var monthRows: [[DayDate]] { DateRanges.monthGrid(containing: anchorDate, calendar: calendar) }

    /// Mese mostrato nella vista mese (per attenuare i giorni fuori mese).
    var anchorMonth: Int { calendar.component(.month, from: anchorDate) }

    private var fetchInterval: DateInterval {
        let visible = visibleInterval
        let todayStart = today.startDate(in: calendar)
        let weekAhead = calendar.date(byAdding: .day, value: 8, to: todayStart)!
        return DateInterval(start: min(visible.start, todayStart), end: max(visible.end, weekAhead))
    }

    func goToToday() {
        anchorDate = now
        Task { await reloadEvents() }
    }

    /// `delta` periodi avanti (positivo) o indietro (negativo) secondo la vista corrente.
    func step(_ delta: Int) {
        let component: Calendar.Component = switch viewMode {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
        anchorDate = calendar.date(byAdding: component, value: delta, to: anchorDate) ?? anchorDate
        Task { await reloadEvents() }
    }

    func show(day: DayDate, mode: CalendarViewMode = .day) {
        anchorDate = day.startDate(in: calendar)
        viewMode = mode
        Task { await reloadEvents() }
    }

    // MARK: Dati derivati per le view

    var visibleCalendars: [CalendarInfo] { calendars.filter { !settings.hiddenCalendarIDs.contains($0.id) } }

    /// Eventi da mostrare: calendari visibili, senza quelli in eliminazione.
    var displayedEvents: [CalendarEvent] {
        let hidden = settings.hiddenCalendarIDs
        return events.filter { !hidden.contains($0.calendarID) && !isPendingDeletion($0) }
    }

    /// Promemoria da mostrare, compresi i completati di questa sessione.
    var displayedTasks: [TaskItem] {
        let hidden = settings.hiddenTaskListIDs
        return (tasks + recentlyCompleted.values).filter { !hidden.contains($0.listID) && !isPendingDeletion($0) }
    }

    var sections: TaskSections {
        // I completati di sessione restano nella loro sezione: si classificano come se fossero aperti.
        let reopened = displayedTasks.map { task -> TaskItem in
            var t = task
            t.isCompleted = false
            return t
        }
        return TaskClassifier.sections(for: reopened, context: context)
    }

    func isDone(_ task: TaskItem) -> Bool { recentlyCompleted[task.id] != nil }

    func events(on day: DayDate) -> [CalendarEvent] {
        let interval = DateRanges.dayInterval(day, calendar: calendar)
        return displayedEvents.filter { $0.start < interval.end && $0.end > interval.start }
    }

    func timedEvents(on day: DayDate) -> [CalendarEvent] { events(on: day).filter { !$0.isAllDay } }
    func allDayEvents(on day: DayDate) -> [CalendarEvent] { events(on: day).filter(\.isAllDay) }

    /// Task con data e ora nel giorno (anche futuri): compaiono nel calendario come blocchi (REQ-054, REQ-059).
    func scheduledTasks(on day: DayDate) -> [TaskItem] {
        displayedTasks.filter { task in
            if case .dateTime(let date) = task.due { return DayDate(date, calendar: calendar) == day }
            return false
        }
    }

    /// Durata visiva dei task nel calendario (REQ-058).
    var taskBlockDuration: TimeInterval { TimeInterval(settings.taskBlockMinutes * 60) }

    var summary: DaySummary {
        let todays = events(on: today).filter { calendarInfo($0.calendarID)?.kind != .birthday }
        return DaySummary.make(events: todays, sections: sections, context: context)
    }

    /// Compleanni da oggi ai prossimi 7 giorni (REQ-065).
    var upcomingBirthdays: [CalendarEvent] {
        let start = today.startDate(in: calendar)
        let end = calendar.date(byAdding: .day, value: 8, to: start)!
        return displayedEvents
            .filter { calendarInfo($0.calendarID)?.kind == .birthday && $0.start < end && $0.end > start }
            .sorted { $0.start < $1.start }
    }

    func busyHours(on day: DayDate) -> Double {
        Density.busyHours(on: day, events: displayedEvents, calendar: calendar)
    }

    func calendarInfo(_ id: String) -> CalendarInfo? { calendars.first { $0.id == id } }
    func taskList(_ id: String) -> TaskListInfo? { taskLists.first { $0.id == id } }
    var defaultTaskList: TaskListInfo? { taskLists.first(where: \.isDefault) ?? taskLists.first }

    /// Accento del tema per un calendario o una lista (DEC-018), con cache.
    func accent(forCalendar id: String) -> AccentName {
        if let cached = accentCache[id] { return cached }
        let color = calendarInfo(id)?.color ?? taskList(id)?.color ?? RGB(hex: "#888888")
        let accent = nearestAccent(to: color, in: ThemeRegistry.theme(id: settings.themeID))
        accentCache[id] = accent
        return accent
    }

    var selectedEvent: CalendarEvent? {
        guard case .event(let id) = selection else { return nil }
        return displayedEvents.first { $0.id == id }
    }

    var selectedTask: TaskItem? {
        guard case .task(let id) = selection else { return nil }
        return displayedTasks.first { $0.id == id }
    }

    // MARK: Task

    func toggleCompleted(_ task: TaskItem) {
        if var done = recentlyCompleted.removeValue(forKey: task.id) {
            done.isCompleted = false
            done.completionDate = nil
            tasks.append(done)
            save(done)
        } else {
            var done = task
            done.isCompleted = true
            done.completionDate = Date()
            tasks.removeAll { $0.id == task.id }
            recentlyCompleted[task.id] = done
            save(done)
        }
    }

    /// Drop su uno slot orario (REQ-053).
    func schedule(taskID: String, at date: Date) {
        mutateTask(taskID) { $0.due = .dateTime(date) }
    }

    /// Drop su un giorno della vista mese (REQ-032).
    func schedule(taskID: String, on day: DayDate) {
        mutateTask(taskID) { $0.due = .day(day) }
    }

    /// Toglie l'ora (drop su "Da pianificare", REQ-055); se c'è solo la data, toglie anche quella.
    func unschedule(taskID: String) {
        mutateTask(taskID) { task in
            switch task.due {
            case .dateTime(let date): task.due = .day(DayDate(date, calendar: calendar))
            case .day, nil: task.due = nil
            }
        }
    }

    func updateTask(_ task: TaskItem) {
        mutateTask(task.id) { $0 = task }
    }

    /// Inserimento rapido (REQ-021). Restituisce il task creato.
    @discardableResult
    func quickAdd(_ text: String) async -> TaskItem? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parsed = QuickAddParser.parse(trimmed, context: context)
        do {
            let created = try await deps.planner.createTask(TaskDraft(listID: defaultTaskList?.id, title: parsed.title, due: parsed.due))
            tasks.append(created)
            return created
        } catch {
            report(error)
            return nil
        }
    }

    private func mutateTask(_ id: String, _ change: (inout TaskItem) -> Void) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            change(&tasks[index])
            save(tasks[index])
        } else if var task = recentlyCompleted[id] {
            change(&task)
            recentlyCompleted[id] = task
            save(task)
        }
    }

    private func save(_ task: TaskItem) {
        Task {
            do {
                _ = try await deps.planner.updateTask(task)
            } catch {
                report(error)
                await reload()
            }
        }
    }

    // MARK: Eventi

    /// Sposta mantenendo la durata (REQ-014).
    func move(_ event: CalendarEvent, toStart start: Date, span: EditSpan = .thisOccurrence) {
        var moved = event
        moved.end = start.addingTimeInterval(event.end.timeIntervalSince(event.start))
        moved.start = start
        updateEvent(moved, span: span)
    }

    func resize(_ event: CalendarEvent, toEnd end: Date, span: EditSpan = .thisOccurrence) {
        guard end > event.start else { return }
        var resized = event
        resized.end = end
        updateEvent(resized, span: span)
    }

    func updateEvent(_ event: CalendarEvent, span: EditSpan = .thisOccurrence) {
        guard event.isWritable else { return }
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        }
        Task {
            do {
                let saved = try await deps.planner.updateEvent(event, span: span)
                if span == .futureOccurrences {
                    await reloadEvents()
                } else if let index = events.firstIndex(where: { $0.id == event.id }) {
                    events[index] = saved
                }
            } catch {
                report(error)
                await reloadEvents()
            }
        }
    }

    @discardableResult
    func createEvent(_ draft: EventDraft) async -> CalendarEvent? {
        do {
            let created = try await deps.planner.createEvent(draft)
            events.append(created)
            selection = .event(created.id)
            return created
        } catch {
            report(error)
            return nil
        }
    }

    /// Calendario per i nuovi eventi: il primo scrivibile visibile.
    var defaultEventCalendar: CalendarInfo? {
        visibleCalendars.first(where: \.isWritable) ?? calendars.first(where: \.isWritable)
    }

    // MARK: Eliminazione con Annulla (REQ-092)

    func delete(_ event: CalendarEvent, span: EditSpan = .thisOccurrence) {
        guard event.isWritable else { return }
        beginDeletion(PendingDeletion(item: .event(event, span), title: event.title))
    }

    func delete(_ task: TaskItem) {
        beginDeletion(PendingDeletion(item: .task(task), title: task.title))
    }

    func undoDeletion() {
        deletionTask?.cancel()
        deletionTask = nil
        pendingDeletion = nil
    }

    /// Esegue subito l'eliminazione in sospeso (nuova eliminazione, chiusura dell'app).
    func commitPendingDeletion() async {
        deletionTask?.cancel()
        deletionTask = nil
        guard let pending = pendingDeletion else { return }
        do {
            switch pending.item {
            case .event(let event, let span):
                try await deps.planner.deleteEvent(event, span: span)
                events.removeAll { Self.matches($0, deleted: event, span: span) }
            case .task(let task):
                try await deps.planner.deleteTask(task)
                tasks.removeAll { $0.id == task.id }
                recentlyCompleted[task.id] = nil
            }
        } catch {
            report(error)
        }
        if pendingDeletion?.id == pending.id { pendingDeletion = nil }
    }

    private func beginDeletion(_ deletion: PendingDeletion) {
        Task {
            await commitPendingDeletion()
            if selection == selectionFor(deletion.item) { selection = nil }
            pendingDeletion = deletion
            deletionTask = Task {
                try? await Task.sleep(for: Self.deletionDelay)
                guard !Task.isCancelled else { return }
                await commitPendingDeletion()
            }
        }
    }

    private func selectionFor(_ item: PendingDeletion.Item) -> Selection {
        switch item {
        case .event(let event, _): .event(event.id)
        case .task(let task): .task(task.id)
        }
    }

    private func isPendingDeletion(_ event: CalendarEvent) -> Bool {
        guard case .event(let deleted, let span) = pendingDeletion?.item else { return false }
        return Self.matches(event, deleted: deleted, span: span)
    }

    private func isPendingDeletion(_ task: TaskItem) -> Bool {
        guard case .task(let deleted) = pendingDeletion?.item else { return false }
        return task.id == deleted.id
    }

    private static func matches(_ event: CalendarEvent, deleted: CalendarEvent, span: EditSpan) -> Bool {
        switch span {
        case .thisOccurrence: event.id == deleted.id
        case .futureOccurrences: event.eventIdentifier == deleted.eventIdentifier && event.start >= deleted.start
        }
    }

    // MARK: Meteo e mail

    func refreshWeather() async {
        var coordinate: Coordinate?
        var placeName: String?
        locationAccess = deps.location.authorizationStatus()
        if locationAccess != .denied, let current = try? await deps.location.currentCoordinate() {
            coordinate = current
            placeName = await deps.location.placeName(for: current.rounded)
            locationAccess = deps.location.authorizationStatus()
        } else if let fallback = settings.weatherFallbackPlace {
            coordinate = fallback.coordinate
            placeName = fallback.name
        }
        guard let coordinate else {
            weather = .noLocation
            return
        }
        do {
            var snapshot = try await deps.weather.weather(at: coordinate, unit: settings.temperatureUnit)
            snapshot.placeName = placeName
            weather = .loaded(snapshot)
            weatherPlaceName = placeName
        } catch {
            // Offline: si tiene l'ultimo dato.
            if case .loaded = weather { return }
            weather = .failed
        }
    }

    func refreshMail() async {
        do {
            if let summary = try await deps.mail.unreadSummary() {
                mail = .loaded(summary)
            } else {
                mail = .closed
            }
        } catch MailError.notAuthorized {
            mail = .notAuthorized
        } catch {
            mail = .failed
        }
    }

    func refreshAll() async {
        await reload()
        await refreshWeather()
        await refreshMail()
    }

    // MARK: Permessi

    func requestAccess(_ kind: PermissionKind) async {
        switch kind {
        case .calendar:
            calendarAccess = await deps.planner.requestAccess(to: .calendar)
        case .reminders:
            remindersAccess = await deps.planner.requestAccess(to: .reminders)
        case .location:
            await refreshWeather()
        case .mailAutomation:
            await refreshMail()
        }
        await reload()
    }

    /// Apre il pannello giusto di Impostazioni di Sistema (REQ-103).
    func openSystemSettings(for kind: PermissionKind) {
        let anchor = switch kind {
        case .calendar: "Privacy_Calendars"
        case .reminders: "Privacy_Reminders"
        case .location: "Privacy_LocationServices"
        case .mailAutomation: "Privacy_Automation"
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Errori

    private func report(_ error: Error) {
        switch error as? PlannerError {
        case .readOnly: errorMessage = "Questo calendario è in sola lettura."
        case .notFound: errorMessage = "L'elemento non esiste più: forse è stato modificato altrove."
        case .accessDenied: errorMessage = "Accesso a Calendario o Promemoria negato."
        case .underlying(let message): errorMessage = message
        case nil: errorMessage = error.localizedDescription
        }
    }
}
