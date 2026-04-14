import SwiftUI
import MapKit
import SwiftData

struct MapFlightView: View {
    @Query(sort: \Flight.date, order: .reverse) private var flights: [Flight]
    @Environment(AirportService.self) private var airportService

    @State private var selectedYear: Int? = nil
    @State private var beenMode: Bool = false
    @State private var selectedFlight: Flight?

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

    /// Unique airports across filteredFlights. Bool = hasAnyUpcomingFlight using that airport.
    private var uniqueAirportDots: [(airport: Airport, upcoming: Bool)] {
        var seen: [String: Bool] = [:]
        for flight in filteredFlights {
            let up = flight.date > .now
            for iata in [flight.originIATA, flight.destinationIATA] {
                seen[iata] = (seen[iata] == true) || up
            }
        }
        return seen.compactMap { iata, up in
            airportService.airport(for: iata).map { ($0, up) }
        }
    }

    private var totalKm: Int {
        Int(filteredFlights.reduce(0) { $0 + $1.distanceKm })
    }

    private var kmFormatted: String {
        totalKm >= 1000 ? "\(totalKm / 1000)k" : "\(totalKm)"
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

                // Arcs + midpoint taps
                ForEach(filteredFlights) { flight in
                    if let origin = airportService.airport(for: flight.originIATA),
                       let dest   = airportService.airport(for: flight.destinationIATA) {
                        let arc = greatCirclePoints(from: origin.coordinate, to: dest.coordinate)
                        let upcoming = flight.date > .now
                        let arcColor = upcoming ? FDColor.blue : FDColor.gold

                        MapPolyline(coordinates: arc)
                            .stroke(arcColor.opacity(0.22), lineWidth: 5)
                        MapPolyline(coordinates: arc)
                            .stroke(arcColor.opacity(0.88), lineWidth: 2)

                        if arc.indices.contains(arc.count / 2) {
                            Annotation("", coordinate: arc[arc.count / 2]) {
                                Button {
                                    selectedFlight = flight
                                } label: {
                                    Image(systemName: "airplane")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(arcColor)
                                        .frame(width: 22, height: 22)
                                        .background(.ultraThinMaterial, in: Circle())
                                        .overlay(Circle().stroke(arcColor.opacity(0.4), lineWidth: 0.8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Deduplicated airport dots (one per unique airport)
                ForEach(uniqueAirportDots, id: \.airport.iata) { item in
                    Annotation("", coordinate: item.airport.coordinate) {
                        airportDot(upcoming: item.upcoming)
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

                        HStack(spacing: 8) {
                            // Been mode — always visible, outside scroll
                            yearChip(label: "✓ Been", active: beenMode) {
                                beenMode.toggle()
                            }

                            Rectangle()
                                .fill(FDColor.borderBright)
                                .frame(width: 1, height: 20)

                            // Year chips — scrollable with soft trailing fade
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    yearChip(label: "All", active: selectedYear == nil) {
                                        selectedYear = nil
                                    }
                                    ForEach(availableYears, id: \.self) { year in
                                        yearChip(label: "\(year)", active: selectedYear == year) {
                                            selectedYear = selectedYear == year ? nil : year
                                        }
                                    }
                                }
                                .padding(.trailing, 24)
                            }
                            .mask(
                                LinearGradient(
                                    stops: [
                                        .init(color: .black, location: 0),
                                        .init(color: .black, location: 0.75),
                                        .init(color: .clear, location: 1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .ignoresSafeArea(edges: .top)

                Spacer()
            }

            // Bottom gradient + stats panel
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, FDColor.black.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 160)
                .overlay(alignment: .bottomLeading) {
                    bottomPanel
                }
            }

            // Recenter button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            position = .camera(MapCamera(
                                centerCoordinate: CLLocationCoordinate2D(latitude: 47, longitude: 13),
                                distance: 15_000_000, heading: 0, pitch: 0
                            ))
                        }
                    } label: {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(FDColor.gold)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(FDColor.gold.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.bottom, 120)
                }
            }
        }
        .sheet(item: $selectedFlight) { flight in
            FlightDetailView(flight: flight, airportService: airportService, detents: [.fraction(0.6)])
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
        let visited  = visitedIsoCodes.count
        let total    = CountryShapeService.shared.shapes.count
        let progress = total > 0 ? Double(visited) / Double(total) : 0

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 20) {
                statItem(value: "\(filteredFlights.count)", label: "FLIGHTS")
                statDivider
                statItem(value: "\(kmFormatted) km", label: "DISTANCE")
                statDivider
                statItem(value: "\(visited) / \(total)", label: "COUNTRIES")
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(FDColor.borderBright).frame(height: 3)
                    Capsule().fill(FDColor.gold).frame(width: geo.size.width * progress, height: 3)
                }
            }
            .frame(height: 3)
            .frame(maxWidth: 260)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 100)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(FDFont.display(20, weight: .bold))
                .foregroundStyle(FDColor.text)
            Text(label)
                .font(FDFont.ui(10, weight: .medium))
                .foregroundStyle(FDColor.gold)
                .tracking(1.2)
        }
    }

    private var statDivider: some View {
        Rectangle()
            .fill(FDColor.borderBright)
            .frame(width: 1, height: 28)
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
