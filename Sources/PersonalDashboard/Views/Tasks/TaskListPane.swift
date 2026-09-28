import DashboardCore
import SwiftUI

/// Lista task: inserimento rapido, sezioni Scaduti/Oggi/Da pianificare (TASK-014).
struct TaskListPane: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let sections = model.sections
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                QuickAddField()

                TaskSectionView(title: "Scaduti", kind: .overdue, tasks: sections.overdue)
                TaskSectionView(title: "Oggi", kind: .today, tasks: sections.today)
                TaskSectionView(title: "Da pianificare", kind: .toPlan, tasks: sections.toPlan)

                Spacer(minLength: 12)
                unscheduleHintBox
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { moveSelection(orderedTaskIDs(sections), by: -1) }
        .onKeyPress(.downArrow) { moveSelection(orderedTaskIDs(sections), by: 1) }
    }

    private var unscheduleHintBox: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .foregroundStyle(palette.tx2)
            Text("Trascina un task sul calendario per dargli data e ora, o qui per toglierla.")
                .font(.system(size: 12))
                .foregroundStyle(palette.tx2)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(palette.ui3, style: StrokeStyle(lineWidth: 1, dash: [4]))
        )
        .unscheduleDropTarget()
    }

    /// Ordine di navigazione con le frecce: Scaduti → Oggi → Da pianificare.
    private func orderedTaskIDs(_ sections: TaskSections) -> [String] {
        (sections.overdue + sections.today + sections.toPlan).map(\.id)
    }

    private func moveSelection(_ ids: [String], by delta: Int) -> KeyPress.Result {
        guard !ids.isEmpty else { return .ignored }
        if case .task(let currentID) = model.selection, let index = ids.firstIndex(of: currentID) {
            let newIndex = min(max(index + delta, 0), ids.count - 1)
            model.selection = .task(ids[newIndex])
        } else {
            model.selection = .task(delta > 0 ? ids[0] : ids[ids.count - 1])
        }
        return .handled
    }
}

/// Le tre sezioni della lista: cambia solo colore/etichetta e, per "Da pianificare", il drop per togliere l'ora.
enum TaskSectionKind {
    case overdue
    case today
    case toPlan
}

private struct TaskSectionView: View {
    let title: String
    let kind: TaskSectionKind
    let tasks: [TaskItem]

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    private var openCount: Int { tasks.filter { !model.isDone($0) }.count }

    var body: some View {
        Group {
            if kind == .toPlan {
                content.unscheduleDropTarget()
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Rectangle().fill(palette.ui).frame(height: 1)
            if tasks.isEmpty {
                Text("Nessun task")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.tx2)
            } else {
                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        TaskRow(task: task, isOverdueSection: kind == .overdue)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(1)
                .foregroundStyle(kind == .overdue ? palette.overdue : palette.tx2)
            Spacer()
            Text("\(openCount)")
                .font(.system(size: 11, weight: .bold))
                .padding(.vertical, 1)
                .padding(.horizontal, 7)
                .background(
                    Capsule().fill(kind == .overdue ? palette.overdue.opacity(0.12) : palette.ui)
                )
                .foregroundStyle(kind == .overdue ? palette.overdue : palette.tx2)
        }
    }
}

/// Zona di drop che toglie l'ora (o l'intera data) a un task `.dateTime` trascinato sopra (REQ-055).
private struct UnscheduleDropModifier: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            .dropDestination(for: String.self) { items, _ in
                guard
                    let raw = items.first,
                    case .task(let id)? = DragPayload(raw),
                    let task = model.displayedTasks.first(where: { $0.id == id }),
                    case .dateTime = task.due
                else { return false }
                model.unschedule(taskID: id)
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 8).stroke(palette.selection, lineWidth: 2)
                }
            }
    }
}

private extension View {
    func unscheduleDropTarget() -> some View { modifier(UnscheduleDropModifier()) }
}
