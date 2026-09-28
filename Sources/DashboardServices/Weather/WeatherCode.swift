import DashboardCore

/// Mappa i codici WMO (`weather_code` di Open-Meteo) sulle condizioni meteo dell'app.
enum WeatherCode {
    static func condition(for code: Int) -> WeatherCondition {
        switch code {
        case 0:
            return .clear
        case 1, 2:
            return .partlyCloudy
        case 3:
            return .cloudy
        case 45, 48:
            return .fog
        case 51...57:
            return .drizzle
        case 61...67, 80...82:
            return .rain
        case 71...77, 85, 86:
            return .snow
        case 95...99:
            return .thunderstorm
        default:
            return .cloudy
        }
    }
}
