import SwiftUI
import MapKit

struct FlightDetailView: View {
    let flight: Flight
    let airportService: AirportService
    let detents: Set<PresentationDetent>

    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationService.self) private var ls

    @State private var showMapPreview = false
    @State private var selectedDetent: PresentationDetent

    init(flight: Flight, airportService: AirportService,
         detents: Set<PresentationDetent> = [.large],
         startDetent: PresentationDetent = .large) {
        self.flight = flight
        self.airportService = airportService
        self.detents = detents
        _selectedDetent = State(initialValue: startDetent)
    }

    private var origin: Airport? { airportService.airport(for: flight.originIATA) }
    private var dest: Airport?   { airportService.airport(for: flight.destinationIATA) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            FDColor.surface.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    routeHeader
                    // Animated map preview — expands below header on tap
                    if showMapPreview, let o = origin, let d = dest {
                        FlightRouteMapView(origin: o, destination: d)
                            .frame(height: 240)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    Divider().background(FDColor.border).padding(.horizontal, 24)
                    metaSection
                    if flight.airline != nil || flight.seatType != nil || flight.flightClass != nil || flight.aircraftType != nil || flight.flightNumber != nil || flight.price != nil {
                        Divider().background(FDColor.border).padding(.horizontal, 24)
                        travelSection
                    }
                    Divider().background(FDColor.border).padding(.horizontal, 24)
                    airportSection
                }
                .padding(.bottom, 48)
            }

            // Dismiss button
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FDColor.textMuted)
                    .frame(width: 32, height: 32)
                    .background(FDColor.surface3)
                    .clipShape(Circle())
            }
            .padding(.top, 20)
            .padding(.trailing, 24)
        }
        .presentationBackground(FDColor.surface)
        .presentationDetents(detents, selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .preferredColorScheme(ls.preferredColorScheme)
    }

    // MARK: - Route Header (tappable)

    private var routeHeader: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                showMapPreview.toggle()
                if showMapPreview { selectedDetent = .large }
            }
        } label: {
            VStack(spacing: 0) {
                // Decorative arc
                RouteArcView(arcColor: FDColor.gold)
                    .frame(height: 80)
                    .padding(.top, 32)

                // IATA codes
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(flight.originIATA)
                            .font(FDFont.display(44, weight: .bold))
                            .foregroundStyle(FDColor.text)
                        Text(origin?.city ?? "—")
                            .font(FDFont.ui(13))
                            .foregroundStyle(FDColor.textMuted)
                        Text(origin?.country ?? "")
                            .font(FDFont.ui(11))
                            .foregroundStyle(FDColor.textDim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "airplane")
                        .font(.system(size: 18))
                        .foregroundStyle(FDColor.gold)
                        .padding(.top, 12)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(flight.destinationIATA)
                            .font(FDFont.display(44, weight: .bold))
                            .foregroundStyle(FDColor.gold)
                        Text(dest?.city ?? "—")
                            .font(FDFont.ui(13))
                            .foregroundStyle(FDColor.textMuted)
                        Text(dest?.country ?? "")
                            .font(FDFont.ui(11))
                            .foregroundStyle(FDColor.textDim)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 14)

                // Tap hint
                HStack(spacing: 5) {
                    Image(systemName: showMapPreview ? "chevron.up" : "map")
                        .font(.system(size: 9, weight: .semibold))
                    Text(showMapPreview ? "HIDE MAP" : "PREVIEW ROUTE")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.2)
                }
                .foregroundStyle(FDColor.gold.opacity(0.55))
                .padding(.bottom, 20)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Meta Section

    private var metaSection: some View {
        HStack(spacing: 0) {
            metaCell(
                label: ls.dateLabel.uppercased(),
                value: flight.date.formatted(date: .long, time: .omitted)
            )

            Rectangle()
                .fill(FDColor.border)
                .frame(width: 1)
                .padding(.vertical, 16)

            metaCell(
                label: ls.distanceLabel.uppercased(),
                value: ls.formatDistance(flight.distanceKm)
            )

            Rectangle()
                .fill(FDColor.border)
                .frame(width: 1)
                .padding(.vertical, 16)

            metaCell(
                label: ls.estDurationLabel,
                value: flight.estimatedDurationFormatted
            )
        }
        .padding(.vertical, 4)
    }

    private func metaCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(FDFont.ui(10, weight: .medium))
                .foregroundStyle(FDColor.textDim)
                .tracking(1.5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(FDFont.ui(14, weight: .medium))
                .foregroundStyle(FDColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Travel Section

    private var travelSection: some View {
        let items: [(label: String, value: String, icon: String)] = [
            flight.flightNumber.map { (ls.flightNumberLabel, $0, "number") },
            flight.airline.map { (ls.airlineLabel, $0, "airplane.circle") },
            flight.aircraftType.map { (ls.aircraftLabel, $0, "airplane") },
            flight.flightClass.map { (ls.classLabel, ls.flightClassLabel($0), $0.icon) },
            flight.seatType.map { (ls.seatLabel, ls.seatTypeLabel($0), $0.icon) },
            flight.price.map { (ls.priceLabel, ls.formatPrice($0), "banknote") }
        ].compactMap { $0 }

        let rows = stride(from: 0, to: items.count, by: 2).map {
            Array(items[$0..<min($0 + 2, items.count)])
        }

        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                if rowIndex > 0 {
                    Rectangle().fill(FDColor.border).frame(height: 1).padding(.horizontal, 24)
                }
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, item in
                        if colIndex > 0 {
                            Rectangle().fill(FDColor.border).frame(width: 1).padding(.vertical, 16)
                        }
                        travelCell(label: item.label, value: item.value, icon: item.icon)
                    }
                }
            }
        }
    }

    private func travelCell(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(FDColor.gold)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(FDFont.ui(10, weight: .medium))
                    .foregroundStyle(FDColor.textDim)
                    .tracking(1.5)
                    .lineLimit(1)
                Text(value)
                    .font(FDFont.ui(14, weight: .medium))
                    .foregroundStyle(FDColor.text)
                    .lineLimit(1)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Airport Detail Section

    private var airportSection: some View {
        VStack(spacing: 0) {
            if let o = origin {
                airportRow(label: ls.originLabel, airport: o)
                Divider().background(FDColor.border).padding(.horizontal, 24)
            }
            if let d = dest {
                airportRow(label: ls.destinationLabel, airport: d)
            }
        }
    }

    private func airportRow(label: String, airport: Airport) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(label)
                    .font(FDFont.ui(10, weight: .medium))
                    .foregroundStyle(FDColor.textDim)
                    .tracking(1.5)
                Text(airport.name)
                    .font(FDFont.ui(15, weight: .medium))
                    .foregroundStyle(FDColor.text)
                    .lineLimit(2)
                Text("\(airport.city), \(airport.country)")
                    .font(FDFont.ui(12))
                    .foregroundStyle(FDColor.textMuted)
            }

            Spacer()

            Text(airport.iata)
                .font(FDFont.display(22, weight: .bold))
                .foregroundStyle(FDColor.gold.opacity(0.5))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }
}

