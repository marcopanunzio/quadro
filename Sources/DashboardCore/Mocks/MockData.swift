import Foundation

/// Dati di esempio per la modalità mock e per i test.
public enum MockData {
    /// Genera dati di esempio relativi alla settimana che contiene context.now.
    public static func sample(context: DateContext) -> MockSample {
        let today = context.today
        let startOfWeek = startOfWeekDate(for: context.now(), calendar: context.calendar)

        // Calendari
        let calendars = [
            CalendarInfo(id: "work", title: "Lavoro", color: RGB(hex: "#007AFF"), sourceTitle: "Exchange", kind: .standard, isWritable: true),
            CalendarInfo(id: "personal", title: "Personale", color: RGB(hex: "#34C759"), sourceTitle: "iCloud", kind: .standard, isWritable: true),
            CalendarInfo(id: "family", title: "Famiglia", color: RGB(hex: "#AF52DE"), sourceTitle: "iCloud", kind: .standard, isWritable: true),
            CalendarInfo(id: "sport", title: "Sport", color: RGB(hex: "#FF9500"), sourceTitle: "iCloud", kind: .standard, isWritable: true),
            CalendarInfo(id: "birthdays", title: "Compleanni", color: RGB(hex: "#FF2D55"), sourceTitle: "iCloud", kind: .birthday, isWritable: false),
            CalendarInfo(id: "holidays", title: "Festività italiane", color: RGB(hex: "#FF3B30"), sourceTitle: "iCloud", kind: .subscription, isWritable: false),
        ]

        // Liste di task
        let taskLists = [
            TaskListInfo(id: "reminders", title: "Promemoria", color: RGB(hex: "#007AFF"), sourceTitle: "iCloud", isDefault: true),
            TaskListInfo(id: "work-tasks", title: "Lavoro", color: RGB(hex: "#5AC8FA"), sourceTitle: "iCloud", isDefault: false),
            TaskListInfo(id: "personal-tasks", title: "Personale", color: RGB(hex: "#34C759"), sourceTitle: "iCloud", isDefault: false),
            TaskListInfo(id: "home-tasks", title: "Casa", color: RGB(hex: "#FFCC00"), sourceTitle: "iCloud", isDefault: false),
        ]

        var events: [CalendarEvent] = []
        var recurringIds: [String: String] = [:]

        // Eventi ricorrenti e specifici della settimana
        let standup = "recurring-standup"
        recurringIds[standup] = UUID().uuidString
        for dayOffset in 0..<5 {
            let eventDate = addDays(to: startOfWeek, days: dayOffset, calendar: context.calendar)
            let start = dateAtTime(eventDate, hour: 9, minute: 0, calendar: context.calendar)
            let end = dateAtTime(eventDate, hour: 9, minute: 30, calendar: context.calendar)
            events.append(CalendarEvent(
                id: "\(recurringIds[standup]!)-\(dayOffset)",
                eventIdentifier: recurringIds[standup]!,
                calendarID: "work",
                title: "Standup",
                start: start,
                end: end,
                location: "Meet",
                isRecurring: true,
                isWritable: true
            ))
        }

        // Giorni 0-6 relativi a startOfWeek
        let day0 = startOfWeek
        let day1 = addDays(to: startOfWeek, days: 1, calendar: context.calendar)
        let day2 = addDays(to: startOfWeek, days: 2, calendar: context.calendar)
        let day3 = addDays(to: startOfWeek, days: 3, calendar: context.calendar)
        let day4 = addDays(to: startOfWeek, days: 4, calendar: context.calendar)
        let day5 = addDays(to: startOfWeek, days: 5, calendar: context.calendar)
        let day6 = addDays(to: startOfWeek, days: 6, calendar: context.calendar)

        // Giorno 0: Revisione progetto
        events.append(CalendarEvent(
            id: UUID().uuidString,
            eventIdentifier: UUID().uuidString,
            calendarID: "work",
            title: "Revisione progetto",
            start: dateAtTime(day0, hour: 10, minute: 0, calendar: context.calendar),
            end: dateAtTime(day0, hour: 11, minute: 30, calendar: context.calendar),
            location: "Sala riunioni 2",
            isWritable: true
        ))

        // Giorno 0: Call fornitore
        events.append(CalendarEvent(
            id: UUID().uuidString,
            eventIdentifier: UUID().uuidString,
            calendarID: "work",
            title: "Call fornitore",
            start: dateAtTime(day0, hour: 11, minute: 0, calendar: context.calendar),
            end: dateAtTime(day0, hour: 12, minute: 0, calendar: context.calendar),
            location: "Teams",
            hasAttendees: true,
            isOrganizedByMe: false,
            isWritable: true
        ))

        // Giorno 0: Pranzo con Anna (Personale)
        events.append(CalendarEvent(
            id: UUID().uuidString,
            eventIdentifier: UUID().uuidString,
            calendarID: "personal",
            title: "Pranzo con Anna",
            start: dateAtTime(day0, hour: 13, minute: 0, calendar: context.calendar),
            end: dateAtTime(day0, hour: 14, minute: 0, calendar: context.calendar),
            isWritable: true
        ))

        // Palestra ricorrente (giorno 0 e 4)
        let palestra = "recurring-gym"
        recurringIds[palestra] = UUID().uuidString
        for dayOffset in [0, 4] {
            let eventDate = addDays(to: startOfWeek, days: dayOffset, calendar: context.calendar)
            let start = dateAtTime(eventDate, hour: 18, minute: 30, calendar: context.calendar)
            let end = dateAtTime(eventDate, hour: 19, minute: 30, calendar: context.calendar)
            events.append(CalendarEvent(
                id: "\(recurringIds[palestra]!)-\(dayOffset)",
                eventIdentifier: recurringIds[palestra]!,
                calendarID: "sport",
                title: "Palestra",
                start: start,
                end: end,
                isRecurring: true,
                isWritable: true
            ))
        }

        // Giorno 1: Workshop UX
        events.append(CalendarEvent(
            id: UUID().uuidString,
            eventIdentifier: UUID().uuidString,
            calendarID: "work",
            title: "Workshop UX",
            start: dateAtTime(day1, hour: 14, minute: 0, calendar: context.calendar),
            end: dateAtTime(day1, hour: 16, minute: 0, calendar: context.calendar),
            isWritable: true
        ))

        // Giorno 2: 1:1 con Paolo
        events.append(CalendarEvent(
            id: UUID().uuidString,
            eventIdentifier: UUID().uuidString,
            calendarID: "work",
            title: "1:1 con Paolo",
            start: dateAtTime(day2, hour: 12, minute: 30, calendar: context.calendar),
            end: dateAtTime(day2, hour: 13, minute: 30, calendar: context.calendar),
            isWritable: true
        ))

        // Giorno 2: Cena in famiglia
        events.append(CalendarEvent(
            id: UUID().uuidString,
            eventIdentifier: UUID().uuidString,
            calendarID: "family",
            title: "Cena in famiglia",
            start: dateAtTime(day2, hour: 19, minute: 0, calendar: context.calendar),
            end: dateAtTime(day2, hour: 20, minute: 0, calendar: context.calendar),
            isWritable: true
        ))

        // Giorno 3: Sprint planning
        events.append(CalendarEvent(
            id: UUID().uuidString,
            eventIdentifier: UUID().uuidString,
            calendarID: "work",
            title: "Sprint planning",
            start: dateAtTime(day3, hour: 10, minute: 0, calendar: context.calendar),
            end: dateAtTime(day3, hour: 12, minute: 0, calendar: context.calendar),
            isWritable: true
        ))

        // Giorno 3: All-day "Consegna release 1.2"
        events.append(CalendarEvent(
            id: UUID().uuidString,
            eventIdentifier: UUID().uuidString,
            calendarID: "work",
            title: "Consegna release 1.2",
            start: day3,
            end: addDays(to: day3, days: 1, calendar: context.calendar),
            isAllDay: true,
            isWritable: true
        ))

        // Giorno 4: Demo cliente
        events.append(CalendarEvent(
            id: UUID().uuidString,
            eventIdentifier: UUID().uuidString,
            calendarID: "work",
            title: "Demo cliente",
            start: dateAtTime(day4, hour: 15, minute: 0, calendar: context.calendar),
            end: dateAtTime(day4, hour: 17, minute: 0, calendar: context.calendar),
            hasAttendees: true,
            isOrganizedByMe: false,
            isWritable: true
        ))

        // Giorno 5: Mercato
        events.append(CalendarEvent(
            id: UUID().uuidString,
            eventIdentifier: UUID().uuidString,
            calendarID: "personal",
            title: "Mercato",
            start: dateAtTime(day5, hour: 10, minute: 0, calendar: context.calendar),
            end: dateAtTime(day5, hour: 12, minute: 0, calendar: context.calendar),
            isWritable: true
        ))

        // Giorno 5: All-day "Compleanno di Marco"
        events.append(CalendarEvent(
            id: UUID().uuidString,
            eventIdentifier: UUID().uuidString,
            calendarID: "birthdays",
            title: "Compleanno di Marco",
            start: day5,
            end: addDays(to: day5, days: 1, calendar: context.calendar),
            isAllDay: true,
            isWritable: false
        ))

        // Giorno 6: Pranzo dai nonni
        events.append(CalendarEvent(
            id: UUID().uuidString,
            eventIdentifier: UUID().uuidString,
            calendarID: "family",
            title: "Pranzo dai nonni",
            start: dateAtTime(day6, hour: 12, minute: 0, calendar: context.calendar),
            end: dateAtTime(day6, hour: 14, minute: 30, calendar: context.calendar),
            isWritable: true
        ))

        // Giorno 0: All-day "Compleanno di Giulia"
        events.append(CalendarEvent(
            id: UUID().uuidString,
            eventIdentifier: UUID().uuidString,
            calendarID: "birthdays",
            title: "Compleanno di Giulia",
            start: day0,
            end: addDays(to: day0, days: 1, calendar: context.calendar),
            isAllDay: true,
            isWritable: false
        ))

        // Aggiungi 3-4 eventi nelle due settimane prima e dopo
        let prevWeekStart = addDays(to: startOfWeek, days: -7, calendar: context.calendar)
        let nextWeekStart = addDays(to: startOfWeek, days: 7, calendar: context.calendar)

        // Settimana precedente
        for i in 0..<4 {
            let eventDate = addDays(to: prevWeekStart, days: i * 2, calendar: context.calendar)
            events.append(CalendarEvent(
                id: UUID().uuidString,
                eventIdentifier: UUID().uuidString,
                calendarID: i % 2 == 0 ? "work" : "personal",
                title: "Evento precedente \(i + 1)",
                start: dateAtTime(eventDate, hour: 10 + i, minute: 0, calendar: context.calendar),
                end: dateAtTime(eventDate, hour: 11 + i, minute: 0, calendar: context.calendar),
                isWritable: true
            ))
        }

        // Settimana successiva
        for i in 0..<4 {
            let eventDate = addDays(to: nextWeekStart, days: i * 2, calendar: context.calendar)
            events.append(CalendarEvent(
                id: UUID().uuidString,
                eventIdentifier: UUID().uuidString,
                calendarID: i % 2 == 0 ? "work" : "personal",
                title: "Evento successivo \(i + 1)",
                start: dateAtTime(eventDate, hour: 10 + i, minute: 0, calendar: context.calendar),
                end: dateAtTime(eventDate, hour: 11 + i, minute: 0, calendar: context.calendar),
                isWritable: true
            ))
        }

        // Task
        var tasks: [TaskItem] = []

        // Task 3 giorni fa (passato)
        let threeDaysAgo = today.adding(days: -3, calendar: context.calendar)
        tasks.append(TaskItem(
            id: UUID().uuidString,
            listID: "personal-tasks",
            title: "Rinnovare assicurazione auto",
            due: .day(threeDaysAgo),
            isCompleted: false
        ))

        // Task oggi con ora (alta priorità)
        let todayNoon = dateAtTime(context.now(), hour: 9, minute: 0, calendar: context.calendar)
        tasks.append(TaskItem(
            id: UUID().uuidString,
            listID: "work-tasks",
            title: "Inviare fattura di agosto",
            due: .dateTime(todayNoon),
            priority: .high,
            isCompleted: false
        ))

        // Task oggi 15:00
        let todayAfternoon = dateAtTime(context.now(), hour: 15, minute: 0, calendar: context.calendar)
        tasks.append(TaskItem(
            id: UUID().uuidString,
            listID: "work-tasks",
            title: "Inviare report settimanale",
            due: .dateTime(todayAfternoon),
            isCompleted: false
        ))

        // Task oggi 17:30
        let todayEvening = dateAtTime(context.now(), hour: 17, minute: 30, calendar: context.calendar)
        tasks.append(TaskItem(
            id: UUID().uuidString,
            listID: "home-tasks",
            title: "Ritirare pacco",
            due: .dateTime(todayEvening),
            isCompleted: false
        ))

        // Task oggi (solo giorno)
        tasks.append(TaskItem(
            id: UUID().uuidString,
            listID: "personal-tasks",
            title: "Comprare regalo per Giulia",
            due: .day(today),
            isCompleted: false
        ))

        // Task fra 3 giorni
        let inThreeDays = today.adding(days: 3, calendar: context.calendar)
        tasks.append(TaskItem(
            id: UUID().uuidString,
            listID: "home-tasks",
            title: "Rivedere preventivo cucina",
            due: .day(inThreeDays),
            isCompleted: false
        ))

        // Task senza data
        tasks.append(TaskItem(
            id: UUID().uuidString,
            listID: "personal-tasks",
            title: "Prenotare dentista",
            isCompleted: false
        ))

        // Task senza data
        tasks.append(TaskItem(
            id: UUID().uuidString,
            listID: "work-tasks",
            title: "Leggere documento di architettura",
            isCompleted: false
        ))

        // Task fra 3 giorni alle 16:00
        let inThreeDaysAfternoon = dateAtTime(
            inThreeDays.startDate(in: context.calendar),
            hour: 16,
            minute: 0,
            calendar: context.calendar
        )
        tasks.append(TaskItem(
            id: UUID().uuidString,
            listID: "personal-tasks",
            title: "Chiamare commercialista",
            due: .dateTime(inThreeDaysAfternoon),
            isCompleted: false
        ))

        return MockSample(calendars: calendars, taskLists: taskLists, events: events, tasks: tasks)
    }
}

public struct MockSample: Sendable {
    public var calendars: [CalendarInfo]
    public var taskLists: [TaskListInfo]
    public var events: [CalendarEvent]
    public var tasks: [TaskItem]

    public init(calendars: [CalendarInfo], taskLists: [TaskListInfo], events: [CalendarEvent], tasks: [TaskItem]) {
        self.calendars = calendars
        self.taskLists = taskLists
        self.events = events
        self.tasks = tasks
    }
}

// MARK: - Helper Functions

private func startOfWeekDate(for date: Date, calendar: Calendar) -> Date {
    var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekday], from: date)
    components.weekday = calendar.firstWeekday
    components.hour = 0
    components.minute = 0
    components.second = 0
    return calendar.date(from: components)!
}

private func addDays(to date: Date, days: Int, calendar: Calendar) -> Date {
    calendar.date(byAdding: .day, value: days, to: date)!
}

private func dateAtTime(_ date: Date, hour: Int, minute: Int, calendar: Calendar) -> Date {
    var components = calendar.dateComponents([.year, .month, .day], from: date)
    components.hour = hour
    components.minute = minute
    components.second = 0
    return calendar.date(from: components)!
}
