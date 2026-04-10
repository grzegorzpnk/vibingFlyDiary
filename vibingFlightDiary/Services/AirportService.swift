import Foundation
import Observation

@Observable
class AirportService {
    private(set) var airports: [Airport] = []

    init() {
        load()
    }

    func airport(for iata: String) -> Airport? {
        airports.first { $0.iata == iata }
    }

    func search(_ query: String) -> [Airport] {
        guard !query.isEmpty else { return [] }
        let q = query.uppercased()
        return airports
            .filter {
                $0.iata.contains(q) ||
                $0.city.uppercased().contains(q) ||
                $0.name.uppercased().contains(q) ||
                $0.country.uppercased().contains(q)
            }
            .prefix(30)
            .map { $0 }
    }

    private func load() {
        guard
            let url = Bundle.main.url(forResource: "airports", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([Airport].self, from: data)
        else {
            return
        }
        airports = decoded
    }
}
