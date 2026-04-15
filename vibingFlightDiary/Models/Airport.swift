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

    /// Converts ISO-2 country code to emoji flag (e.g. "PL" → "🇵🇱")
    var flagEmoji: String {
        country.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(127397 + $0.value) }
            .reduce("") { $0 + String($1) }
    }
}
