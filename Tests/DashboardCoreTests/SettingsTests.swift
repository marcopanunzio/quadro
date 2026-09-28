import DashboardCore
import Foundation
import Testing

@Suite struct SettingsTests {
    @Test func decodesOldSettingsWithDefaults() throws {
        let old = #"{"defaultView":"month","firstWeekday":1,"themeID":"flexoki"}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(old.utf8))
        #expect(settings.defaultView == .month)
        #expect(settings.firstWeekday == 1)
        #expect(settings.gridStartHour == 8)
        #expect(settings.rememberGridScroll)
        #expect(settings.allDayAreaHeight == 64)
        #expect(settings.taskPaneWidth == nil)
    }

    @Test func roundTrips() throws {
        var settings = AppSettings()
        settings.lastGridScrollHour = 9.5
        settings.isTaskPaneCollapsed = true
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }

    @Test func initialGridHour() {
        var settings = AppSettings()
        #expect(settings.initialGridHour == 8)
        settings.lastGridScrollHour = 10.25
        #expect(settings.initialGridHour == 10.25)
        settings.rememberGridScroll = false
        #expect(settings.initialGridHour == 8)
    }
}
