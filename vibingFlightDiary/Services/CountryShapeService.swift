import Foundation
import CoreLocation

/// Loads and caches country boundary polygons from the bundled countries.geojson.
/// Each country may have multiple polygon rings (islands, exclaves, etc.).
struct CountryShapeService {

    static let shared = CountryShapeService()

    /// [ISO-A2 code: array of polygon rings (each ring = array of coordinates)]
    let shapes: [String: [[CLLocationCoordinate2D]]]

    private init() {
        shapes = Self.load()
    }

    func polygons(for iso: String) -> [[CLLocationCoordinate2D]] {
        shapes[iso] ?? []
    }

    // MARK: - Parsing

    private static func load() -> [String: [[CLLocationCoordinate2D]]] {
        guard
            let url  = Bundle.main.url(forResource: "countries", withExtension: "geojson"),
            let data = try? Data(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let features = json["features"] as? [[String: Any]]
        else { return [:] }

        var result: [String: [[CLLocationCoordinate2D]]] = [:]

        for feature in features {
            guard
                let props    = feature["properties"] as? [String: Any],
                let iso      = props["iso"] as? String, !iso.isEmpty,
                let geometry = feature["geometry"] as? [String: Any],
                let geoType  = geometry["type"] as? String
            else { continue }

            var rings: [[CLLocationCoordinate2D]] = []

            switch geoType {
            case "Polygon":
                if let coords = geometry["coordinates"] as? [[[Double]]],
                   let outer = coords.first {
                    rings.append(coords2D(outer))
                }
            case "MultiPolygon":
                if let coords = geometry["coordinates"] as? [[[[Double]]]] {
                    for polygon in coords {
                        if let outer = polygon.first {
                            rings.append(coords2D(outer))
                        }
                    }
                }
            default:
                break
            }

            if !rings.isEmpty {
                result[iso, default: []].append(contentsOf: rings)
            }
        }

        return result
    }

    private static func coords2D(_ raw: [[Double]]) -> [CLLocationCoordinate2D] {
        raw.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
        }
    }
}
