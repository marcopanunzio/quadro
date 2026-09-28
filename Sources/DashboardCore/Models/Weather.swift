import Foundation

public struct Coordinate: Hashable, Codable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Coordinate arrotondate a 2 decimali (~1 km) prima di uscire in rete (REQ-102).
    public var rounded: Coordinate {
        Coordinate(latitude: (latitude * 100).rounded() / 100, longitude: (longitude * 100).rounded() / 100)
    }
}

public struct Place: Hashable, Codable, Sendable {
    public var name: String
    /// Regione/paese, per distinguere omonimi.
    public var detail: String?
    public var coordinate: Coordinate

    public init(name: String, detail: String? = nil, coordinate: Coordinate) {
        self.name = name
        self.detail = detail
        self.coordinate = coordinate
    }
}

public enum WeatherCondition: String, Hashable, Sendable, CaseIterable {
    case clear
    case partlyCloudy
    case cloudy
    case fog
    case drizzle
    case rain
    case snow
    case thunderstorm
}

public struct DailyForecast: Hashable, Sendable {
    public var day: DayDate
    public var condition: WeatherCondition
    public var high: Double
    public var low: Double

    public init(day: DayDate, condition: WeatherCondition, high: Double, low: Double) {
        self.day = day
        self.condition = condition
        self.high = high
        self.low = low
    }
}

public struct WeatherSnapshot: Hashable, Sendable {
    public var placeName: String?
    public var temperature: Double
    public var condition: WeatherCondition
    public var isDaylight: Bool
    /// Primo elemento = oggi.
    public var daily: [DailyForecast]
    public var fetchedAt: Date

    public init(placeName: String?, temperature: Double, condition: WeatherCondition, isDaylight: Bool, daily: [DailyForecast], fetchedAt: Date) {
        self.placeName = placeName
        self.temperature = temperature
        self.condition = condition
        self.isDaylight = isDaylight
        self.daily = daily
        self.fetchedAt = fetchedAt
    }
}
