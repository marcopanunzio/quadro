import DashboardCore
import DashboardServices
import Foundation

/// Servizi usati dall'app: reali o mock (`--mock`, REQ-109).
struct Dependencies {
    var planner: any PlannerStore
    var location: any LocationProvider
    var weather: any WeatherProvider
    var mail: any MailProvider

    static func live() -> Dependencies {
        Dependencies(
            planner: EventKitPlannerStore(),
            location: CoreLocationProvider(),
            weather: OpenMeteoClient(),
            mail: AppleScriptMailProvider()
        )
    }

    static func mock(context: DateContext) -> Dependencies {
        Dependencies(
            planner: MockPlannerStore(context: context),
            location: MockLocationProvider(),
            weather: MockWeatherProvider(),
            mail: MockMailProvider()
        )
    }
}
