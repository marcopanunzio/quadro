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

    /// Ora mostrata in cima alla griglia all'apertura, se non si ricorda l'ultima posizione.
    public var gridStartHour: Int = 8
    public var rememberGridScroll: Bool = true
    /// Ultima ora in cima alla griglia (frazionaria), salvata durante lo scorrimento.
    public var lastGridScrollHour: Double?

    /// Larghezza del riquadro task in punti; `nil` = un terzo della finestra.
    public var taskPaneWidth: Double?
    public var isTaskPaneCollapsed: Bool = false
    /// Altezza massima dell'area "tutto il giorno" in punti.
    public var allDayAreaHeight: Double = 64

    public init() {}

    /// Ora da cui parte la griglia all'apertura.
    public var initialGridHour: Double {
        if rememberGridScroll, let last = lastGridScrollHour { return last }
        return Double(gridStartHour)
    }

    // Decodifica tollerante: le chiavi mancanti (preferenze salvate da versioni precedenti) prendono il default.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        defaultView = try c.decodeIfPresent(CalendarViewMode.self, forKey: .defaultView) ?? d.defaultView
        firstWeekday = try c.decodeIfPresent(Int.self, forKey: .firstWeekday) ?? d.firstWeekday
        taskBlockMinutes = try c.decodeIfPresent(Int.self, forKey: .taskBlockMinutes) ?? d.taskBlockMinutes
        hiddenCalendarIDs = try c.decodeIfPresent(Set<String>.self, forKey: .hiddenCalendarIDs) ?? d.hiddenCalendarIDs
        hiddenTaskListIDs = try c.decodeIfPresent(Set<String>.self, forKey: .hiddenTaskListIDs) ?? d.hiddenTaskListIDs
        weatherFallbackPlace = try c.decodeIfPresent(Place.self, forKey: .weatherFallbackPlace)
        temperatureUnit = try c.decodeIfPresent(TemperatureUnit.self, forKey: .temperatureUnit) ?? d.temperatureUnit
        appearance = try c.decodeIfPresent(AppearancePreference.self, forKey: .appearance) ?? d.appearance
        themeID = try c.decodeIfPresent(String.self, forKey: .themeID) ?? d.themeID
        mailRefreshInterval = try c.decodeIfPresent(Int.self, forKey: .mailRefreshInterval) ?? d.mailRefreshInterval
        gridStartHour = try c.decodeIfPresent(Int.self, forKey: .gridStartHour) ?? d.gridStartHour
        rememberGridScroll = try c.decodeIfPresent(Bool.self, forKey: .rememberGridScroll) ?? d.rememberGridScroll
        lastGridScrollHour = try c.decodeIfPresent(Double.self, forKey: .lastGridScrollHour)
        taskPaneWidth = try c.decodeIfPresent(Double.self, forKey: .taskPaneWidth)
        isTaskPaneCollapsed = try c.decodeIfPresent(Bool.self, forKey: .isTaskPaneCollapsed) ?? d.isTaskPaneCollapsed
        allDayAreaHeight = try c.decodeIfPresent(Double.self, forKey: .allDayAreaHeight) ?? d.allDayAreaHeight
    }
}
