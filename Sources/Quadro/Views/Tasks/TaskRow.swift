import DashboardCore
import SwiftUI

/// Riga di un task nella lista (TASK-014).
struct TaskRow: View {
    let task: TaskItem
    /// Nella sezione Scaduti la scadenza si mostra in `palette.overdue` e senza "senza ora".
    let isOverdueSection: Bool

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    private var isDone: Bool { model.isDone(task) }
    private var isSelected: Bool { model.selection == .task(task.id) }

    var body: some View {
        // Il pallino resta fuori dall'area con tap e drag: su macOS `.draggable` si prende il clic dei bottoni che contiene.
        HStack(spacing: 10) {
            completionButton
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    titleText
                    metaLine
                }
                Spacer(minLength: 4)
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.tx3)
            }
            .contentShape(Rectangle())
            .onTapGesture { model.selection = .task(task.id) }
            .draggable(DragPayload.task(id: task.id).string) {
                Text(task.title)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.tx)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(palette.bg))
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? palette.ui : Color.clear)
        )
        .popover(
            isPresented: Binding(
                get: { model.selection == .task(task.id) },
                set: { if !$0 { model.selection = nil } }
            ),
            arrowEdge: .leading
        ) {
            TaskDetailView(task: task)
        }
        .contextMenu {
            Button(isDone ? "Riapri" : "Completa") { model.toggleCompleted(task) }
            if task.due != nil {
                Button("Togli data/ora") { model.unschedule(taskID: task.id) }
            }
            Button("Elimina", role: .destructive) { model.delete(task) }
        }
    }

    private var completionButton: some View {
        Button {
            model.toggleCompleted(task)
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(palette.accent(model.accent(forCalendar: task.listID)), lineWidth: 1.5)
                    .background(Circle().fill(isDone ? palette.accent(model.accent(forCalendar: task.listID)) : Color.clear))
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(palette.bg)
                }
            }
            .frame(width: 18, height: 18)
            .padding(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isDone ? "Riapri \(task.title)" : "Completa \(task.title)")
    }

    private var titleText: some View {
        Text("\(highPriorityPrefix)\(task.title)")
            .font(.system(size: 13))
            .foregroundStyle(isDone ? palette.tx2 : palette.tx)
            .strikethrough(isDone, color: palette.tx2)
    }

    private var highPriorityPrefix: Text {
        guard task.priority == .high else { return Text("") }
        return Text("!! ").fontWeight(.bold).foregroundStyle(palette.overdue)
    }

    private var metaLine: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isDone ? palette.tx3 : palette.accent(model.accent(forCalendar: task.listID)))
                .frame(width: 6, height: 6)
            Text("\(listTitle) · \(Text(dueString).foregroundStyle(dueColor))")
                .font(.system(size: 11))
                .foregroundStyle(palette.tx2)
        }
    }

    private var listTitle: String { model.taskList(task.listID)?.title ?? "" }
    private var dueString: String { DueText.string(for: task.due, context: model.context) }
    private var dueColor: Color { isOverdueSection ? palette.overdue : palette.tx2 }
}
