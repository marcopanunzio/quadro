import DashboardCore
import SwiftUI

struct MonthView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            // Header with day names
            headerRow

            // Grid of weeks
            VStack(spacing: 0) {
                ForEach(model.monthRows, id: \.self) { week in
                    HStack(spacing: 0) {
                        ForEach(week, id: \.self) { day in
                            MonthDayCell(day: day)
                                .background(dayBackgroundColor(day))
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .border(palette.ui, width: 1)
                }
            }
            .border(palette.ui, width: 1)
        }
    }

    private var headerRow: some View {
        let symbols = model.calendar.shortWeekdaySymbols
        let firstWeekday = model.calendar.firstWeekday
        let rotated = Array(symbols.dropFirst(firstWeekday - 1)) + Array(symbols.prefix(firstWeekday - 1))

        return HStack(spacing: 0) {
            ForEach(rotated, id: \.self) { dayName in
                Text(dayName.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.tx2)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .padding(.leading, 8)
            }
        }
        .border(palette.ui, width: 1)
    }

    private func dayBackgroundColor(_ day: DayDate) -> Color {
        let isInMonth = model.calendar.component(.month, from: day.startDate(in: model.calendar)) == model.anchorMonth
        return isInMonth ? palette.bg : palette.bg2
    }
}

struct MonthDayCell: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    let day: DayDate

    @State private var isTargeted = false

    var body: some View {
        let isInMonth = model.calendar.component(.month, from: day.startDate(in: model.calendar)) == model.anchorMonth
        let isToday = model.today == day
        let allDayEvents = model.allDayEvents(on: day)
        let timedEvents = model.timedEvents(on: day)
        let scheduledTasks = model.scheduledTasks(on: day) + model.dayOnlyTasks(on: day)
        let busyHours = model.busyHours(on: day)

        // Combine all items and sort by start time
        let items = combineItems(allDay: allDayEvents, timed: timedEvents, tasks: scheduledTasks)

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                // Day number
                if isToday {
                    Text("\(day.day)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(palette.bg)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(palette.now))
                } else {
                    Text("\(day.day)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(palette.tx)
                        .opacity(isInMonth ? 1 : 0.6)
                }

                // Density bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(densityBarColor(busyHours))
                    .frame(height: 4)
                    .frame(width: calculateBarFill(busyHours))
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(palette.ui)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }

            // Items (max 3)
            ForEach(items.prefix(3), id: \.id) { item in
                itemRow(item, isInMonth: isInMonth)
            }

            if items.count > 3 {
                Text("+\(items.count - 3) altri")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.tx2)
            }

            Spacer()
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isTargeted ? palette.selection.opacity(0.1) : Color.clear)
        .border(isTargeted ? palette.selection : Color.clear, width: isTargeted ? 2 : 0)
        .contentShape(Rectangle())
        .onTapGesture {
            model.show(day: day, mode: .day)
        }
        .liveOnly { $0.dropDestination(for: String.self) { strings, location in
            for string in strings {
                if let payload = DragPayload(string), case .task(let id) = payload {
                    model.schedule(taskID: id, on: day)
                    return true
                }
            }
            return false
        } isTargeted: { targeted in
            isTargeted = targeted
        } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(day, items: items))
    }

    private func itemRow(_ item: DayItem, isInMonth: Bool) -> some View {
        HStack(spacing: 4) {
            // Color dot
            Circle()
                .fill(item.color)
                .frame(width: 6, height: 6)

            // Time (if not all-day)
            if !item.isAllDay {
                Text(item.time)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.tx2)
                    .frame(width: 32, alignment: .leading)
            } else {
                Text("")
                    .frame(width: 32, alignment: .leading)
            }

            // Title
            Text(item.title)
                .font(.system(size: 11))
                .foregroundStyle(palette.tx)
                .lineLimit(1)
                .truncationMode(.tail)
                .opacity(isInMonth ? 1 : 0.6)
        }
        .frame(height: 11)
    }

    private struct DayItem: Identifiable {
        let id: String
        let title: String
        let color: Color
        let isAllDay: Bool
        let time: String
        let startDate: Date?
    }

    private func combineItems(
        allDay: [CalendarEvent],
        timed: [CalendarEvent],
        tasks: [TaskItem]
    ) -> [DayItem] {
        var items: [DayItem] = []

        // Add all-day events first
        for event in allDay {
            let accent = model.accent(forCalendar: event.calendarID)
            items.append(DayItem(
                id: event.id,
                title: event.title,
                color: palette.accent(accent),
                isAllDay: true,
                time: "",
                startDate: event.start
            ))
        }

        // Add timed events
        for event in timed {
            let accent = model.accent(forCalendar: event.calendarID)
            let timeStr = timeString(event.start)
            items.append(DayItem(
                id: event.id,
                title: event.title,
                color: palette.accent(accent),
                isAllDay: false,
                time: timeStr,
                startDate: event.start
            ))
        }

        // Add scheduled tasks
        for task in tasks {
            let accent = model.accent(forCalendar: task.listID)
            if case .dateTime(let date) = task.due {
                let timeStr = timeString(date)
                items.append(DayItem(
                    id: task.id,
                    title: task.title,
                    color: palette.accent(accent),
                    isAllDay: false,
                    time: timeStr,
                    startDate: date
                ))
            } else if case .day(let dueDay) = task.due {
                items.append(DayItem(
                    id: task.id,
                    title: task.title,
                    color: palette.accent(accent),
                    isAllDay: true,
                    time: "",
                    startDate: dueDay.startDate(in: model.calendar)
                ))
            }
        }

        // Sort by start time (all-day events are already first)
        return items.sorted { (a, b) in
            if let dateA = a.startDate, let dateB = b.startDate {
                return dateA < dateB
            }
            return false
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }

    private func densityBarColor(_ hours: Double) -> Color {
        hours >= 6 ? palette.now : palette.tx2
    }

    private func calculateBarFill(_ hours: Double) -> CGFloat {
        let percentage = min(hours / 8, 1.0)
        return percentage * 30 // Max width 30 for visual balance
    }

    private func accessibilityLabel(_ day: DayDate, items: [DayItem]) -> String {
        let dayName = dayString(day)
        let itemCount = items.count
        let itemText = itemCount == 1 ? "1 evento" : "\(itemCount) eventi"
        return "\(dayName), \(itemText)"
    }

    private func dayString(_ day: DayDate) -> String {
        let date = day.startDate(in: model.calendar)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}
