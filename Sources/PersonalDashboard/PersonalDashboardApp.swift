import DashboardCore
import SwiftUI

@main
struct PersonalDashboardApp: App {
    /// `--mock`: dati finti al posto di EventKit, rete e Mail (REQ-109).
    static let isMock = CommandLine.arguments.contains("--mock")

    var body: some Scene {
        Window("Personal Dashboard", id: "main") {
            Text(Self.isMock ? "Personal Dashboard (mock)" : "Personal Dashboard")
                .frame(minWidth: 1100, minHeight: 700)
        }
        .defaultSize(width: 1440, height: 900)

        Settings {
            Text("Impostazioni")
                .frame(width: 480, height: 320)
        }
    }
}
