import Foundation

/// Mock store in-memory per testing e modalità --mock.
public final class MockPlannerStore: PlannerStore, @unchecked Sendable {
    private var state: State
    private let lock = NSLock()
    private var changesContinuations: [AsyncStream<Void>.Continuation] = []

    public struct State {
        var calendars: [CalendarInfo]
        var taskLists: [TaskListInfo]
        var events: [CalendarEvent]
        var tasks: [TaskItem]
    }

    public init(sample: MockSample) {
        self.state = State(
            calendars: sample.calendars,
            taskLists: sample.taskLists,
            events: sample.events,
            tasks: sample.tasks
        )
    }

    public convenience init(context: DateContext) {
        let sample = MockData.sample(context: context)
        self.init(sample: sample)
    }

    public func authorizationStatus(for kind: PermissionKind) -> PermissionStatus {
        .granted
    }

    public func requestAccess(to kind: PermissionKind) async -> PermissionStatus {
        .granted
    }

    public func calendars() async throws -> [CalendarInfo] {
        calendarsSynchronous()
    }

    public func taskLists() async throws -> [TaskListInfo] {
        taskListsSynchronous()
    }

    public func events(in interval: DateInterval) async throws -> [CalendarEvent] {
        eventsSynchronous(in: interval)
    }

    public func createEvent(_ draft: EventDraft) async throws -> CalendarEvent {
        try createEventSynchronous(draft)
    }

    public func updateEvent(_ event: CalendarEvent, span: EditSpan) async throws -> CalendarEvent {
        try updateEventSynchronous(event, span: span)
    }

    public func deleteEvent(_ event: CalendarEvent, span: EditSpan) async throws {
        try deleteEventSynchronous(event, span: span)
    }

    public func incompleteTasks() async throws -> [TaskItem] {
        incompleteTasksSynchronous()
    }

    public func createTask(_ draft: TaskDraft) async throws -> TaskItem {
        createTaskSynchronous(draft)
    }

    public func updateTask(_ task: TaskItem) async throws -> TaskItem {
        try updateTaskSynchronous(task)
    }

    public func deleteTask(_ task: TaskItem) async throws {
        try deleteTaskSynchronous(task)
    }

    public func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            lock.lock()
            changesContinuations.append(continuation)
            lock.unlock()
        }
    }

    // MARK: - Synchronous Implementations

    nonisolated private func calendarsSynchronous() -> [CalendarInfo] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.state.calendars
    }

    nonisolated private func taskListsSynchronous() -> [TaskListInfo] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.state.taskLists
    }

    nonisolated private func eventsSynchronous(in interval: DateInterval) -> [CalendarEvent] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.state.events.filter { event in
            event.start < interval.end && event.end > interval.start
        }.sorted { $0.start < $1.start }
    }

    nonisolated private func createEventSynchronous(_ draft: EventDraft) throws -> CalendarEvent {
        self.lock.lock()
        defer { self.lock.unlock() }

        let calendarID = draft.calendarID ?? "personal"
        guard self.state.calendars.first(where: { $0.id == calendarID })?.isWritable == true else {
            throw PlannerError.readOnly
        }

        let eventID = UUID().uuidString
        let event = CalendarEvent(
            id: eventID,
            eventIdentifier: eventID,
            calendarID: calendarID,
            title: draft.title,
            start: draft.start,
            end: draft.end,
            isAllDay: draft.isAllDay,
            location: draft.location,
            notes: draft.notes,
            isWritable: true
        )

        self.state.events.append(event)
        self.emitChangeSynchronous()
        return event
    }

    nonisolated private func updateEventSynchronous(_ event: CalendarEvent, span: EditSpan) throws -> CalendarEvent {
        self.lock.lock()
        defer { self.lock.unlock() }

        guard self.state.calendars.first(where: { $0.id == event.calendarID })?.isWritable == true else {
            throw PlannerError.readOnly
        }

        guard let index = self.state.events.firstIndex(where: { $0.id == event.id }) else {
            throw PlannerError.notFound
        }

        self.state.events[index] = event

        if event.isRecurring && span == .futureOccurrences {
            let futureEventIndices = self.state.events.indices.filter { i in
                self.state.events[i].eventIdentifier == event.eventIdentifier && self.state.events[i].start >= event.start
            }
            for idx in futureEventIndices {
                var updated = self.state.events[idx]
                updated.title = event.title
                updated.start = event.start
                updated.end = event.end
                self.state.events[idx] = updated
            }
        }

        self.emitChangeSynchronous()
        return event
    }

    nonisolated private func deleteEventSynchronous(_ event: CalendarEvent, span: EditSpan) throws {
        self.lock.lock()
        defer { self.lock.unlock() }

        guard self.state.calendars.first(where: { $0.id == event.calendarID })?.isWritable == true else {
            throw PlannerError.readOnly
        }

        guard self.state.events.contains(where: { $0.id == event.id }) else {
            throw PlannerError.notFound
        }

        if event.isRecurring && span == .futureOccurrences {
            self.state.events.removeAll { e in
                e.eventIdentifier == event.eventIdentifier && e.start >= event.start
            }
        } else {
            self.state.events.removeAll { $0.id == event.id }
        }

        self.emitChangeSynchronous()
    }

    nonisolated private func incompleteTasksSynchronous() -> [TaskItem] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.state.tasks.filter { !$0.isCompleted }
    }

    nonisolated private func createTaskSynchronous(_ draft: TaskDraft) -> TaskItem {
        self.lock.lock()
        defer { self.lock.unlock() }

        let listID = draft.listID ?? "reminders"
        let taskID = UUID().uuidString
        let task = TaskItem(
            id: taskID,
            listID: listID,
            title: draft.title,
            notes: draft.notes,
            due: draft.due,
            priority: draft.priority,
            isCompleted: false
        )

        self.state.tasks.append(task)
        self.emitChangeSynchronous()
        return task
    }

    nonisolated private func updateTaskSynchronous(_ task: TaskItem) throws -> TaskItem {
        self.lock.lock()
        defer { self.lock.unlock() }

        guard let index = self.state.tasks.firstIndex(where: { $0.id == task.id }) else {
            throw PlannerError.notFound
        }

        self.state.tasks[index] = task
        self.emitChangeSynchronous()
        return task
    }

    nonisolated private func deleteTaskSynchronous(_ task: TaskItem) throws {
        self.lock.lock()
        defer { self.lock.unlock() }

        guard self.state.tasks.contains(where: { $0.id == task.id }) else {
            throw PlannerError.notFound
        }

        self.state.tasks.removeAll { $0.id == task.id }
        self.emitChangeSynchronous()
    }

    nonisolated private func emitChangeSynchronous() {
        for continuation in self.changesContinuations {
            continuation.yield()
        }
    }
}
