import DashboardCore
import SwiftUI

/// Griglia oraria (viste giorno e settimana): intestazione colonne, riga "tutto il giorno", righe delle ore
/// con gli eventi/task, linea dell'ora attuale, creazione trascinando o con doppio clic, e drop dei task.
struct TimeGridView: View {
    private let gutterWidth: CGFloat = 48
    private let hourHeight: CGFloat = 54
    private let headerHeight: CGFloat = 44
    private static let scrollAnchorID = "time-grid-0730"

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    @State private var newEventDraft: NewEventDraft?
    @State private var dropTargetDay: DayDate?
    @State private var didSetInitialScroll = false

    @State private var organizerWarningChange: PendingEventChange?
    @State private var recurrenceChoiceChange: PendingEventChange?

    private var geometry: GridGeometry { GridGeometry(hourHeight: hourHeight, calendar: model.calendar) }

    var body: some View {
        let days = model.visibleDays

        GeometryReader { proxy in
            let columnWidth = max(0, (proxy.size.width - gutterWidth) / CGFloat(max(days.count, 1)))

            VStack(spacing: 0) {
                columnHeaders(days: days, columnWidth: columnWidth)
                allDayRow(days: days, columnWidth: columnWidth)
                Rectangle().fill(palette.ui).frame(height: 1)
                scrollableGrid(days: days, columnWidth: columnWidth, totalWidth: proxy.size.width)
            }
        }
        .alert(
            "Invito organizzato da altri",
            isPresented: Binding(
                get: { organizerWarningChange != nil },
                set: { isPresented in if !isPresented { organizerWarningChange = nil } }
            )
        ) {
            Button("Annulla", role: .cancel) { organizerWarningChange = nil }
            Button("Sposta") {
                if let change = organizerWarningChange {
                    organizerWarningChange = nil
                    proceedAfterOrganizerWarning(change)
                }
            }
        } message: {
            Text("Se lo sposti cambia solo la tua copia e l'organizzatore non viene avvisato.")
        }
        .confirmationDialog(
            "Evento ricorrente",
            isPresented: Binding(
                get: { recurrenceChoiceChange != nil },
                set: { isPresented in if !isPresented { recurrenceChoiceChange = nil } }
            )
        ) {
            Button("Solo questo evento") {
                if let change = recurrenceChoiceChange { commit(change, span: .thisOccurrence) }
                recurrenceChoiceChange = nil
            }
            Button("Questo e i futuri") {
                if let change = recurrenceChoiceChange { commit(change, span: .futureOccurrences) }
                recurrenceChoiceChange = nil
            }
            Button("Annulla", role: .cancel) { recurrenceChoiceChange = nil }
        }
    }

    // MARK: Griglia scorrevole

