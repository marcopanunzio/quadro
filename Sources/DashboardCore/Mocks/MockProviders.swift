import Foundation

public struct MockLocationProvider: LocationProvider {
    public init() {}

    public func authorizationStatus() -> PermissionStatus {
        .granted
    }

    public func currentCoordinate() async throws -> Coordinate {
        Coordinate(latitude: 41.9028, longitude: 12.4964)
    }

    public func placeName(for coordinate: Coordinate) async -> String? {
        "Roma"
    }
}

public struct MockWeatherProvider: WeatherProvider {
    private static let cities = [
        Place(name: "Roma", detail: "Lazio", coordinate: Coordinate(latitude: 41.9028, longitude: 12.4964)),
        Place(name: "Milano", detail: "Lombardia", coordinate: Coordinate(latitude: 45.4642, longitude: 9.1900)),
        Place(name: "Napoli", detail: "Campania", coordinate: Coordinate(latitude: 40.8518, longitude: 14.2681)),
        Place(name: "Torino", detail: "Piemonte", coordinate: Coordinate(latitude: 45.0703, longitude: 7.6869)),
        Place(name: "Firenze", detail: "Toscana", coordinate: Coordinate(latitude: 43.7696, longitude: 11.2558)),
        Place(name: "Venezia", detail: "Veneto", coordinate: Coordinate(latitude: 45.4408, longitude: 12.3155)),
        Place(name: "Palermo", detail: "Sicilia", coordinate: Coordinate(latitude: 38.1157, longitude: 13.3615)),
        Place(name: "Genova", detail: "Liguria", coordinate: Coordinate(latitude: 44.4056, longitude: 8.9463)),
    ]

    public init() {}

    public func weather(at coordinate: Coordinate, unit: TemperatureUnit) async throws -> WeatherSnapshot {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)

        let dailyForecasts = (0..<7).map { dayOffset -> DailyForecast in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: now)!
            let dayDate = DayDate(date, calendar: calendar)

            let conditions: [WeatherCondition] = [.clear, .partlyCloudy, .cloudy, .rain, .drizzle]
            let condition = conditions[dayOffset % conditions.count]
            let high = 20.0 - Double(dayOffset)
            let low = 12.0 - Double(dayOffset)

            return DailyForecast(day: dayDate, condition: condition, high: high, low: low)
        }

        return WeatherSnapshot(
            placeName: "Roma",
            temperature: 18.0,
            condition: .partlyCloudy,
            isDaylight: true,
            daily: dailyForecasts,
            fetchedAt: now
        )
    }

    public func searchPlaces(named query: String) async throws -> [Place] {
        let lowerQuery = query.lowercased()
        return Self.cities.filter { $0.name.lowercased().hasPrefix(lowerQuery) }
    }
}

public struct MockMailProvider: MailProvider {
    public init() {}

    public func unreadSummary() async throws -> MailSummary? {
        let accounts = [
            MailAccountUnread(accountName: "iCloud", unreadCount: 4),
            MailAccountUnread(accountName: "Gmail", unreadCount: 7),
            MailAccountUnread(accountName: "Lavoro", unreadCount: 1),
        ]
        return MailSummary(accounts: accounts, fetchedAt: Date())
    }
}
