import CoreLocation
import DashboardCore
import Foundation
import MapKit

/// Errori di `CoreLocationProvider`.
public enum LocationError: Error, Sendable, Equatable {
    case permissionDenied
    case timeout
    case unavailable
}

/// Custodisce le continuation in attesa: i callback del delegate arrivano fuori dal contesto async.
private actor LocationContinuations {
    private var authorization: CheckedContinuation<PermissionStatus, Never>?
    private var location: CheckedContinuation<Coordinate, Error>?

    func awaitAuthorization() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            authorization = continuation
        }
    }

    func resumeAuthorization(with status: PermissionStatus) {
        authorization?.resume(returning: status)
        authorization = nil
    }

    func awaitLocation() async throws -> Coordinate {
        try await withCheckedThrowingContinuation { continuation in
            location = continuation
        }
    }

    func resumeLocation(with result: Result<Coordinate, Error>) {
        switch result {
        case .success(let coordinate):
            location?.resume(returning: coordinate)
        case .failure(let error):
            location?.resume(throwing: error)
        }
        location = nil
    }
}

/// Riceve i callback di `CLLocationManager` e li inoltra alle continuation in attesa.
private final class LocationManagerDelegate: NSObject, CLLocationManagerDelegate, Sendable {
    let continuations: LocationContinuations

    init(continuations: LocationContinuations) {
        self.continuations = continuations
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = CoreLocationProvider.mapStatus(manager.authorizationStatus)
        Task { await continuations.resumeAuthorization(with: status) }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let coordinate = Coordinate(latitude: last.coordinate.latitude, longitude: last.coordinate.longitude)
        Task { await continuations.resumeLocation(with: .success(coordinate)) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { await continuations.resumeLocation(with: .failure(error)) }
    }
}

/// Posizione via CoreLocation, con precisione ridotta: al meteo non serve altro (REQ-102).
public final class CoreLocationProvider: LocationProvider, @unchecked Sendable {
    private let manager: CLLocationManager
    private let delegate: LocationManagerDelegate
    private let continuations = LocationContinuations()

    public init() {
        manager = CLLocationManager()
        delegate = LocationManagerDelegate(continuations: continuations)
        manager.delegate = delegate
        manager.desiredAccuracy = kCLLocationAccuracyReduced
    }

    public func authorizationStatus() -> PermissionStatus {
        Self.mapStatus(manager.authorizationStatus)
    }

    public func currentCoordinate() async throws -> Coordinate {
        try await requestAuthorizationIfNeeded()

        return try await withThrowingTaskGroup(of: Coordinate.self) { group in
            group.addTask {
                try await self.requestLocationAndAwait()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(10))
                throw LocationError.timeout
            }
            guard let first = try await group.next() else { throw LocationError.timeout }
            group.cancelAll()
            return first
        }
    }

    private func requestLocationAndAwait() async throws -> Coordinate {
        async let coordinate = continuations.awaitLocation()
        manager.requestLocation()
        return try await coordinate
    }

    public func placeName(for coordinate: Coordinate) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        guard let items = try? await request.mapItems, let first = items.first else { return nil }
        return first.name
    }

    private func requestAuthorizationIfNeeded() async throws {
        switch manager.authorizationStatus {
        case .notDetermined:
            let granted = await requestWhenInUseAndAwait()
            guard granted == .granted else { throw LocationError.permissionDenied }
        case .denied, .restricted:
            throw LocationError.permissionDenied
        default:
            break
        }
    }

    private func requestWhenInUseAndAwait() async -> PermissionStatus {
        async let status = continuations.awaitAuthorization()
        manager.requestWhenInUseAuthorization()
        return await status
    }

    fileprivate static func mapStatus(_ status: CLAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        case .authorizedAlways:
            return .granted
        @unknown default:
            return .denied
        }
    }
}
