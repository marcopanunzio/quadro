import DashboardCore
import SwiftUI

/// Modifica in sospeso su un evento: spostamento, ridimensionamento o eliminazione.
/// Prima di essere eseguita può richiedere conferma (invito organizzato da altri, ricorrenza).
struct PendingEventChange: Identifiable {
    enum Action {
        case move(newStart: Date)
        case resize(newEnd: Date)
        case delete
    }

    let id = UUID()
    let event: CalendarEvent
    let action: Action
}

/// Bozza di un nuovo evento disegnato trascinando su un'area vuota della griglia.
struct NewEventDraft: Equatable {
    let day: DayDate
    let dayIndex: Int
    let start: Date
    let end: Date
}

/// Un evento posizionato nella griglia oraria: spostabile e ridimensionabile con il trascinamento.
struct EventBlockView: View {
    let event: CalendarEvent
    let day: DayDate
    let dayIndex: Int
    let days: [DayDate]
    let slot: LayoutSlot
    let columnWidth: CGFloat
    let gutterWidth: CGFloat
    let geometry: GridGeometry
    let showLocation: Bool
    let onCommitChange: (PendingEventChange) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    @State private var dragTranslation: CGSize = .zero
    @State private var resizeTranslation: CGFloat = 0
    @State private var isActive = false

    private var dayStart: Date { day.startDate(in: model.calendar) }
    private var dayEnd: Date { model.calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart }
    private var visibleStart: Date { max(event.start, dayStart) }
    private var visibleEnd: Date { min(event.end, dayEnd) }
    private var baseY: CGFloat { geometry.y(for: visibleStart, on: day) }
    private var baseHeight: CGFloat { max(geometry.height(for: visibleEnd.timeIntervalSince(visibleStart)), 16) }
    private var displayHeight: CGFloat { max(baseHeight + resizeTranslation, 16) }
    private var slotWidth: CGFloat { columnWidth / CGFloat(max(slot.columnCount, 1)) }
    private var baseX: CGFloat { gutterWidth + CGFloat(dayIndex) * columnWidth + CGFloat(slot.column) * slotWidth }
    private var blockWidth: CGFloat { max(slotWidth - 4, 10) }
    private var accent: AccentName { model.accent(forCalendar: event.calendarID) }
    private var isSelected: Bool { model.selection == .event(event.id) }
    private var isCompact: Bool { displayHeight < 30 }

    /// Orario mostrato nel blocco: durante spostamento o ridimensionamento quello di arrivo (snap a 15 minuti).
    private var rangeText: String {
        if dragTranslation != .zero {
            let dayShift = Int((dragTranslation.width / columnWidth).rounded())
            let targetDay = days[min(max(dayIndex + dayShift, 0), days.count - 1)]
            let newStart = geometry.date(forY: baseY + dragTranslation.height, on: targetDay, snapMinutes: 15)
            return geometry.rangeLabel(newStart, newStart.addingTimeInterval(event.end.timeIntervalSince(event.start)))
        }
        if resizeTranslation != 0 {
            let minEnd = event.start.addingTimeInterval(15 * 60)
            let newEnd = max(geometry.date(forY: baseY + baseHeight + resizeTranslation, on: day, snapMinutes: 15), minEnd)
            return geometry.rangeLabel(visibleStart, newEnd)
        }
        return geometry.rangeLabel(visibleStart, visibleEnd)
    }

