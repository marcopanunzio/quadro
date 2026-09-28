import DashboardCore
import Foundation

/// Errori del client Open-Meteo.
public enum WeatherError: Error, Sendable, Equatable {
    /// La risposta non è un HTTP response valida.
    case invalidResponse
    /// Status HTTP diverso da 200.
    case httpStatus(Int)
    /// JSON non decodificabile.
    case decoding(String)
}

/// Client per le API pubbliche Open-Meteo (previsioni e geocoding). Nessuna chiave API richiesta.
public struct OpenMeteoClient: WeatherProvider {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func weather(at coordinate: Coordinate, unit: TemperatureUnit) async throws -> WeatherSnapshot {
        let url = try Self.forecastURL(for: coordinate, unit: unit)
        let (data, response) = try await session.data(from: url)
        try Self.checkHTTPStatus(response)
        return try Self.decodeSnapshot(from: data, fetchedAt: Date())
    }

    public func searchPlaces(named query: String) async throws -> [Place] {
        let url = try Self.geocodingURL(for: query)
        let (data, response) = try await session.data(from: url)
        try Self.checkHTTPStatus(response)
        return try Self.decodePlaces(from: data)
    }

    // MARK: - Costruzione URL (testabile)

    static func forecastURL(for coordinate: Coordinate, unit: TemperatureUnit) throws -> URL {
        let rounded = coordinate.rounded
        guard var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast") else {
            throw WeatherError.invalidResponse
        }
        var items = [
            URLQueryItem(name: "latitude", value: Self.formatted(rounded.latitude)),
            URLQueryItem(name: "longitude", value: Self.formatted(rounded.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "7"),
        ]
        if unit == .fahrenheit {
            items.append(URLQueryItem(name: "temperature_unit", value: "fahrenheit"))
        }
        components.queryItems = items
        guard let url = components.url else { throw WeatherError.invalidResponse }
        return url
    }

    static func geocodingURL(for query: String) throws -> URL {
        guard var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search") else {
            throw WeatherError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "5"),
            URLQueryItem(name: "language", value: "it"),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components.url else { throw WeatherError.invalidResponse }
        return url
    }

    private static func formatted(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func checkHTTPStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw WeatherError.invalidResponse }
        guard http.statusCode == 200 else { throw WeatherError.httpStatus(http.statusCode) }
    }

    // MARK: - Decodifica (testabile)

    private struct ForecastResponse: Decodable {
        struct Current: Decodable {
            let temperature2m: Double
            let weatherCode: Int
            let isDay: Int

            enum CodingKeys: String, CodingKey {
                case temperature2m = "temperature_2m"
                case weatherCode = "weather_code"
                case isDay = "is_day"
            }
        }

        struct Daily: Decodable {
            let time: [String]
            let weatherCode: [Int]
            let temperatureMax: [Double]
            let temperatureMin: [Double]

            enum CodingKeys: String, CodingKey {
                case time
                case weatherCode = "weather_code"
                case temperatureMax = "temperature_2m_max"
                case temperatureMin = "temperature_2m_min"
            }
        }

        let current: Current
        let daily: Daily
    }

    private struct GeocodingResponse: Decodable {
        struct Result: Decodable {
            let name: String
            let latitude: Double
            let longitude: Double
            let admin1: String?
            let country: String?
        }

        let results: [Result]?
    }

    static func decodeSnapshot(from data: Data, fetchedAt: Date) throws -> WeatherSnapshot {
        let raw: ForecastResponse
        do {
            raw = try JSONDecoder().decode(ForecastResponse.self, from: data)
        } catch {
            throw WeatherError.decoding(String(describing: error))
        }

        let count = min(
            raw.daily.time.count,
            raw.daily.weatherCode.count,
            raw.daily.temperatureMax.count,
            raw.daily.temperatureMin.count
        )
        var daily: [DailyForecast] = []
        daily.reserveCapacity(count)
        for i in 0..<count {
            guard let day = Self.dayDate(from: raw.daily.time[i]) else {
                throw WeatherError.decoding("data giorno non valida: \(raw.daily.time[i])")
            }
            daily.append(DailyForecast(
                day: day,
                condition: WeatherCode.condition(for: raw.daily.weatherCode[i]),
                high: raw.daily.temperatureMax[i],
                low: raw.daily.temperatureMin[i]
            ))
        }

        return WeatherSnapshot(
            placeName: nil,
            temperature: raw.current.temperature2m,
            condition: WeatherCode.condition(for: raw.current.weatherCode),
            isDaylight: raw.current.isDay != 0,
            daily: daily,
            fetchedAt: fetchedAt
        )
    }

    static func decodePlaces(from data: Data) throws -> [Place] {
        let raw: GeocodingResponse
        do {
            raw = try JSONDecoder().decode(GeocodingResponse.self, from: data)
        } catch {
            throw WeatherError.decoding(String(describing: error))
        }
        return (raw.results ?? []).map { result in
            let detail = [result.admin1, result.country].compactMap { $0 }.joined(separator: ", ")
            return Place(
                name: result.name,
                detail: detail.isEmpty ? nil : detail,
                coordinate: Coordinate(latitude: result.latitude, longitude: result.longitude)
            )
        }
    }

    /// Campo `time` "yyyy-MM-dd" del daily forecast.
    private static func dayDate(from string: String) -> DayDate? {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else { return nil }
        return DayDate(year: year, month: month, day: day)
    }
}