    @ViewBuilder
    private func scrollableGrid(days: [DayDate], columnWidth: CGFloat, totalWidth: CGFloat) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical) {
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        gutterColumn
                        daysArea(days: days, columnWidth: columnWidth)
                    }
                    AllBlocksLayer(
                        days: days,
                        columnWidth: columnWidth,
                        gutterWidth: gutterWidth,
                        geometry: geometry,
                        showLocation: days.count == 1,
                        onCommitChange: requestChange
                    )
                    ForEach(days.filter { $0 == model.today }, id: \.self) { day in
                        currentTimeLine(day: day, dayIndex: days.firstIndex(of: day) ?? 0, columnWidth: columnWidth)
                    }
                    if let draft = newEventDraft {
                        newEventGhost(draft, columnWidth: columnWidth)
                    }
                    Color.clear
                        .frame(width: 1, height: 1)
                        .id(Self.scrollAnchorID)
                        .position(x: 0, y: 7.5 * hourHeight)
                }
                .frame(width: totalWidth, height: geometry.totalHeight, alignment: .topLeading)
            }
            .onAppear {
                guard !didSetInitialScroll else { return }
                didSetInitialScroll = true
                DispatchQueue.main.async {
                    scrollProxy.scrollTo(Self.scrollAnchorID, anchor: .top)
                }
            }
        }
    }

    private var gutterColumn: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<24, id: \.self) { hour in
                Text("\(hour):00")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.tx2)
                    .frame(width: gutterWidth - 8, alignment: .trailing)
                    .position(x: (gutterWidth - 8) / 2, y: CGFloat(hour) * hourHeight)
            }
        }
        .frame(width: gutterWidth, height: geometry.totalHeight, alignment: .topLeading)
    }

    private func daysArea(days: [DayDate], columnWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                dayColumnBackground(day: day, columnWidth: columnWidth)
            }
        }
        .contentShape(Rectangle())
        .gesture(newEventDragGesture(days: days, columnWidth: columnWidth))
        .simultaneousGesture(doubleTapGesture(days: days, columnWidth: columnWidth))
    }

    private func dayColumnBackground(day: DayDate, columnWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            if day == model.today && model.viewMode == .week {
                palette.now.opacity(0.04)
            }
            if dropTargetDay == day {
                palette.selection.opacity(0.12)
            }
            hourLines
        }
        .frame(width: columnWidth, height: geometry.totalHeight, alignment: .topLeading)
        .overlay(alignment: .leading) { Rectangle().fill(palette.ui).frame(width: 1) }
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, location in
            handleTaskDrop(items: items, day: day, location: location)
        } isTargeted: { targeted in
            dropTargetDay = targeted ? day : (dropTargetDay == day ? nil : dropTargetDay)
        }
    }

    private var hourLines: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { _ in
                Rectangle().fill(palette.ui).frame(height: 1)
                Color.clear.frame(height: hourHeight - 1)
            }
        }
    }

    private func currentTimeLine(day: DayDate, dayIndex: Int, columnWidth: CGFloat) -> some View {
        let y = geometry.y(for: model.now, on: day)
        let x = gutterWidth + CGFloat(dayIndex) * columnWidth
        return ZStack(alignment: .topLeading) {
            Circle().fill(palette.now).frame(width: 8, height: 8).position(x: 4, y: y)
            Rectangle().fill(palette.now).frame(width: columnWidth, height: 2).position(x: columnWidth / 2, y: y)
        }
        .frame(width: columnWidth, height: geometry.totalHeight, alignment: .topLeading)
        .offset(x: x)
        .allowsHitTesting(false)
    }

    // MARK: Intestazione colonne

    private func columnHeaders(days: [DayDate], columnWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: gutterWidth)
            ForEach(days, id: \.self) { day in
                columnHeader(day: day).frame(width: columnWidth)
            }
        }
        .frame(height: headerHeight)
    }

    private func columnHeader(day: DayDate) -> some View {
        let date = day.startDate(in: model.calendar)
        let isToday = day == model.today
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.calendar = model.calendar
        weekdayFormatter.locale = Locale(identifier: "it_IT")
        weekdayFormatter.dateFormat = model.viewMode == .day ? "EEEE" : "EEE"
        let weekdayText = weekdayFormatter.string(from: date)
        let dayNumber = model.calendar.component(.day, from: date)

        return VStack(spacing: 4) {
            Text(model.viewMode == .day ? weekdayText : weekdayText.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isToday ? palette.now : palette.tx2)
            if isToday {
                Text("\(dayNumber)")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(palette.now))
                    .foregroundStyle(palette.bg)
            } else {
                Text("\(dayNumber)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.tx)
            }
        }
    }

    // MARK: Riga "tutto il giorno"

    private func allDayRow(days: [DayDate], columnWidth: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Color.clear.frame(width: gutterWidth)
            ForEach(days, id: \.self) { day in
                allDayCell(day: day).frame(width: columnWidth, alignment: .leading)
            }
        }
    }

    private func allDayCell(day: DayDate) -> some View {
        let events = model.allDayEvents(on: day)
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(events) { event in
                HStack(spacing: 4) {
                    if !event.isWritable {
                        Image(systemName: "lock.fill").font(.system(size: 9))
                    }
                    Text(event.title)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(palette.tx)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(palette.fill(model.accent(forCalendar: event.calendarID))))
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, events.isEmpty ? 0 : 4)
    }

    // MARK: Nuovo evento (trascinamento e doppio clic)

    private func newEventDragGesture(days: [DayDate], columnWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                guard !days.isEmpty else { return }
                let dayIndex = min(max(Int(value.startLocation.x / columnWidth), 0), days.count - 1)
                let day = days[dayIndex]
                let startY = min(value.startLocation.y, value.location.y)
                let endY = max(value.startLocation.y, value.location.y)
                let start = geometry.date(forY: startY, on: day, snapMinutes: 15)
                var end = geometry.date(forY: endY, on: day, snapMinutes: 15)
                if end <= start {
                    end = model.calendar.date(byAdding: .minute, value: 15, to: start) ?? start.addingTimeInterval(15 * 60)
                }
                newEventDraft = NewEventDraft(day: day, dayIndex: dayIndex, start: start, end: end)
            }
            .onEnded { _ in
                if let draft = newEventDraft {
                    createEvent(start: draft.start, end: draft.end)
                }
                newEventDraft = nil
            }
    }

    private func doubleTapGesture(days: [DayDate], columnWidth: CGFloat) -> some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { value in
                guard !days.isEmpty else { return }
                let dayIndex = min(max(Int(value.location.x / columnWidth), 0), days.count - 1)
                let day = days[dayIndex]
                let start = geometry.date(forY: value.location.y, on: day, snapMinutes: 30)
                let end = model.calendar.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
                createEvent(start: start, end: end)
            }
    }

    private func newEventGhost(_ draft: NewEventDraft, columnWidth: CGFloat) -> some View {
        let x = gutterWidth + CGFloat(draft.dayIndex) * columnWidth + 2
        let y = geometry.y(for: draft.start, on: draft.day)
        let height = max(geometry.height(for: draft.end.timeIntervalSince(draft.start)), 16)
        let width = max(columnWidth - 4, 10)
        let accent = model.defaultEventCalendar.map { model.accent(forCalendar: $0.id) } ?? .blue

        return Text(geometry.rangeLabel(draft.start, draft.end))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(palette.accent(accent))
            .padding(4)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 6).fill(palette.fill(accent)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.accent(accent), lineWidth: 1))
            .position(x: x + width / 2, y: y + height / 2)
            .allowsHitTesting(false)
    }

    private func createEvent(start: Date, end: Date) {
        Task {
            _ = await model.createEvent(EventDraft(calendarID: model.defaultEventCalendar?.id, title: "Nuovo evento", start: start, end: end))
        }
    }

    // MARK: Drop dei task

    private func handleTaskDrop(items: [String], day: DayDate, location: CGPoint) -> Bool {
        guard let raw = items.first, case .task(let id) = DragPayload(raw) else { return false }
        let date = geometry.date(forY: location.y, on: day, snapMinutes: 15)
        model.schedule(taskID: id, at: date)
        return true
    }

    // MARK: Conferme su spostamento/ridimensionamento/eliminazione

    private func requestChange(_ change: PendingEventChange) {
        let isMoveOrResize: Bool
        switch change.action {
        case .delete: isMoveOrResize = false
        case .move, .resize: isMoveOrResize = true
        }
        if isMoveOrResize && change.event.needsOrganizerWarning {
            organizerWarningChange = change
            return
        }
        proceedAfterOrganizerWarning(change)
    }

    private func proceedAfterOrganizerWarning(_ change: PendingEventChange) {
        if change.event.isRecurring {
            recurrenceChoiceChange = change
        } else {
            commit(change, span: .thisOccurrence)
        }
    }

    private func commit(_ change: PendingEventChange, span: EditSpan) {
        switch change.action {
        case .move(let newStart): model.move(change.event, toStart: newStart, span: span)
        case .resize(let newEnd): model.resize(change.event, toEnd: newEnd, span: span)
        case .delete: model.delete(change.event, span: span)
        }
    }
}
