import Foundation

public enum CalendarViewMode: String, Codable, Sendable, CaseIterable {
    case day
    case week
    case month
}

public enum AppearancePreference: String, Codable, Sendable, CaseIterable {
    case system
    case light
    case dark
}

public enum TemperatureUnit: String, Codable, Sendable, CaseIterable {
    case celsius
    case fahrenheit
}

/// Preferenze dell'app (REQ-080..086). Unico stato salvato dall'app (REQ-072).
public struct AppSettings: Codable, Hashable, Sendable {
    public var defaultView: CalendarViewMode = .week
    /// Convenzione di `Calendar.firstWeekday`: 1 = domenica, 2 = lunedì.
    public var firstWeekday: Int = 2
    public var taskBlockMinutes: Int = 30
    public var hiddenCalendarIDs: Set<String> = []
    public var hiddenTaskListIDs: Set<String> = []
    public var weatherFallbackPlace: Place?
    public var temperatureUnit: TemperatureUnit = .celsius
    public var appearance: AppearancePreference = .system
    public var themeID: String = "flexoki"
    /// Intervallo di aggiornamento delle mail non lette, in secondi.
    public var mailRefreshInterval: Int = 180

    public init() {}
}
