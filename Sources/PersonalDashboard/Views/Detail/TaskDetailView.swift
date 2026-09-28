import DashboardCore
import SwiftUI

/// Popover di dettaglio di un promemoria (TASK-015). Salvataggio subito a ogni modifica confermata.
struct TaskDetailView: View {
    let task: TaskItem

    @Environment(\.palette) private var palette
    @Environment(AppModel.self) private var model

    @State private var draft: TaskItem
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case title, notes }
    private enum DueKind: Hashable { case none, day, dateTime }

    init(task: TaskItem) {
        self.task = task
        _draft = State(initialValue: task)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            VStack(spacing: 0) {
                DetailRow("Scadenza") { dueControls }
                DetailDivider()
                DetailRow("Lista") { listControl }
                DetailDivider()
                DetailRow("Priorità") { priorityControl }
                DetailDivider()
                DetailRow("Note") {
                    TextField("Aggiungi note", text: notesBinding, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .focused($focusedField, equals: .notes)
                        .onSubmit { save() }
                }
            }

            footer
        }
        .padding(16)
        .frame(width: 320)
        .onChange(of: focusedField) { oldValue, _ in
            if oldValue != nil { save() }
        }
        .onChange(of: task) { _, newValue in
            guard focusedField == nil else { return }
            draft = newValue
        }
    }

    // MARK: Sezioni

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(palette.accent(model.accent(forCalendar: draft.listID)))
                .frame(width: 10, height: 10)
            TextField("Titolo", text: $draft.title)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .bold))
                .focused($focusedField, equals: .title)
                .onSubmit { save() }
            Spacer(minLength: 0)
            Button {
                save()
                model.selection = nil
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(palette.tx2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Chiudi")
        }
    }

    @ViewBuilder
    private var dueControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("", selection: dueKindBinding) {
                Text("Nessuna").tag(DueKind.none)
                Text("Giorno").tag(DueKind.day)
                Text("Giorno e ora").tag(DueKind.dateTime)
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            switch dueKindBinding.wrappedValue {
            case .none:
                EmptyView()
            case .day:
                DatePicker("", selection: dayBinding, displayedComponents: .date)
                    .labelsHidden()
            case .dateTime:
                DatePicker("", selection: dateTimeBinding, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
        }
    }

    private var listControl: some View {
        Picker("", selection: listBinding) {
            ForEach(model.taskLists) { list in
                HStack(spacing: 6) {
                    Circle()
                        .fill(palette.accent(model.accent(forCalendar: list.id)))
                        .frame(width: 8, height: 8)
                    Text(list.title)
                }
                .tag(list.id)
            }
        }
        .labelsHidden()
    }

    private var priorityControl: some View {
        Picker("", selection: priorityBinding) {
            Text("Nessuna").tag(TaskPriority.none)
            Text("Bassa").tag(TaskPriority.low)
            Text("Media").tag(TaskPriority.medium)
            Text("Alta").tag(TaskPriority.high)
        }
        .labelsHidden()
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(task.isCompleted ? "Riapri" : "Completa") {
                model.toggleCompleted(draft)
            }
            .buttonStyle(.bordered)
            Button("Elimina") {
                model.delete(draft)
            }
            .buttonStyle(.bordered)
            .foregroundStyle(palette.overdue)
        }
    }

    // MARK: Binding e logica di salvataggio

    private var notesBinding: Binding<String> {
        Binding(
            get: { draft.notes ?? "" },
            set: { draft.notes = $0.isEmpty ? nil : $0 }
        )
    }

    private var listBinding: Binding<String> {
        Binding(
            get: { draft.listID },
            set: { newValue in
                draft.listID = newValue
                save()
            }
        )
    }

    private var priorityBinding: Binding<TaskPriority> {
        Binding(
            get: { draft.priority },
            set: { newValue in
                draft.priority = newValue
                save()
            }
        )
    }

    private var dueKindBinding: Binding<DueKind> {
        Binding(
            get: {
                switch draft.due {
                case nil: .none
                case .day: .day
                case .dateTime: .dateTime
                }
            },
            set: { newKind in
                switch newKind {
                case .none:
                    draft.due = nil
                case .day:
                    if case .day = draft.due {} else { draft.due = .day(model.today) }
                case .dateTime:
                    if case .dateTime = draft.due {} else { draft.due = .dateTime(nextFullHour()) }
                }
                save()
            }
        )
    }

    private var dayBinding: Binding<Date> {
        Binding(
            get: {
                if case .day(let day) = draft.due { return day.startDate(in: model.calendar) }
                return model.today.startDate(in: model.calendar)
            },
            set: { newValue in
                draft.due = .day(DayDate(newValue, calendar: model.calendar))
                save()
            }
        )
    }

    private var dateTimeBinding: Binding<Date> {
        Binding(
            get: {
                if case .dateTime(let date) = draft.due { return date }
                return nextFullHour()
            },
            set: { newValue in
                draft.due = .dateTime(newValue)
                save()
            }
        )
    }

    /// Prossima ora piena da adesso (usata quando si passa a "Giorno e ora").
    private func nextFullHour() -> Date {
        let cal = model.calendar
        let now = model.now
        let truncated = cal.date(bySettingHour: cal.component(.hour, from: now), minute: 0, second: 0, of: now) ?? now
        return cal.date(byAdding: .hour, value: 1, to: truncated) ?? now
    }

    private func save() {
        model.updateTask(draft)
    }
}