    var body: some View {
        content
            .padding(.horizontal, 6)
            .padding(.vertical, isCompact ? 2 : 4)
            .frame(width: blockWidth, height: displayHeight, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 6).fill(palette.fill(accent)))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(palette.accent(accent), lineWidth: isSelected ? 2 : 0)
            )
            .overlay(alignment: .bottom) {
                if event.isWritable {
                    resizeHandle
                }
            }
            .contentShape(Rectangle())
            .gesture(moveGesture)
            .onTapGesture { model.selection = .event(event.id) }
            .position(x: baseX + blockWidth / 2 + dragTranslation.width, y: baseY + displayHeight / 2 + dragTranslation.height)
            .opacity(isActive ? 0.85 : 1)
            .zIndex(isActive ? 1 : 0)
            .popover(isPresented: popoverBinding, arrowEdge: .trailing) {
                EventDetailView(event: event)
            }
            .contextMenu {
                Button("Modifica…") { model.selection = .event(event.id) }
                if event.isWritable {
                    Button("Elimina", role: .destructive) {
                        onCommitChange(PendingEventChange(event: event, action: .delete))
                    }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if isCompact {
            HStack(spacing: 4) {
                if !event.isWritable {
                    Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(palette.tx2)
                }
                Text(event.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.tx)
                    .lineLimit(1)
                Text(rangeText)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.accent(accent))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if !event.isWritable {
                        Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(palette.tx2)
                    }
                    Text(event.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.tx)
                        .lineLimit(1)
                }
                Text(rangeText)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.accent(accent))
                if showLocation, let location = event.location, !location.isEmpty, displayHeight > 60 {
                    Text(location)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.tx2)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 8)
            .contentShape(Rectangle())
            .pointerStyle(.frameResize(position: .bottom))
            .highPriorityGesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .named(TimeGridView.coordinateSpaceName))
                    .onChanged { value in
                        guard event.isWritable else { return }
                        isActive = true
                        resizeTranslation = value.translation.height
                    }
                    .onEnded { value in
                        defer { isActive = false; resizeTranslation = 0 }
                        guard event.isWritable else { return }
                        let newEndY = baseY + baseHeight + value.translation.height
                        var newEnd = geometry.date(forY: newEndY, on: day, snapMinutes: 15)
                        let minEnd = model.calendar.date(byAdding: .minute, value: 15, to: event.start) ?? event.start.addingTimeInterval(15 * 60)
                        if newEnd < minEnd { newEnd = minEnd }
                        guard newEnd != event.end else { return }
                        onCommitChange(PendingEventChange(event: event, action: .resize(newEnd: newEnd)))
                    }
            )
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(TimeGridView.coordinateSpaceName))
            .onChanged { value in
                guard event.isWritable else { return }
                isActive = true
                dragTranslation = value.translation
            }
            .onEnded { value in
                defer { isActive = false; dragTranslation = .zero }
                guard event.isWritable else { return }
                let dayShift = Int((value.translation.width / columnWidth).rounded())
                let targetIndex = min(max(dayIndex + dayShift, 0), days.count - 1)
                let targetDay = days[targetIndex]
                let newY = baseY + value.translation.height
                let newStart = geometry.date(forY: newY, on: targetDay, snapMinutes: 15)
                guard newStart != event.start || targetDay != day else { return }
                onCommitChange(PendingEventChange(event: event, action: .move(newStart: newStart)))
            }
    }

    private var popoverBinding: Binding<Bool> {
        Binding(
            get: { model.selection == .event(event.id) },
            set: { isPresented in if !isPresented { model.selection = nil } }
        )
    }
}

/// Un promemoria pianificato in un orario, mostrato come blocco nella griglia. Si sposta come gli eventi
/// (segue il cursore, snap a 15 minuti, anche su altri giorni); rilasciato fuori dalla griglia, sopra la lista,
/// perde l'ora (REQ-055).
struct TaskBlockView: View {
    let task: TaskItem
    let day: DayDate
    let dayIndex: Int
    let days: [DayDate]
    let slot: LayoutSlot
    let columnWidth: CGFloat
    let gutterWidth: CGFloat
    let geometry: GridGeometry

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    @State private var dragTranslation: CGSize = .zero
    @State private var pointerX: CGFloat?

    private var start: Date {
        if case .dateTime(let date) = task.due { return date }
        return day.startDate(in: model.calendar)
    }

