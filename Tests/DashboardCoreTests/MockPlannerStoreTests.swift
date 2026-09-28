import DashboardCore
import Foundation
import Testing

@Suite struct MockPlannerStoreTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        c.locale = Locale(identifier: "it_IT")
        c.firstWeekday = 2
        return c
    }()

    let context: DateContext = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        c.locale = Locale(identifier: "it_IT")
        c.firstWeekday = 2

        // 2026-09-28 = lunedì
        let fixed = Date(timeIntervalSince1970: 1_769_020_800)
        return DateContext(calendar: c, now: { fixed })
    }()

    @Test("Campione ha dati della settimana in ordine")
    func sampleDataIsInWeekOrder() async throws {
        let store = MockPlannerStore(context: context)
        let events = try await store.calendars()

        #expect(events.count >= 6, "Almeno 6 calendari")
    }

    @Test("Calendari contengono i nomi attesi")
    func calendarsHaveExpectedNames() async throws {
        let store = MockPlannerStore(context: context)
        let calendars = try await store.calendars()

        let titles = Set(calendars.map(\.title))
        #expect(titles.contains("Lavoro"))
        #expect(titles.contains("Personale"))
        #expect(titles.contains("Famiglia"))
        #expect(titles.contains("Sport"))
        #expect(titles.contains("Compleanni"))
        #expect(titles.contains("Festività italiane"))
    }

    @Test("Liste contengono i nomi attesi")
    func taskListsHaveExpectedNames() async throws {
        let store = MockPlannerStore(context: context)
        let lists = try await store.taskLists()

        let titles = Set(lists.map(\.title))
        #expect(titles.contains("Promemoria"))
        #expect(titles.contains("Lavoro"))
        #expect(titles.contains("Personale"))
        #expect(titles.contains("Casa"))
    }

    @Test("Promemoria è lista predefinita")
    func remindersIsDefaultList() async throws {
        let store = MockPlannerStore(context: context)
        let lists = try await store.taskLists()

        let reminders = lists.first(where: { $0.title == "Promemoria" })
        #expect(reminders?.isDefault == true)
    }

    @Test("events(in:) filtra correttamente l'intervallo")
    func eventsInIntervalFiltersCorrectly() async throws {
        let store = MockPlannerStore(context: context)

        let weekStart = startOfWeekDate(for: context.now(), calendar: calendar)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        let interval = DateInterval(start: weekStart, end: weekEnd)

        let weekEvents = try await store.events(in: interval)

        // Tutti gli eventi della settimana dovrebbero essere presenti
        for event in weekEvents {
            #expect(event.start >= interval.start && event.start < interval.end ||
                   event.end > interval.start && event.end <= interval.end,
                   "Evento \(event.title) è nell'intervallo")
        }
    }

    @Test("createEvent aggiunge evento e genera ID")
    func createEventAddsEvent() async throws {
        let store = MockPlannerStore(context: context)

        let weekStart = startOfWeekDate(for: context.now(), calendar: calendar)
        let start = dateAtTime(weekStart, hour: 14, minute: 0, calendar: calendar)
        let end = dateAtTime(weekStart, hour: 15, minute: 0, calendar: calendar)

        let draft = EventDraft(
            calendarID: "personal",
            title: "Nuovo evento",
            start: start,
            end: end
        )

        let created = try await store.createEvent(draft)
        #expect(!created.id.isEmpty)
        #expect(created.title == "Nuovo evento")
        #expect(created.calendarID == "personal")
    }

    @Test("updateEvent modifica evento esistente")
    func updateEventModifiesEvent() async throws {
        let store = MockPlannerStore(context: context)

        let weekStart = startOfWeekDate(for: context.now(), calendar: calendar)
        let start = dateAtTime(weekStart, hour: 14, minute: 0, calendar: calendar)
        let end = dateAtTime(weekStart, hour: 15, minute: 0, calendar: calendar)

        let draft = EventDraft(
            calendarID: "personal",
            title: "Titolo originale",
            start: start,
            end: end
        )

        var event = try await store.createEvent(draft)
        event.title = "Titolo modificato"

        let updated = try await store.updateEvent(event, span: .thisOccurrence)
        #expect(updated.title == "Titolo modificato")
    }

    @Test("deleteEvent rimuove evento")
    func deleteEventRemovesEvent() async throws {
        let store = MockPlannerStore(context: context)

        let weekStart = startOfWeekDate(for: context.now(), calendar: calendar)
        let start = dateAtTime(weekStart, hour: 14, minute: 0, calendar: calendar)
        let end = dateAtTime(weekStart, hour: 15, minute: 0, calendar: calendar)

        let draft = EventDraft(
            calendarID: "personal",
            title: "Da eliminare",
            start: start,
            end: end
        )

        let event = try await store.createEvent(draft)
        try await store.deleteEvent(event, span: .thisOccurrence)

        let interval = DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: start)!)
        let events = try await store.events(in: interval)
        #expect(!events.contains(where: { $0.id == event.id }))
    }

    @Test("updateEvent su calendario read-only genera errore")
    func updateEventOnReadOnlyCalendarThrows() async throws {
        let store = MockPlannerStore(context: context)

        // Creiamo un evento da un calendario non scrivibile (Compleanni)
        let weekStart = startOfWeekDate(for: context.now(), calendar: calendar)
        let start = dateAtTime(weekStart, hour: 10, minute: 0, calendar: calendar)
        let end = dateAtTime(weekStart, hour: 11, minute: 0, calendar: calendar)

        var event = CalendarEvent(
            id: UUID().uuidString,
            eventIdentifier: UUID().uuidString,
            calendarID: "birthdays",
            title: "Compleanno",
            start: start,
            end: end,
            isWritable: false
        )

        await #expect(throws: PlannerError.readOnly) {
            try await store.updateEvent(event, span: .thisOccurrence)
        }
    }

    @Test("deleteEvent su calendario read-only genera errore")
    func deleteEventOnReadOnlyCalendarThrows() async throws {
        let store = MockPlannerStore(context: context)

        let weekStart = startOfWeekDate(for: context.now(), calendar: calendar)
        let start = dateAtTime(weekStart, hour: 10, minute: 0, calendar: calendar)
        let end = dateAtTime(weekStart, hour: 11, minute: 0, calendar: calendar)

        let event = CalendarEvent(
            id: UUID().uuidString,
            eventIdentifier: UUID().uuidString,
            calendarID: "birthdays",
            title: "Compleanno",
            start: start,
            end: end,
            isWritable: false
        )

        await #expect(throws: PlannerError.readOnly) {
            try await store.deleteEvent(event, span: .thisOccurrence)
        }
    }

    @Test("deleteEvent con futureOccurrences elimina occorrenze future")
    func deleteEventWithFutureOccurrencesDeletesFutureOnly() async throws {
        let store = MockPlannerStore(context: context)

        let weekStart = startOfWeekDate(for: context.now(), calendar: calendar)
        let eventID = UUID().uuidString

        // Creiamo due occorrenze dello stesso evento ricorrente
        let start1 = dateAtTime(weekStart, hour: 9, minute: 0, calendar: calendar)
        let end1 = dateAtTime(weekStart, hour: 9, minute: 30, calendar: calendar)

        let start2 = calendar.date(byAdding: .day, value: 1, to: start1)!
        let end2 = calendar.date(byAdding: .day, value: 1, to: end1)!

        let event1 = CalendarEvent(
            id: eventID + "-0",
            eventIdentifier: eventID,
            calendarID: "work",
            title: "Standup",
            start: start1,
            end: end1,
            isRecurring: true,
            isWritable: true
        )

        let event2 = CalendarEvent(
            id: eventID + "-1",
            eventIdentifier: eventID,
            calendarID: "work",
            title: "Standup",
            start: start2,
            end: end2,
            isRecurring: true,
            isWritable: true
        )

        let sample = MockData.sample(context: context)
        let mockSample = MockSample(
            calendars: sample.calendars,
            taskLists: sample.taskLists,
            events: sample.events + [event1, event2],
            tasks: sample.tasks
        )

        let storeWithEvents = MockPlannerStore(sample: mockSample)

        // Eliminiamo event1 con futureOccurrences - dovrebbe eliminare sia event1 che event2
        try await storeWithEvents.deleteEvent(event1, span: .futureOccurrences)

        let interval = DateInterval(start: weekStart, end: calendar.date(byAdding: .day, value: 7, to: weekStart)!)
        let remaining = try await storeWithEvents.events(in: interval)

        #expect(!remaining.contains(where: { $0.eventIdentifier == eventID }))
    }

    @Test("incompleteTasks esclude completati")
    func incompleteTasksExcludesCompleted() async throws {
        let store = MockPlannerStore(context: context)

        // Creiamo un task completato
        let completedDraft = TaskDraft(
            listID: "reminders",
            title: "Task completato",
            priority: .none
        )
        var completedTask = try await store.createTask(completedDraft)
        completedTask.isCompleted = true
        completedTask.completionDate = Date()
        _ = try await store.updateTask(completedTask)

        let incompleteTasks = try await store.incompleteTasks()
        #expect(!incompleteTasks.contains(where: { $0.id == completedTask.id }))
    }

    @Test("createTask assegna lista predefinita se non specificata")
    func createTaskUsesDefaultListWhenNotSpecified() async throws {
        let store = MockPlannerStore(context: context)

        let draft = TaskDraft(
            listID: nil,
            title: "Task senza lista",
            priority: .none
        )

        let task = try await store.createTask(draft)
        #expect(task.listID == "reminders")
    }

    @Test("updateTask modifica task esistente")
    func updateTaskModifiesTask() async throws {
        let store = MockPlannerStore(context: context)

        let draft = TaskDraft(
            listID: "work-tasks",
            title: "Task originale",
            priority: .none
        )

        var task = try await store.createTask(draft)
        task.title = "Task modificato"
        task.priority = .high

        let updated = try await store.updateTask(task)
        #expect(updated.title == "Task modificato")
        #expect(updated.priority == .high)
    }

    @Test("deleteTask rimuove task")
    func deleteTaskRemovesTask() async throws {
        let store = MockPlannerStore(context: context)

        let draft = TaskDraft(
            listID: "reminders",
            title: "Da eliminare",
            priority: .none
        )

        let task = try await store.createTask(draft)
        try await store.deleteTask(task)

        let remaining = try await store.incompleteTasks()
        #expect(!remaining.contains(where: { $0.id == task.id }))
    }

    @Test("Compleanni calendario non scrivibile")
    func birthdaysCalendarNotWritable() async throws {
        let store = MockPlannerStore(context: context)
        let calendars = try await store.calendars()

        let birthdays = calendars.first(where: { $0.id == "birthdays" })
        #expect(birthdays?.isWritable == false)
    }

    @Test("Festività calendario non scrivibile")
    func holidaysCalendarNotWritable() async throws {
        let store = MockPlannerStore(context: context)
        let calendars = try await store.calendars()

        let holidays = calendars.first(where: { $0.id == "holidays" })
        #expect(holidays?.isWritable == false)
    }
}

// MARK: - Helpers

private func startOfWeekDate(for date: Date, calendar: Calendar) -> Date {
    var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekday], from: date)
    components.weekday = calendar.firstWeekday
    components.hour = 0
    components.minute = 0
    components.second = 0
    return calendar.date(from: components)!
}

private func dateAtTime(_ date: Date, hour: Int, minute: Int, calendar: Calendar) -> Date {
    var components = calendar.dateComponents([.year, .month, .day], from: date)
    components.hour = hour
    components.minute = minute
    components.second = 0
    return calendar.date(from: components)!
}
