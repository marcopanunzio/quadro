import DashboardCore
import Foundation
import Testing

@Suite struct TaskClassifierTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        c.firstWeekday = 2
        return c
    }()

    // "Oggi" fisso: 28 settembre 2026, 10:00 Europe/Rome.
    var fixedNow: Date {
        DateComponents(calendar: calendar, year: 2026, month: 9, day: 28, hour: 10, minute: 0).date!
    }

    var context: DateContext {
        let now = fixedNow
        return DateContext(calendar: calendar, now: { now })
    }

    private func task(
        id: String,
        title: String = "task",
        due: TaskDue? = nil,
        priority: TaskPriority = .none,
        isCompleted: Bool = false
    ) -> TaskItem {
        TaskItem(id: id, listID: "list", title: title, due: due, priority: priority, isCompleted: isCompleted)
    }

    @Test func completedTasksAreDiscarded() {
        let completed = task(id: "1", due: nil, isCompleted: true)
        let sections = TaskClassifier.sections(for: [completed], context: context)
        #expect(sections.overdue.isEmpty)
        #expect(sections.today.isEmpty)
        #expect(sections.toPlan.isEmpty)
    }

    @Test func overdueDateTimeAndPastDay() {
        let pastDateTime = task(id: "1", due: .dateTime(fixedNow.addingTimeInterval(-3600)))
        let pastDay = task(id: "2", due: .day(DayDate(year: 2026, month: 9, day: 27)))
        let sections = TaskClassifier.sections(for: [pastDateTime, pastDay], context: context)
        #expect(Set(sections.overdue.map(\.id)) == Set(["1", "2"]))
    }

    @Test func overdueSortedByAscendingDeadline() {
        let later = task(id: "later", due: .dateTime(fixedNow.addingTimeInterval(-60)))
        let earlier = task(id: "earlier", due: .day(DayDate(year: 2026, month: 9, day: 20)))
        let sections = TaskClassifier.sections(for: [later, earlier], context: context)
        #expect(sections.overdue.map(\.id) == ["earlier", "later"])
    }

    @Test func todaySectionOnlyDateTimeTodayAtOrAfterNow() {
        let dueLater = task(id: "later", due: .dateTime(fixedNow.addingTimeInterval(3600)))
        let dueNow = task(id: "now", due: .dateTime(fixedNow))
        let sections = TaskClassifier.sections(for: [dueLater, dueNow], context: context)
        #expect(sections.today.map(\.id) == ["now", "later"])
    }

    @Test func futureDateTimeBeyondTodayIsInNoSection() {
        let tomorrowComponents = DateComponents(calendar: calendar, year: 2026, month: 9, day: 29, hour: 9)
        let futureTask = task(id: "future", due: .dateTime(tomorrowComponents.date!))
        let sections = TaskClassifier.sections(for: [futureTask], context: context)
        #expect(sections.overdue.isEmpty)
        #expect(sections.today.isEmpty)
        #expect(sections.toPlan.isEmpty)
    }

    @Test func dayDueTodayGoesToPlanNotToday() {
        let dueToday = task(id: "1", due: .day(DayDate(year: 2026, month: 9, day: 28)))
        let sections = TaskClassifier.sections(for: [dueToday], context: context)
        #expect(sections.today.isEmpty)
        #expect(sections.toPlan.map(\.id) == ["1"])
    }

    @Test func noDueDateGoesToPlan() {
        let noDue = task(id: "1", due: nil)
        let sections = TaskClassifier.sections(for: [noDue], context: context)
        #expect(sections.toPlan.map(\.id) == ["1"])
    }

    @Test func toPlanOrdering() {
        let laterDay = task(id: "laterDay", due: .day(DayDate(year: 2026, month: 10, day: 5)))
        let earlierDay = task(id: "earlierDay", due: .day(DayDate(year: 2026, month: 9, day: 30)))
        let noDueHighPriority = task(id: "highPriority", due: nil, priority: .high)
        let noDueLowPriorityB = task(id: "lowB", title: "banana", due: nil, priority: .low)
        let noDueLowPriorityA = task(id: "lowA", title: "arancia", due: nil, priority: .low)

        let sections = TaskClassifier.sections(
            for: [noDueLowPriorityB, laterDay, noDueHighPriority, earlierDay, noDueLowPriorityA],
            context: context
        )

        #expect(sections.toPlan.map(\.id) == ["earlierDay", "laterDay", "highPriority", "lowA", "lowB"])
    }
}