    private var baseY: CGFloat { geometry.y(for: start, on: day) }
    private var baseHeight: CGFloat { max(geometry.height(for: model.taskBlockDuration), 16) }
    private var slotWidth: CGFloat { columnWidth / CGFloat(max(slot.columnCount, 1)) }
    private var baseX: CGFloat { gutterWidth + CGFloat(dayIndex) * columnWidth + CGFloat(slot.column) * slotWidth }
    private var blockWidth: CGFloat { max(slotWidth - 4, 10) }
    private var gridWidth: CGFloat { gutterWidth + CGFloat(days.count) * columnWidth }
    private var accent: AccentName { model.accent(forCalendar: task.listID) }
    private var isSelected: Bool { model.selection == .task(task.id) }
    private var isDone: Bool { model.isDone(task) }
    private var isDragging: Bool { pointerX != nil }
    private var isOutsideGrid: Bool { (pointerX ?? 0) > gridWidth }

    /// Giorno e ora di arrivo per uno spostamento, con snap a 15 minuti.
    private func target(for translation: CGSize) -> Date {
        let dayShift = Int((translation.width / columnWidth).rounded())
        let targetDay = days[min(max(dayIndex + dayShift, 0), days.count - 1)]
        return geometry.date(forY: baseY + translation.height, on: targetDay, snapMinutes: 15)
    }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                model.toggleCompleted(task)
            } label: {
                Circle()
                    .strokeBorder(palette.accent(accent), lineWidth: 1.5)
                    .background(Circle().fill(isDone ? palette.accent(accent) : Color.clear))
                    .frame(width: 10, height: 10)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone ? "Segna come da fare" : "Segna come completato")

            Text(task.title)
                .font(.system(size: 12))
                .foregroundStyle(isDone ? palette.tx2 : palette.tx)
                .strikethrough(isDone, color: palette.tx2)
                .lineLimit(1)
            Spacer(minLength: 0)
            if isDragging {
                Text(isOutsideGrid ? "Togli ora" : geometry.timeLabel(target(for: dragTranslation)))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent(accent))
                    .lineLimit(1)
            }
        }
        .padding(.leading, 2)
        .padding(.trailing, 6)
        .frame(width: blockWidth, height: baseHeight, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(palette.bg))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isDone ? palette.ui3 : palette.accent(accent), lineWidth: isSelected || isDragging ? 2 : 1)
        )
        .opacity(isDone ? 0.7 : (isDragging ? 0.9 : 1))
        .contentShape(Rectangle())
        .gesture(moveGesture)
        .onTapGesture { model.selection = .task(task.id) }
        .position(x: baseX + blockWidth / 2 + dragTranslation.width, y: baseY + baseHeight / 2 + dragTranslation.height)
        .zIndex(isDragging ? 1 : 0)
        .popover(isPresented: popoverBinding, arrowEdge: .trailing) {
            TaskDetailView(task: task)
        }
        .contextMenu {
            Button(isDone ? "Riapri" : "Completa") { model.toggleCompleted(task) }
            Button("Togli ora") { model.unschedule(taskID: task.id) }
            Button("Elimina", role: .destructive) { model.delete(task) }
        }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(TimeGridView.coordinateSpaceName))
            .onChanged { value in
                dragTranslation = value.translation
                pointerX = value.location.x
                let overList = value.location.x > gridWidth
                if model.isTaskDragOverList != overList { model.isTaskDragOverList = overList }
            }
            .onEnded { value in
                defer {
                    dragTranslation = .zero
                    pointerX = nil
                    model.isTaskDragOverList = false
                }
                if value.location.x > gridWidth {
                    model.unschedule(taskID: task.id)
                    return
                }
                let newStart = target(for: value.translation)
                guard newStart != start else { return }
                model.schedule(taskID: task.id, at: newStart)
            }
    }

    private var popoverBinding: Binding<Bool> {
        Binding(
            get: { model.selection == .task(task.id) },
            set: { isPresented in if !isPresented { model.selection = nil } }
        )
    }
}

