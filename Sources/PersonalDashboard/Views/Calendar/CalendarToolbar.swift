import DashboardCore
import SwiftUI

/// Barra strumenti del riquadro calendario: vista, navigazione, titolo del periodo, menu calendari, nuovo evento.
struct CalendarToolbar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 12) {
            Picker("Vista", selection: $model.viewMode) {
                Text("Giorno").tag(CalendarViewMode.day)
                Text("Settimana").tag(CalendarViewMode.week)
                Text("Mese").tag(CalendarViewMode.month)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)

            Button("Oggi") { model.goToToday() }

            HStack(spacing: 2) {
                Button { model.step(-1) } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Periodo precedente")

                Button { model.step(1) } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Periodo successivo")
            }
            .buttonStyle(.borderless)

            Text(periodTitle)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(palette.tx)
                .lineLimit(1)

            Spacer(minLength: 8)

            calendarsMenu

            Button {
                createNewEvent()
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Nuovo evento")
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .onChange(of: model.newEventRequest) { _, _ in createNewEvent() }
    }

    // MARK: Titolo periodo

    private var periodTitle: String {
        switch model.viewMode {
        case .day: dayTitle
        case .week: weekTitle
        case .month: monthTitle
        }
    }

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = model.calendar
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "EEEE d MMMM yyyy"
        return capitalizedFirstLetter(formatter.string(from: model.anchorDate))
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = model.calendar
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "MMMM yyyy"
        return capitalizedFirstLetter(formatter.string(from: model.anchorDate))
    }

    private var weekTitle: String {
        guard let first = model.visibleDays.first, let last = model.visibleDays.last else { return "" }
        let calendar = model.calendar
        let startDate = first.startDate(in: calendar)
        let endDate = last.startDate(in: calendar)
        let sameYear = first.year == last.year

        let startFormatter = DateFormatter()
        startFormatter.calendar = calendar
        startFormatter.locale = Locale(identifier: "it_IT")
        startFormatter.dateFormat = sameYear ? "d MMM" : "d MMM yyyy"

        let endFormatter = DateFormatter()
        endFormatter.calendar = calendar
        endFormatter.locale = Locale(identifier: "it_IT")
        endFormatter.dateFormat = "d MMM yyyy"

        return "\(startFormatter.string(from: startDate)) – \(endFormatter.string(from: endDate))"
    }

    private func capitalizedFirstLetter(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    // MARK: Menu calendari

    private var calendarsMenu: some View {
        Menu {
            ForEach(groupedCalendars, id: \.key) { group in
                Section(group.key) {
                    ForEach(group.value) { calendarInfo in
                        Toggle(isOn: calendarVisibilityBinding(for: calendarInfo.id)) {
                            calendarRow(title: calendarInfo.title, accent: model.accent(forCalendar: calendarInfo.id), isWritable: calendarInfo.isWritable)
                        }
                    }
                }
            }
            if !model.taskLists.isEmpty {
                Section("Liste promemoria") {
                    ForEach(model.taskLists) { list in
                        Toggle(isOn: taskListVisibilityBinding(for: list.id)) {
                            calendarRow(title: list.title, accent: model.accent(forCalendar: list.id), isWritable: true)
                        }
                    }
                }
            }
        } label: {
            calendarsMenuIcon
        }
        .accessibilityLabel("Calendari")
        .menuIndicator(.hidden)
    }

    private func calendarRow(title: String, accent: AccentName, isWritable: Bool) -> some View {
        HStack(spacing: 6) {
            Circle().fill(palette.accent(accent)).frame(width: 8, height: 8)
            Text(title)
            if !isWritable {
                Image(systemName: "lock.fill")
            }
        }
    }

    /// Icona decorativa del menu: 4 pallini colorati.
    private var calendarsMenuIcon: some View {
        let accents: [AccentName] = [.blue, .green, .orange, .purple]
        return VStack(spacing: 2) {
            HStack(spacing: 2) {
                Circle().fill(palette.accent(accents[0])).frame(width: 6, height: 6)
                Circle().fill(palette.accent(accents[1])).frame(width: 6, height: 6)
            }
            HStack(spacing: 2) {
                Circle().fill(palette.accent(accents[2])).frame(width: 6, height: 6)
                Circle().fill(palette.accent(accents[3])).frame(width: 6, height: 6)
            }
        }
        .frame(width: 16, height: 16)
    }

    private var groupedCalendars: [(key: String, value: [CalendarInfo])] {
        var order: [String] = []
        var groups: [String: [CalendarInfo]] = [:]
        for calendarInfo in model.calendars {
            if groups[calendarInfo.sourceTitle] == nil {
                order.append(calendarInfo.sourceTitle)
                groups[calendarInfo.sourceTitle] = []
            }
            groups[calendarInfo.sourceTitle]?.append(calendarInfo)
        }
        return order.map { (key: $0, value: groups[$0] ?? []) }
    }

    private func calendarVisibilityBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { !model.settings.hiddenCalendarIDs.contains(id) },
            set: { isVisible in
                var settings = model.settings
                if isVisible { settings.hiddenCalendarIDs.remove(id) } else { settings.hiddenCalendarIDs.insert(id) }
                model.settings = settings
            }
        )
    }

    private func taskListVisibilityBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { !model.settings.hiddenTaskListIDs.contains(id) },
            set: { isVisible in
                var settings = model.settings
                if isVisible { settings.hiddenTaskListIDs.remove(id) } else { settings.hiddenTaskListIDs.insert(id) }
                model.settings = settings
            }
        )
    }

    // MARK: Nuovo evento

    private func createNewEvent() {
        let calendar = model.calendar
        let now = model.now
        let flooredHour = calendar.date(bySetting: .minute, value: 0, of: calendar.date(bySetting: .second, value: 0, of: now) ?? now) ?? now
        let start = calendar.date(byAdding: .hour, value: 1, to: flooredHour) ?? now.addingTimeInterval(3600)
        let end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
        Task {
            _ = await model.createEvent(EventDraft(calendarID: model.defaultEventCalendar?.id, title: "Nuovo evento", start: start, end: end))
        }
    }
}
