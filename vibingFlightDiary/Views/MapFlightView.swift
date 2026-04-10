import SwiftUI
import MapKit
import SwiftData

struct MapFlightView: View {
    @Query(sort: \Flight.date, order: .reverse) private var flights: [Flight]
    @Environment(AirportService.self) private var airportService

    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20, longitude: 10),
            span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 160)
        )
    )

    private var visitedCountries: [String] {
        let codes = flights.compactMap { airportService.airport(for: $0.destinationIATA)?.country }
        return Array(Set(codes)).sorted()
    }

    var body: some View {
        ZStack {
            // Full-screen satellite map
            Map(position: $position) {
                ForEach(flights) { flight in
                    if let origin = airportService.airport(for: flight.originIATA),
                       let dest   = airportService.airport(for: flight.destinationIATA) {
                        let arc = greatCirclePoints(from: origin.coordinate, to: dest.coordinate)

                        // Glow layer
                        MapPolyline(coordinates: arc)
                            .stroke(FDColor.gold.opacity(0.22), lineWidth: 10)

                        // Core arc
                        MapPolyline(coordinates: arc)
                            .stroke(FDColor.gold, lineWidth: 1.5)

                        Annotation("", coordinate: origin.coordinate) {
                            airportDot
                        }
                        Annotation("", coordinate: dest.coordinate) {
                            airportDot
                        }
                    }
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .ignoresSafeArea()

            // Top gradient + title
            VStack {
                LinearGradient(
                    colors: [Color(hex: "0D1520").opacity(0.96), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 130)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FLIGHT MAP")
                            .font(FDFont.ui(11, weight: .medium))
                            .foregroundStyle(FDColor.gold)
                            .tracking(2.5)
                        Text("Flight Map")
                            .font(FDFont.display(22, weight: .bold))
                            .foregroundStyle(FDColor.text)
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

    private var airportDot: some View {
        Circle()
            .fill(FDColor.gold)
            .frame(width: 7, height: 7)
            .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
    }

    @ViewBuilder
    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if visitedCountries.isEmpty {
                Text("Add flights to see your travel map")
                    .font(FDFont.ui(12))
                    .foregroundStyle(FDColor.textMuted)
            } else {
                Text("\(visitedCountries.count) COUNTR\(visitedCountries.count == 1 ? "Y" : "IES") VISITED")
                    .font(FDFont.ui(11, weight: .medium))
                    .foregroundStyle(FDColor.textMuted)
                    .tracking(1.5)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(visitedCountries.prefix(8), id: \.self) { country in
                            countryTag(country)
                        }
                        if visitedCountries.count > 8 {
                            countryTag("+\(visitedCountries.count - 8) more")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 100) // clear custom tab bar
    }

    private func countryTag(_ text: String) -> some View {
        Text(text)
            .font(FDFont.ui(11))
            .foregroundStyle(FDColor.textMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(FDColor.surface3)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(FDColor.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
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