/// Task con sola data futura nella fascia "tutto il giorno": si completa dal pallino, si apre con un clic
/// e si trascina su uno slot orario per dargli un'ora.
struct AllDayTaskChip: View {
    let task: TaskItem

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    private var accent: AccentName { model.accent(forCalendar: task.listID) }
    private var isDone: Bool { model.isDone(task) }

    var body: some View {
        HStack(spacing: 4) {
            Button {
                model.toggleCompleted(task)
            } label: {
                Circle()
                    .strokeBorder(palette.accent(accent), lineWidth: 1.5)
                    .background(Circle().fill(isDone ? palette.accent(accent) : Color.clear))
                    .frame(width: 9, height: 9)
                    .padding(2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone ? "Segna come da fare" : "Segna come completato")

            Text(task.title)
                .font(.system(size: 11))
                .foregroundStyle(isDone ? palette.tx2 : palette.tx)
                .strikethrough(isDone, color: palette.tx2)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { model.selection = .task(task.id) }
                .draggable(DragPayload.task(id: task.id).string)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 4).fill(palette.bg))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(palette.accent(accent), lineWidth: model.selection == .task(task.id) ? 2 : 1)
        )
        .opacity(isDone ? 0.7 : 1)
        .popover(
            isPresented: Binding(
                get: { model.selection == .task(task.id) },
                set: { if !$0 { model.selection = nil } }
            ),
            arrowEdge: .bottom
        ) {
            TaskDetailView(task: task)
        }
        .contextMenu {
            Button(isDone ? "Riapri" : "Completa") { model.toggleCompleted(task) }
            Button("Togli data") { model.unschedule(taskID: task.id) }
            Button("Elimina", role: .destructive) { model.delete(task) }
        }
    }
}

/// Livello unico con tutti i blocchi di tutti i giorni visibili: consente di trascinare un evento tra colonne
/// (giorni) diversi restando in un unico spazio di coordinate.
struct AllBlocksLayer: View {
    let days: [DayDate]
    let columnWidth: CGFloat
    let gutterWidth: CGFloat
    let geometry: GridGeometry
    let showLocation: Bool
    let onCommitChange: (PendingEventChange) -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        ForEach(Array(days.enumerated()), id: \.element) { index, day in
            dayBlocks(day: day, dayIndex: index)
        }
    }

    @ViewBuilder
    private func dayBlocks(day: DayDate, dayIndex: Int) -> some View {
        let events = model.timedEvents(on: day)
        let tasks = model.scheduledTasks(on: day)
        let dayStart = day.startDate(in: model.calendar)

        let taskInputs: [LayoutInput] = tasks.map { task in
            let start: Date = {
                if case .dateTime(let date) = task.due { return date }
                return dayStart
            }()
            return LayoutInput(id: "t-\(task.id)", start: start, end: start.addingTimeInterval(model.taskBlockDuration))
        }
        let inputs = events.map { LayoutInput(id: "e-\($0.id)", start: $0.start, end: $0.end) } + taskInputs
        let slots = EventLayout.layout(inputs)

        ForEach(events) { event in
            EventBlockView(
                event: event,
                day: day,
                dayIndex: dayIndex,
                days: days,
                slot: slots["e-\(event.id)"] ?? LayoutSlot(column: 0, columnCount: 1),
                columnWidth: columnWidth,
                gutterWidth: gutterWidth,
                geometry: geometry,
                showLocation: showLocation,
                onCommitChange: onCommitChange
            )
        }
        ForEach(tasks) { task in
            TaskBlockView(
                task: task,
                day: day,
                dayIndex: dayIndex,
                days: days,
                slot: slots["t-\(task.id)"] ?? LayoutSlot(column: 0, columnCount: 1),
                columnWidth: columnWidth,
                gutterWidth: gutterWidth,
                geometry: geometry
            )
        }
    }
}
