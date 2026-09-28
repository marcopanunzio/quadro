import AppKit
import DashboardCore
import SwiftUI

@main
enum Entry {
    static func main() {
        if CommandLine.arguments.contains("--snapshot") {
            SnapshotRunner.run()
        } else {
            QuadroApp.main()
        }
    }
}

/// `--snapshot <file.png> [--view day|week|month] [--dark] [--select-event <titolo>] [--select-task <titolo>]`:
/// disegna la finestra con i dati mock in un PNG ed esce. Niente finestre e niente permessi:
/// serve a controllare l'aspetto da riga di comando.
@MainActor
enum SnapshotRunner {
    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        Task { @MainActor in
            await render()
            exit(0)
        }
        app.run()
    }

    private static func argument(after flag: String) -> String? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    private static func render() async {
        let output = argument(after: "--snapshot") ?? "snapshot.png"
        let isDark = CommandLine.arguments.contains("--dark")
        let suite = "quadro.snapshot"
        UserDefaults().removePersistentDomain(forName: suite)
        let settings = SettingsStore(defaults: UserDefaults(suiteName: suite)!)
        if let view = argument(after: "--view").flatMap(CalendarViewMode.init(rawValue:)) {
            settings.settings.defaultView = view
        }
        let context = DateContext.live(firstWeekday: settings.settings.firstWeekday)
        let model = AppModel(deps: .mock(context: context), settingsStore: settings)
        await model.start()
        await model.refreshWeather()
        await model.refreshMail()
        if let title = argument(after: "--select-event"), let event = model.displayedEvents.first(where: { $0.title == title }) {
            model.selection = .event(event.id)
        }
        if let title = argument(after: "--select-task"), let task = model.displayedTasks.first(where: { $0.title == title }) {
            model.selection = .task(task.id)
        }

        let content = RootView()
            .environment(model)
            .environment(\.palette, Palette(theme: ThemeRegistry.theme(id: model.settings.themeID), isDark: isDark))
            .environment(\.colorScheme, isDark ? .dark : .light)
            .environment(\.isSnapshot, true)
            .frame(width: 1440, height: 900)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("snapshot fallito\n".utf8))
            return
        }
        try? png.write(to: URL(fileURLWithPath: output))
        print(output)
    }
}