// MARK: - Decorative Arc

private struct RouteArcView: View {
    let arcColor: Color

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            var arc = Path()
            arc.move(to: CGPoint(x: w * 0.12, y: h * 0.85))
            arc.addQuadCurve(
                to: CGPoint(x: w * 0.88, y: h * 0.85),
                control: CGPoint(x: w * 0.50, y: -h * 0.20)
            )
            ctx.stroke(arc,
                       with: .color(arcColor.opacity(0.4)),
                       style: StrokeStyle(lineWidth: 1.5, dash: [5, 6]))

            let r: Double = 4
            func dot(_ x: Double, _ y: Double) {
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r*2, height: r*2)),
                         with: .color(arcColor.opacity(0.85)))
            }
            dot(w * 0.12, h * 0.85)
            dot(w * 0.88, h * 0.85)
        }
    }
}

// MARK: - Animated Flight Route Map
//
// Approach: the plane icon stays fixed at the center of the view.
// The map camera pans + rotates along the great-circle arc so the route
// sweeps underneath the plane. Camera heading = current bearing, so the
// direction of travel always points "up". This avoids any 3D-projection
// mismatch between the polyline and a screen-coordinate overlay.

private struct FlightRouteMapView: View {
    let origin: Airport
    let destination: Airport

    @State private var cameraPosition: MapCameraPosition
    @State private var currentBearing: Double = 0
    @State private var isFinished = false
    @State private var replayToken = 0  // incrementing restarts .task(id:)

    init(origin: Airport, destination: Airport) {
        self.origin = origin
        self.destination = destination
        _cameraPosition = State(initialValue: .camera(MapCamera(
            centerCoordinate: origin.coordinate,
            distance: 3_000_000,
            heading: 0,
            pitch: 0
        )))
    }

    private let animationDuration = 6.0

    // Altitude scaled to route length so short and long routes both look good
    private var cameraAltitude: Double {
        let lat1 = origin.lat      * .pi / 180
        let lat2 = destination.lat * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (destination.lon - origin.lon) * .pi / 180
        let a    = sin(dLat/2)*sin(dLat/2) + cos(lat1)*cos(lat2)*sin(dLon/2)*sin(dLon/2)
        let distKm = 6371.0 * 2 * atan2(sqrt(a), sqrt(1 - a))
        return max(800_000, min(7_000_000, distKm * 500))
    }

    private var arcPoints: [CLLocationCoordinate2D] {
        greatCircle(from: origin.coordinate, to: destination.coordinate)
    }

