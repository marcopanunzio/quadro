import DashboardCore
import SwiftUI

/// Popover di dettaglio di un evento (TASK-015). Salvataggio subito per i non ricorrenti (REQ-070);
/// per i ricorrenti le modifiche si accumulano finché non si sceglie la portata con "Salva…".
struct EventDetailView: View {
    let event: CalendarEvent

    @Environment(\.palette) private var palette
    @Environment(AppModel.self) private var model

    @State private var draft: CalendarEvent
    @State private var lastValidDuration: TimeInterval
    @State private var hasPendingChanges = false
    @State private var showSaveSpanDialog = false
    @State private var showDeleteDialog = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case title, location, notes }

    init(event: CalendarEvent) {
        self.event = event
        _draft = State(initialValue: event)
        _lastValidDuration = State(initialValue: max(event.end.timeIntervalSince(event.start), 60))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if !event.isWritable {
                Label("Sola lettura", systemImage: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.tx2)
            }
            if draft.needsOrganizerWarning {
                organizerWarning
            }

            VStack(spacing: 0) {
                DetailRow("Quando") { whenControls }
                DetailDivider()
                DetailRow("Tutto il giorno") {
                    Toggle("", isOn: allDayBinding).labelsHidden()
                }
                DetailDivider()
                DetailRow("Calendario") { calendarControl }
                DetailDivider()
                DetailRow("Luogo") {
                    TextField("Aggiungi luogo", text: locationBinding)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .location)
                        .onSubmit { save() }
                }
                if draft.isRecurring {
                    DetailDivider()
                    DetailRow("Ripetizione") {
                        Text("Evento ricorrente")
                            .font(.system(size: 13))
                            .foregroundStyle(palette.tx)
                    }
                }
                DetailDivider()
                DetailRow("Note") {
                    TextField("Aggiungi note", text: notesBinding, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .focused($focusedField, equals: .notes)
                        .onSubmit { save() }
                }
            }
            .disabled(!event.isWritable)

            footer
        }
        .padding(16)
        .frame(width: 320)
        .onChange(of: focusedField) { oldValue, _ in
            if oldValue != nil { save() }
        }
        .onChange(of: event) { _, newValue in
            guard focusedField == nil, !hasPendingChanges else { return }
            draft = newValue
            lastValidDuration = max(newValue.end.timeIntervalSince(newValue.start), 60)
        }
        .confirmationDialog("Evento ricorrente", isPresented: $showSaveSpanDialog) {
            Button("Solo questo evento") { commitRecurring(span: .thisOccurrence) }
            Button("Questo e i futuri") { commitRecurring(span: .futureOccurrences) }
            Button("Annulla", role: .cancel) {}
        }
        .confirmationDialog("Elimina evento ricorrente", isPresented: $showDeleteDialog) {
            Button("Elimina solo questo", role: .destructive) { model.delete(draft, span: .thisOccurrence) }
            Button("Elimina questo e i futuri", role: .destructive) { model.delete(draft, span: .futureOccurrences) }
            Button("Annulla", role: .cancel) {}
        }
    }

    // MARK: Sezioni

    private var header: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(palette.accent(model.accent(forCalendar: draft.calendarID)))
                .frame(width: 10, height: 10)
            TextField("Titolo", text: $draft.title)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .bold))
                .focused($focusedField, equals: .title)
                .onSubmit { save() }
                .disabled(!event.isWritable)
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

    private var organizerWarning: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(palette.accent(.yellow))
            Text("Invito organizzato da altri: se lo sposti o lo modifichi cambia solo la tua copia e l'organizzatore non viene avvisato.")
                .font(.system(size: 12))
                .foregroundStyle(palette.tx)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(palette.accent(.yellow).opacity(0.12))
        )
    }

    @ViewBuilder
    private var whenControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            DatePicker("", selection: startBinding, displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute])
                .labelsHidden()
            DatePicker("", selection: endBinding, displayedComponents: draft.isAllDay ? [.date] : [.hourAndMinute])
                .labelsHidden()
        }
    }

    @ViewBuilder
    private var calendarControl: some View {
        if event.isWritable {
            Picker("", selection: calendarBinding) {
                ForEach(model.calendars.filter(\.isWritable)) { calendar in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(palette.accent(model.accent(forCalendar: calendar.id)))
                            .frame(width: 8, height: 8)
                        Text(calendar.title)
                    }
                    .tag(calendar.id)
                }
            }
            .labelsHidden()
        } else {
            Text(model.calendarInfo(draft.calendarID)?.title ?? "")
                .font(.system(size: 13))
                .foregroundStyle(palette.tx)
        }
    }

    private var footer: some View {
        HStack {
            if draft.isRecurring && hasPendingChanges {
                Button("Salva…") { showSaveSpanDialog = true }
            }
            Spacer()
            if event.isWritable {
                Button("Elimina") {
                    if draft.isRecurring {
                        showDeleteDialog = true
                    } else {
                        model.delete(draft)
                    }
                }
                .buttonStyle(.bordered)
                .foregroundStyle(palette.overdue)
            }
        }
    }

    // MARK: Binding e logica di salvataggio

    private var allDayBinding: Binding<Bool> {
        Binding(
            get: { draft.isAllDay },
            set: { newValue in
                draft.isAllDay = newValue
                save()
            }
        )
    }

    private var locationBinding: Binding<String> {
        Binding(
            get: { draft.location ?? "" },
            set: { draft.location = $0.isEmpty ? nil : $0 }
        )
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { draft.notes ?? "" },
            set: { draft.notes = $0.isEmpty ? nil : $0 }
        )
    }

    private var calendarBinding: Binding<String> {
        Binding(
            get: { draft.calendarID },
            set: { newValue in
                draft.calendarID = newValue
                save()
            }
        )
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: { draft.start },
            set: { newStart in
                if draft.end <= newStart {
                    draft.start = newStart
                    draft.end = newStart.addingTimeInterval(lastValidDuration)
                } else {
                    draft.start = newStart
                    lastValidDuration = draft.end.timeIntervalSince(newStart)
                }
                save()
            }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { draft.end },
            set: { newValue in
                let candidate = mergingTime(of: newValue, ontoDayOf: draft.end)
                if candidate <= draft.start {
                    draft.end = draft.start.addingTimeInterval(lastValidDuration)
                } else {
                    draft.end = candidate
                    lastValidDuration = draft.end.timeIntervalSince(draft.start)
                }
                save()
            }
        )
    }

    /// Il DatePicker di fine mostra solo l'ora: si applica l'ora scelta al giorno esistente.
    private func mergingTime(of newValue: Date, ontoDayOf reference: Date) -> Date {
        let cal = model.calendar
        var comps = cal.dateComponents([.year, .month, .day], from: reference)
        let time = cal.dateComponents([.hour, .minute, .second], from: newValue)
        comps.hour = time.hour
        comps.minute = time.minute
        comps.second = time.second
        return cal.date(from: comps) ?? newValue
    }

    private func save() {
        guard event.isWritable else { return }
        if draft.isRecurring {
            hasPendingChanges = true
        } else {
            model.updateEvent(draft)
        }
    }

    private func commitRecurring(span: EditSpan) {
        model.updateEvent(draft, span: span)
        hasPendingChanges = false
    }
}
