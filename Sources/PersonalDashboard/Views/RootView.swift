import DashboardCore
import SwiftUI

/// Finestra principale (REQ-050): barra in alto, calendario ~2/3 a sinistra, lista task ~1/3 a destra.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        Group {
            if model.calendarAccess == .granted || model.remindersAccess == .granted {
                dashboard
            } else {
                PermissionsView()
            }
        }
        .background(palette.bg)
        .foregroundStyle(palette.tx)
        .overlay(alignment: .bottom) {
            if let pending = model.pendingDeletion {
                UndoToast(title: pending.title)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: model.pendingDeletion?.id)
        .alert("Errore", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .task { await model.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refreshPermissions() }
            } else {
                Task { await model.commitPendingDeletion() }
            }
        }
    }

    private var dashboard: some View {
        VStack(spacing: 0) {
            HeaderBar()
            Divider().overlay(palette.ui)
            GeometryReader { geo in
                HStack(spacing: 0) {
                    CalendarPane()
                        .frame(width: geo.size.width * 2 / 3)
                    Divider().overlay(palette.ui)
                    TaskListPane()
                        .frame(maxWidth: .infinity)
                        .background(palette.bg2)
                }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.space) { completeSelectedTask() }
        .onKeyPress(.delete) { deleteSelection() }
        .onKeyPress(.leftArrow) { model.step(-1); return .handled }
        .onKeyPress(.rightArrow) { model.step(1); return .handled }
        .onKeyPress(.escape) {
            guard model.selection != nil else { return .ignored }
            model.selection = nil
            return .handled
        }
    }

    private func completeSelectedTask() -> KeyPress.Result {
        guard let task = model.selectedTask else { return .ignored }
        model.toggleCompleted(task)
        return .handled
    }

    /// Backspace elimina con Annulla (REQ-092). Per i ricorrenti la scelta della portata sta nel popover.
    private func deleteSelection() -> KeyPress.Result {
        if let task = model.selectedTask {
            model.delete(task)
            return .handled
        }
        if let event = model.selectedEvent, event.isWritable, !event.isRecurring {
            model.delete(event)
            return .handled
        }
        return .ignored
    }
}
