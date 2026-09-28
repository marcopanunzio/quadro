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
        let mutableSelf = self as! MockPlannerStore
        mutableSelf.lock.lock()
        defer { mutableSelf.lock.unlock() }
        return mutableSelf.state.calendars
    }

    nonisolated private func taskListsSynchronous() -> [TaskListInfo] {
        let mutableSelf = self as! MockPlannerStore
        mutableSelf.lock.lock()
        defer { mutableSelf.lock.unlock() }
        return mutableSelf.state.taskLists
    }

    nonisolated private func eventsSynchronous(in interval: DateInterval) -> [CalendarEvent] {
        let mutableSelf = self as! MockPlannerStore
        mutableSelf.lock.lock()
        defer { mutableSelf.lock.unlock() }
        return mutableSelf.state.events.filter { event in
            event.start < interval.end && event.end > interval.start
        }.sorted { $0.start < $1.start }
    }

    nonisolated private func createEventSynchronous(_ draft: EventDraft) throws -> CalendarEvent {
        let mutableSelf = self as! MockPlannerStore
        mutableSelf.lock.lock()
        defer { mutableSelf.lock.unlock() }

        let calendarID = draft.calendarID ?? "personal"
        guard mutableSelf.state.calendars.first(where: { $0.id == calendarID })?.isWritable == true else {
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

        mutableSelf.state.events.append(event)
        mutableSelf.emitChangeSynchronous()
        return event
    }

    nonisolated private func updateEventSynchronous(_ event: CalendarEvent, span: EditSpan) throws -> CalendarEvent {
        let mutableSelf = self as! MockPlannerStore
        mutableSelf.lock.lock()
        defer { mutableSelf.lock.unlock() }

        guard mutableSelf.state.calendars.first(where: { $0.id == event.calendarID })?.isWritable == true else {
            throw PlannerError.readOnly
        }

        guard let index = mutableSelf.state.events.firstIndex(where: { $0.id == event.id }) else {
            throw PlannerError.notFound
        }

        mutableSelf.state.events[index] = event

        if event.isRecurring && span == .futureOccurrences {
            let futureEventIndices = mutableSelf.state.events.indices.filter { i in
                mutableSelf.state.events[i].eventIdentifier == event.eventIdentifier && mutableSelf.state.events[i].start >= event.start
            }
            for idx in futureEventIndices {
                var updated = mutableSelf.state.events[idx]
                updated.title = event.title
                updated.start = event.start
                updated.end = event.end
                mutableSelf.state.events[idx] = updated
            }
        }

        mutableSelf.emitChangeSynchronous()
        return event
    }

    nonisolated private func deleteEventSynchronous(_ event: CalendarEvent, span: EditSpan) throws {
        let mutableSelf = self as! MockPlannerStore
        mutableSelf.lock.lock()
        defer { mutableSelf.lock.unlock() }

        guard mutableSelf.state.calendars.first(where: { $0.id == event.calendarID })?.isWritable == true else {
            throw PlannerError.readOnly
        }

        guard mutableSelf.state.events.contains(where: { $0.id == event.id }) else {
            throw PlannerError.notFound
        }

        if event.isRecurring && span == .futureOccurrences {
            mutableSelf.state.events.removeAll { e in
                e.eventIdentifier == event.eventIdentifier && e.start >= event.start
            }
        } else {
            mutableSelf.state.events.removeAll { $0.id == event.id }
        }

        mutableSelf.emitChangeSynchronous()
    }

    nonisolated private func incompleteTasksSynchronous() -> [TaskItem] {
        let mutableSelf = self as! MockPlannerStore
        mutableSelf.lock.lock()
        defer { mutableSelf.lock.unlock() }
        return mutableSelf.state.tasks.filter { !$0.isCompleted }
    }

    nonisolated private func createTaskSynchronous(_ draft: TaskDraft) -> TaskItem {
        let mutableSelf = self as! MockPlannerStore
        mutableSelf.lock.lock()
        defer { mutableSelf.lock.unlock() }

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

        mutableSelf.state.tasks.append(task)
        mutableSelf.emitChangeSynchronous()
        return task
    }

    nonisolated private func updateTaskSynchronous(_ task: TaskItem) throws -> TaskItem {
        let mutableSelf = self as! MockPlannerStore
        mutableSelf.lock.lock()
        defer { mutableSelf.lock.unlock() }

        guard let index = mutableSelf.state.tasks.firstIndex(where: { $0.id == task.id }) else {
            throw PlannerError.notFound
        }

        mutableSelf.state.tasks[index] = task
        mutableSelf.emitChangeSynchronous()
        return task
    }

    nonisolated private func deleteTaskSynchronous(_ task: TaskItem) throws {
        let mutableSelf = self as! MockPlannerStore
        mutableSelf.lock.lock()
        defer { mutableSelf.lock.unlock() }

        guard mutableSelf.state.tasks.contains(where: { $0.id == task.id }) else {
            throw PlannerError.notFound
        }

        mutableSelf.state.tasks.removeAll { $0.id == task.id }
        mutableSelf.emitChangeSynchronous()
    }

    nonisolated private func emitChangeSynchronous() {
        let mutableSelf = self as! MockPlannerStore
        for continuation in mutableSelf.changesContinuations {
            continuation.yield()
        }
    }
}
