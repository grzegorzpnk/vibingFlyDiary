import SwiftUI
import MapKit
import SwiftData

struct MapFlightView: View {
    @Query(sort: \Flight.date, order: .reverse) private var flights: [Flight]
    @Environment(AirportService.self) private var airportService

    @State private var selectedYear: Int? = nil
    @State private var beenMode: Bool = false

    /// Unique ISO-A2 country codes touched by filteredFlights (both origin + destination)
    private var visitedIsoCodes: Set<String> {
        var codes = Set<String>()
        for flight in filteredFlights {
            if let o = airportService.airport(for: flight.originIATA)      { codes.insert(o.country) }
            if let d = airportService.airport(for: flight.destinationIATA) { codes.insert(d.country) }
        }
        return codes
    }

    /// Flat list of (id, coordinates) ready for ForEach + MapPolygon
    private struct CountryRing: Identifiable {
        let id: String
        let coordinates: [CLLocationCoordinate2D]
    }

    private var countryRings: [CountryRing] {
        var rings: [CountryRing] = []
        for iso in visitedIsoCodes {
            let polygons = CountryShapeService.shared.polygons(for: iso)
            for (index, coords) in polygons.enumerated() {
                rings.append(CountryRing(id: "\(iso)-\(index)", coordinates: coords))
            }
        }
        return rings
    }

    private var availableYears: [Int] {
        let years = flights.compactMap { Calendar.current.component(.year, from: $0.date) }
        return Array(Set(years)).sorted(by: >)
    }

    private var filteredFlights: [Flight] {
        guard let year = selectedYear else { return flights }
        return flights.filter { Calendar.current.component(.year, from: $0.date) == year }
    }

    @State private var position: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 47, longitude: 13),
            distance: 15_000_000,
            heading: 0,
            pitch: 0
        )
    )

    private var visitedCountries: [String] {
        let codes = filteredFlights.compactMap { airportService.airport(for: $0.destinationIATA)?.country }
        return Array(Set(codes)).sorted()
    }

    var body: some View {
        ZStack {
            // Full-screen map
            Map(position: $position) {
                // Been mode: country boundary fills
                if beenMode {
                    ForEach(countryRings) { ring in
                        MapPolygon(coordinates: ring.coordinates)
                            .foregroundStyle(Color(hex: "C9A96E").opacity(0.42))
                            .stroke(Color(hex: "C9A96E").opacity(0.85), lineWidth: 1.5)
                    }
                }

                ForEach(filteredFlights) { flight in
                    if let origin = airportService.airport(for: flight.originIATA),
                       let dest   = airportService.airport(for: flight.destinationIATA) {
                        let arc = greatCirclePoints(from: origin.coordinate, to: dest.coordinate)
                        let upcoming = flight.date > .now
                        let arcColor = upcoming ? FDColor.blue : FDColor.gold

                        // Subtle body — no blur, just slight width
                        MapPolyline(coordinates: arc)
                            .stroke(arcColor.opacity(0.22), lineWidth: 5)

                        // Clean sharp core
                        MapPolyline(coordinates: arc)
                            .stroke(arcColor.opacity(0.88), lineWidth: 2)

                        Annotation("", coordinate: origin.coordinate) {
                            airportDot(upcoming: upcoming)
                        }
                        Annotation("", coordinate: dest.coordinate) {
                            airportDot(upcoming: upcoming)
                        }
                    }
                }
            }
            .mapStyle(.hybrid(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
            .ignoresSafeArea()

            // Top gradient + title + year chips
            VStack {
                LinearGradient(
                    colors: [Color(hex: "0D1520").opacity(0.96), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 170)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FLIGHT MAP")
                                .font(FDFont.ui(11, weight: .medium))
                                .foregroundStyle(FDColor.gold)
                                .tracking(2.5)
                            Text("Flight Map")
                                .font(FDFont.display(22, weight: .bold))
                                .foregroundStyle(FDColor.text)
                        }

                        if availableYears.count > 0 || true {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    // Been mode toggle
                                    yearChip(label: "✓ Been", active: beenMode) {
                                        beenMode.toggle()
                                    }

                                    // Divider
                                    Rectangle()
                                        .fill(FDColor.borderBright)
                                        .frame(width: 1, height: 20)

                                    yearChip(label: "All", active: selectedYear == nil) {
                                        selectedYear = nil
                                    }
                                    ForEach(availableYears, id: \.self) { year in
                                        yearChip(label: "\(year)", active: selectedYear == year) {
                                            selectedYear = selectedYear == year ? nil : year
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.horizontal, -20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .ignoresSafeArea(edges: .top)

                Spacer()
            }

            // Bottom gradient + country tags
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, Color(hex: "0D1520").opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 160)
                .overlay(alignment: .bottomLeading) {
                    bottomPanel
                }
            }
        }
    }

    private func yearChip(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(FDFont.ui(12, weight: .medium))
                .foregroundStyle(active ? Color(hex: "E8C98A") : FDColor.textMuted)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(active ? FDColor.gold.opacity(0.15) : FDColor.surface2)
                .overlay(
                    Capsule().stroke(active ? FDColor.gold : FDColor.borderBright, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: active)
    }

    private func airportDot(upcoming: Bool) -> some View {
        let color = upcoming ? FDColor.blue : FDColor.gold
        return ZStack {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 14, height: 14)
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
        }
    }

    @ViewBuilder
    private var bottomPanel: some View {
        let visited = visitedIsoCodes.count
        let total   = CountryShapeService.shared.shapes.count
        let progress = total > 0 ? Double(visited) / Double(total) : 0

        VStack(alignment: .leading, spacing: 10) {
            Text("COUNTRIES VISITED")
                .font(FDFont.ui(11, weight: .medium))
                .foregroundStyle(FDColor.gold)
                .tracking(1.5)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(visited)")
                    .font(FDFont.display(48, weight: .bold))
                    .foregroundStyle(FDColor.text)
                Text("/ \(total)")
                    .font(FDFont.display(22, weight: .bold))
                    .foregroundStyle(FDColor.textMuted)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FDColor.borderBright)
                        .frame(height: 3)
                    Capsule()
                        .fill(FDColor.gold)
                        .frame(width: geo.size.width * progress, height: 3)
                }
            }
            .frame(height: 3)
            .frame(maxWidth: 220)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 100)
    }

    // MARK: - Great Circle

    private func greatCirclePoints(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        steps: Int = 100
    ) -> [CLLocationCoordinate2D] {
        let lat1 = from.latitude  * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude    * .pi / 180
        let lon2 = to.longitude   * .pi / 180

        let cosD = sin(lat1)*sin(lat2) + cos(lat1)*cos(lat2)*cos(lon2 - lon1)
        let d = acos(max(-1.0, min(1.0, cosD)))
        guard d > 0.0001 else { return [from, to] }

        return (0...steps).map { i in
            let f = Double(i) / Double(steps)
            let A = sin((1 - f) * d) / sin(d)
            let B = sin(f * d)       / sin(d)
            let x = A * cos(lat1) * cos(lon1) + B * cos(lat2) * cos(lon2)
            let y = A * cos(lat1) * sin(lon1) + B * cos(lat2) * sin(lon2)
            let z = A * sin(lat1)              + B * sin(lat2)
            return CLLocationCoordinate2D(
                latitude:  atan2(z, sqrt(x*x + y*y)) * 180 / .pi,
                longitude: atan2(y, x) * 180 / .pi
            )
        }
    }
}
