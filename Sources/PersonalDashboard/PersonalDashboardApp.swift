import AppKit
import DashboardCore
import SwiftUI

struct PersonalDashboardApp: App {
    /// `--mock`: dati finti al posto di EventKit, rete e Mail (REQ-109).
    static let isMock = CommandLine.arguments.contains("--mock") || CommandLine.arguments.contains("--snapshot")

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel

    init() {
        let settings = SettingsStore()
        let context = DateContext.live(firstWeekday: settings.settings.firstWeekday)
        let deps = Self.isMock ? Dependencies.mock(context: context) : Dependencies.live()
        let model = AppModel(deps: deps, settingsStore: settings)
        _model = State(initialValue: model)
        AppDelegate.model = model
    }

    var body: some Scene {
        Window(Self.isMock ? "Personal Dashboard (mock)" : "Personal Dashboard", id: "main") {
            RootView()
                .environment(model)
                .modifier(PaletteProvider(themeID: model.settings.themeID))
                .preferredColorScheme(model.settings.appearance.colorScheme)
                .frame(minWidth: 1100, minHeight: 700)
        }
        .defaultSize(width: 1440, height: 900)
        .commands { DashboardCommands(model: model) }

        Settings {
            SettingsView()
                .environment(model)
                .modifier(PaletteProvider(themeID: model.settings.themeID))
                .preferredColorScheme(model.settings.appearance.colorScheme)
        }
    }
}

extension AppearancePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Alla chiusura esegue l'eventuale eliminazione in sospeso prima di uscire.
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor static var model: AppModel?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            guard let model = Self.model, model.pendingDeletion != nil else { return .terminateNow }
            Task { @MainActor in
                await model.commitPendingDeletion()
                NSApp.reply(toApplicationShouldTerminate: true)
            }
            return .terminateLater
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// Scorciatoie di menu (REQ-095). Frecce, Spazio, Backspace ed Esc sono gestiti in RootView.
struct DashboardCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Nuovo task") { model.quickAddFocusRequest += 1 }
                .keyboardShortcut("n")
            Button("Nuovo evento") { model.newEventRequest += 1 }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .undoRedo) {
            Button("Annulla eliminazione") { model.undoDeletion() }
                .keyboardShortcut("z")
                .disabled(model.pendingDeletion == nil)
        }
        CommandMenu("Vista") {
            Button("Giorno") { model.viewMode = .day }.keyboardShortcut("1")
            Button("Settimana") { model.viewMode = .week }.keyboardShortcut("2")
            Button("Mese") { model.viewMode = .month }.keyboardShortcut("3")
            Divider()
            Button("Oggi") { model.goToToday() }.keyboardShortcut("t")
            Button("Periodo precedente") { model.step(-1) }.keyboardShortcut(.leftArrow)
            Button("Periodo successivo") { model.step(1) }.keyboardShortcut(.rightArrow)
            Divider()
            Button("Togli data/ora al task") {
                if let task = model.selectedTask { model.unschedule(taskID: task.id) }
            }
            .keyboardShortcut(.delete)
            .disabled(model.selectedTask == nil)
            Button("Ricarica") { Task { await model.refreshAll() } }.keyboardShortcut("r")
        }
    }
}