    // Sine ease-in/out: slow takeoff → full cruise → slow landing
    private func easeInOut(_ t: Double) -> Double {
        (1 - cos(t * .pi)) / 2
    }

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                MapPolyline(coordinates: arcPoints)
                    .stroke(Color(hex: "C9A96E"), lineWidth: 2)
            }
            .mapStyle(.imagery(elevation: .realistic))
            .disabled(true)

            // Plane stays centered; map moves beneath it.
            // Map heading is fixed at 0 (north up) so the map doesn't spin.
            // The plane icon rotates to follow the route bearing instead.
            // -45° corrects for the SF Symbol pointing NE by default.
            Image(systemName: "airplane")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(currentBearing - 45))
                .shadow(color: Color(hex: "C9A96E"), radius: 6)
                .shadow(color: .black.opacity(0.6), radius: 2)

            // Replay button — fades in after landing
            if isFinished {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            isFinished = false
                            replayToken += 1
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "0A0A0F"))
                                .frame(width: 36, height: 36)
                                .background(Color(hex: "C9A96E"))
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.4), radius: 4)
                        }
                        .padding(12)
                    }
                }
                .transition(.opacity)
            }
        }
        .task(id: replayToken) {
            let start    = Date()
            let altitude = cameraAltitude
            let pts      = arcPoints

            while !Task.isCancelled {
                let elapsed     = Date().timeIntervalSince(start)
                let rawProgress = min(1.0, elapsed / animationDuration)
                let eased       = easeInOut(rawProgress)

                let b = bearing(at: eased, in: pts)
                currentBearing = b
                cameraPosition = .camera(MapCamera(
                    centerCoordinate: interpolatedCoord(at: eased, in: pts),
                    distance: altitude,
                    heading: 0,  // north always up — plane icon rotates instead
                    pitch: 0
                ))

                if rawProgress >= 1.0 {
                    withAnimation { isFinished = true }
                    break
                }

                try? await Task.sleep(nanoseconds: 33_333_333) // ~30 fps
            }
        }
    }

    // MARK: - Helpers

    private func interpolatedCoord(at progress: Double, in pts: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard pts.count > 1 else { return origin.coordinate }
        let t    = max(0, min(1, progress)) * Double(pts.count - 1)
        let idx  = Int(t)
        let frac = t - Double(idx)
        let a    = pts[min(idx,     pts.count - 1)]
        let b    = pts[min(idx + 1, pts.count - 1)]
        return CLLocationCoordinate2D(
            latitude:  a.latitude  + frac * (b.latitude  - a.latitude),
            longitude: a.longitude + frac * (b.longitude - a.longitude)
        )
    }

    // Screen bearing using Mercator projection — matches the visual angle of the
    // polyline on the map (geodesic bearing ≠ Mercator screen angle, especially
    // at high latitudes and for east-west routes like Boston→London).
    private func bearing(at progress: Double, in pts: [CLLocationCoordinate2D]) -> Double {
        guard pts.count > 1 else { return 0 }
        let t    = max(0, min(0.999, progress)) * Double(pts.count - 1)
        let idx  = min(Int(t), pts.count - 2)
        let from = pts[idx], to = pts[idx + 1]
        let dLon = to.longitude - from.longitude
        // Mercator y in the same degree-scale as longitude
        let mercY1 = log(tan(.pi / 4 + from.latitude * .pi / 360)) * 180 / .pi
        let mercY2 = log(tan(.pi / 4 + to.latitude   * .pi / 360)) * 180 / .pi
        // atan2(east-component, north-component) → clockwise angle from north
        return (atan2(dLon, mercY2 - mercY1) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private func greatCircle(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        steps: Int = 80
    ) -> [CLLocationCoordinate2D] {
        let lat1 = from.latitude  * .pi / 180, lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude    * .pi / 180, lon2 = to.longitude   * .pi / 180
        let cosD = sin(lat1)*sin(lat2) + cos(lat1)*cos(lat2)*cos(lon2 - lon1)
        let d    = acos(max(-1, min(1, cosD)))
        guard d > 0.0001 else { return [from, to] }
        return (0...steps).map { i in
            let f = Double(i) / Double(steps)
            let A = sin((1-f)*d)/sin(d), B = sin(f*d)/sin(d)
            let x = A*cos(lat1)*cos(lon1) + B*cos(lat2)*cos(lon2)
            let y = A*cos(lat1)*sin(lon1) + B*cos(lat2)*sin(lon2)
            let z = A*sin(lat1)           + B*sin(lat2)
            return CLLocationCoordinate2D(
                latitude:  atan2(z, sqrt(x*x + y*y)) * 180 / .pi,
                longitude: atan2(y, x) * 180 / .pi
            )
        }
    }
}
