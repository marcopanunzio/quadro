import DashboardCore
import Foundation
import Testing
@testable import DashboardServices

@Suite struct OpenMeteoTests {

    // MARK: - Costruzione URL

    @Test func forecastURLRoundsCoordinatesAndSetsParameters() throws {
        let coordinate = Coordinate(latitude: 45.0731, longitude: 7.6869)
        let url = try OpenMeteoClient.forecastURL(for: coordinate, unit: .celsius)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        #expect(components.scheme == "https")
        #expect(components.host == "api.open-meteo.com")
        #expect(components.path == "/v1/forecast")
        #expect(items["latitude"] == "45.07")
        #expect(items["longitude"] == "7.69")
        #expect(items["current"] == "temperature_2m,weather_code,is_day")
        #expect(items["daily"] == "weather_code,temperature_2m_max,temperature_2m_min")
        #expect(items["timezone"] == "auto")
        #expect(items["forecast_days"] == "7")
        #expect(items["temperature_unit"] == nil)
    }

    @Test func forecastURLIncludesFahrenheitOnlyWhenRequested() throws {
        let coordinate = Coordinate(latitude: 40.0, longitude: -74.0)
        let url = try OpenMeteoClient.forecastURL(for: coordinate, unit: .fahrenheit)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        #expect(items["temperature_unit"] == "fahrenheit")
        #expect(items["latitude"] == "40.00")
        #expect(items["longitude"] == "-74.00")
    }

    @Test func geocodingURLSetsParameters() throws {
        let url = try OpenMeteoClient.geocodingURL(for: "Torino")
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        #expect(components.host == "geocoding-api.open-meteo.com")
        #expect(components.path == "/v1/search")
        #expect(items["name"] == "Torino")
        #expect(items["count"] == "5")
        #expect(items["language"] == "it")
        #expect(items["format"] == "json")
    }

    // MARK: - Decodifica previsioni

    @Test func decodesRealisticForecast() throws {
        let json = """
        {
          "latitude": 45.07,
          "longitude": 7.69,
          "timezone": "Europe/Rome",
          "current": {
            "time": "2026-09-28T10:00",
            "temperature_2m": 21.4,
            "weather_code": 2,
            "is_day": 1
          },
          "daily": {
            "time": ["2026-09-28", "2026-09-29", "2026-09-30"],
            "weather_code": [2, 61, 95],
            "temperature_2m_max": [24.1, 19.5, 18.0],
            "temperature_2m_min": [14.2, 13.1, 12.4]
          }
        }
        """.data(using: .utf8)!

        let fetchedAt = Date(timeIntervalSince1970: 1_000_000)
        let snapshot = try OpenMeteoClient.decodeSnapshot(from: json, fetchedAt: fetchedAt)

        #expect(snapshot.placeName == nil)
        #expect(snapshot.temperature == 21.4)
        #expect(snapshot.condition == .partlyCloudy)
        #expect(snapshot.isDaylight == true)
        #expect(snapshot.fetchedAt == fetchedAt)
        #expect(snapshot.daily.count == 3)
        #expect(snapshot.daily[0].day == DayDate(year: 2026, month: 9, day: 28))
        #expect(snapshot.daily[0].condition == .partlyCloudy)
        #expect(snapshot.daily[0].high == 24.1)
        #expect(snapshot.daily[0].low == 14.2)
        #expect(snapshot.daily[1].day == DayDate(year: 2026, month: 9, day: 29))
        #expect(snapshot.daily[1].condition == .rain)
        #expect(snapshot.daily[2].condition == .thunderstorm)
    }

    @Test func invalidJSONThrowsDecodingError() {
        let data = Data("not json".utf8)
        #expect(throws: WeatherError.self) {
            _ = try OpenMeteoClient.decodeSnapshot(from: data, fetchedAt: Date())
        }
    }

    // MARK: - Decodifica geocoding

    @Test func decodesGeocodingResultsWithDetail() throws {
        let json = """
        {
          "results": [
            {"name": "Torino", "latitude": 45.07, "longitude": 7.69, "admin1": "Piemonte", "country": "Italy"},
            {"name": "Milano", "latitude": 45.46, "longitude": 9.19, "country": "Italy"},
            {"name": "Atlantis", "latitude": 0.0, "longitude": 0.0}
          ]
        }
        """.data(using: .utf8)!

        let places = try OpenMeteoClient.decodePlaces(from: json)

        #expect(places.count == 3)
        #expect(places[0].name == "Torino")
        #expect(places[0].detail == "Piemonte, Italy")
        #expect(places[1].detail == "Italy")
        #expect(places[2].detail == nil)
        #expect(places[2].coordinate == Coordinate(latitude: 0.0, longitude: 0.0))
    }

    @Test func decodesGeocodingWithoutResultsFieldAsEmpty() throws {
        let json = """
        { "generationtime_ms": 0.1 }
        """.data(using: .utf8)!

        let places = try OpenMeteoClient.decodePlaces(from: json)
        #expect(places.isEmpty)
    }

    // MARK: - Codici WMO

    @Test func weatherCodeMapping() {
        let expectations: [(Int, WeatherCondition)] = [
            (0, .clear),
            (1, .partlyCloudy), (2, .partlyCloudy),
            (3, .cloudy),
            (45, .fog), (48, .fog),
            (51, .drizzle), (55, .drizzle), (57, .drizzle),
            (61, .rain), (65, .rain), (67, .rain), (80, .rain), (81, .rain), (82, .rain),
            (71, .snow), (75, .snow), (77, .snow), (85, .snow), (86, .snow),
            (95, .thunderstorm), (96, .thunderstorm), (99, .thunderstorm),
            (17, .cloudy), (100, .cloudy), (-1, .cloudy),
        ]
        for (code, expected) in expectations {
            #expect(WeatherCode.condition(for: code) == expected)
        }
    }
}
