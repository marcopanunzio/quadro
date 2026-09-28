import DashboardCore
import Foundation
import Observation

/// Preferenze persistite in UserDefaults come JSON (REQ-072, REQ-080..086).
@MainActor
@Observable
final class SettingsStore {
    private static let key = "settings.v1"
    private let defaults: UserDefaults

    var settings: AppSettings {
        didSet { save() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Prima installazione di Quadro: si recuperano le preferenze salvate quando l'app si chiamava Personal Dashboard.
        let legacy = defaults == .standard ? UserDefaults(suiteName: "com.mpanunzio.PersonalDashboard")?.data(forKey: Self.key) : nil
        if let data = defaults.data(forKey: Self.key) ?? legacy,
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
            if defaults.data(forKey: Self.key) == nil { save() }
        } else {
            settings = AppSettings()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
