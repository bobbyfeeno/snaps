import Foundation
import CoreLocation

// MARK: - LocationManager

@MainActor
final class LocationManager: NSObject, ObservableObject {

    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var cityName: String?
    @Published var locationError: Bool = false

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var hasFetched = false
    private var delegate: LocationDelegate?

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = manager.authorizationStatus

        let del = LocationDelegate()
        del.onLocations = { [weak self] locations in
            Task { @MainActor in
                guard let self, let loc = locations.first else { return }
                self.location = loc
                self.reverseGeocode(loc)
            }
        }
        del.onError = { [weak self] _ in
            Task { @MainActor in
                self?.locationError = true
            }
        }
        del.onAuthChange = { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                self.authorizationStatus = status
                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    if !self.hasFetched {
                        self.hasFetched = true
                        self.manager.requestLocation()
                    }
                case .denied, .restricted:
                    self.locationError = true
                default:
                    break
                }
            }
        }
        self.delegate = del
        manager.delegate = del
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            if !hasFetched {
                hasFetched = true
                manager.requestLocation()
            }
        default:
            locationError = true
        }
    }

    // MARK: - Reverse Geocode

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            Task { @MainActor in
                guard let self else { return }
                if let city = placemarks?.first?.locality {
                    self.cityName = city
                } else if let area = placemarks?.first?.administrativeArea {
                    self.cityName = area
                } else {
                    self.locationError = true
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate (non-isolated)

private class LocationDelegate: NSObject, CLLocationManagerDelegate {
    var onLocations: (([CLLocation]) -> Void)?
    var onError: ((Error) -> Void)?
    var onAuthChange: ((CLAuthorizationStatus) -> Void)?

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        onLocations?(locations)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onError?(error)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthChange?(manager.authorizationStatus)
    }
}
