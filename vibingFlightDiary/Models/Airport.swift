import Foundation
import CoreLocation

struct Airport: Codable, Identifiable, Hashable {
    let iata: String
    let name: String
    let city: String
    let country: String
    let lat: Double
    let lon: Double

    var id: String { iata }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var displayName: String { "\(iata) – \(city), \(country)" }
}
