import SwiftUI
import CoreLocation

// MARK: - Flight Map Share Card

/// Pure SwiftUI view — no MapKit, renders cleanly via ImageRenderer.
/// Always given an explicit frame before rendering.
struct FlightMapShareCard: View {
    let flights: [Flight]
    let airportService: AirportService

    private var past: [Flight] { flights.filter { $0.date <= .now } }

    private var visitedISOCodes: Set<String> {
        var s = Set<String>()
        for f in past {
            if let o = airportService.airport(for: f.originIATA)      { s.insert(o.country) }
            if let d = airportService.airport(for: f.destinationIATA) { s.insert(d.country) }
        }
        return s
    }

    private var totalKm: Int { Int(past.reduce(0) { $0 + $1.distanceKm }) }
    private var kmLabel: String { totalKm >= 1_000 ? "\(totalKm / 1_000)K" : "\(totalKm)" }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                Color(hex: "0A0A0F")

                RadialGradient(
                    colors: [Color(hex: "1A2A4A").opacity(0.45), .clear],
                    center: .init(x: 0.5, y: 0.44),
                    startRadius: 0,
                    endRadius: w * 0.8
                )

                Canvas { ctx, size in
                    drawCountries(ctx: ctx, size: size)
                    drawArcs(ctx: ctx, size: size)
                    drawDots(ctx: ctx, size: size)
                }

                VStack(spacing: 0) {
                    // Top branding
                    HStack(spacing: w * 0.015) {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: w * 0.04, weight: .semibold))
                            .foregroundStyle(Color(hex: "C9A96E"))
                        Text("FLYGRAM")
                            .font(.system(size: w * 0.032, weight: .semibold))
                            .tracking(w * 0.009)
                            .foregroundStyle(Color(hex: "F0EEE8").opacity(0.7))
                    }
                    .padding(.top, h * 0.052)

                    Spacer()

                    // Bottom stats
                    VStack(spacing: h * 0.013) {
                        HStack(spacing: 0) {
                            statPill(value: "\(past.count)", label: "FLIGHTS", w: w)
                            Spacer()
                            statPill(value: kmLabel, label: "KM FLOWN", w: w)
                            Spacer()
                            statPill(value: "\(visitedISOCodes.count)", label: "COUNTRIES", w: w)
                        }
                        .padding(.horizontal, w * 0.09)

                        Text("flygram.app")
                            .font(.system(size: w * 0.024, weight: .light))
                            .tracking(w * 0.005)
                            .foregroundStyle(Color(hex: "F0EEE8").opacity(0.18))
                    }
                    .padding(.bottom, h * 0.065)
                }
            }
        }
    }

    // MARK: - Stat Pill

    private func statPill(value: String, label: String, w: CGFloat) -> some View {
        VStack(spacing: w * 0.01) {
            Text(value)
                .font(.system(size: w * 0.062, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "C9A96E"))
            Text(label)
                .font(.system(size: w * 0.022, weight: .medium))
                .tracking(w * 0.004)
                .foregroundStyle(Color(hex: "F0EEE8").opacity(0.38))
        }
    }

    // MARK: - Projection

    private let minLat = -60.0
    private let maxLat =  84.0

    private func mapRect(in size: CGSize) -> CGRect {
        let lonRange = 360.0
        let latRange = maxLat - minLat
        let aspect   = lonRange / latRange
        let mapW     = size.width
        let mapH     = mapW / aspect
        let mapY     = (size.height - mapH) * 0.38
        return CGRect(x: 0, y: mapY, width: mapW, height: mapH)
    }

    private func project(_ coord: CLLocationCoordinate2D, in size: CGSize) -> CGPoint {
        let rect = mapRect(in: size)
        let x = rect.minX + (coord.longitude + 180) / 360           * rect.width
        let y = rect.minY + (maxLat - coord.latitude) / (maxLat - minLat) * rect.height
        return CGPoint(x: x, y: y)
    }

    // MARK: - Canvas: Countries

    private func countryPath(_ ring: [CLLocationCoordinate2D], in size: CGSize) -> Path {
        var path = Path()
        for (i, coord) in ring.enumerated() {
            let pt = project(coord, in: size)
            if i == 0 {
                path.move(to: pt)
            } else if abs(coord.longitude - ring[i - 1].longitude) < 180 {
                path.addLine(to: pt)
            } else {
                path.move(to: pt)
            }
        }
        path.closeSubpath()
        return path
    }

    private func drawCountries(ctx: GraphicsContext, size: CGSize) {
        let outlineW  = max(0.25, size.width * 0.00038)
        let visitedW  = max(0.35, size.width * 0.00065)

        for (iso, rings) in CountryShapeService.shared.shapes {
            let visited = visitedISOCodes.contains(iso)
            for ring in rings {
                guard ring.count > 1 else { continue }
                let path = countryPath(ring, in: size)
                if visited {
                    ctx.fill(path, with: .color(Color(hex: "C9A96E").opacity(0.18)))
                    ctx.stroke(path, with: .color(Color(hex: "C9A96E").opacity(0.7)), lineWidth: visitedW)
                } else {
                    ctx.stroke(path, with: .color(.white.opacity(0.09)), lineWidth: outlineW)
                }
            }
        }
    }

    // MARK: - Canvas: Arcs (deduplicated — one arc per unique route)

    private func drawArcs(ctx: GraphicsContext, size: CGSize) {
        let glowW  = max(0.8, size.width * 0.003)
        let solidW = max(0.4, size.width * 0.001)

        var seen = Set<String>()
        for flight in past {
            let key = routeKey(flight.originIATA, flight.destinationIATA)
            guard seen.insert(key).inserted else { continue }

            guard
                let origin = airportService.airport(for: flight.originIATA),
                let dest   = airportService.airport(for: flight.destinationIATA)
            else { continue }

            let pts = greatCircle(from: origin.coordinate, to: dest.coordinate)
            var glow = Path(), solid = Path()
            for (i, coord) in pts.enumerated() {
                let pt = project(coord, in: size)
                if i == 0 { glow.move(to: pt); solid.move(to: pt) }
                else       { glow.addLine(to: pt); solid.addLine(to: pt) }
            }
            ctx.stroke(glow,  with: .color(Color(hex: "C9A96E").opacity(0.22)), lineWidth: glowW)
            ctx.stroke(solid, with: .color(Color(hex: "C9A96E").opacity(0.88)), lineWidth: solidW)
        }
    }

    private func routeKey(_ a: String, _ b: String) -> String {
        a < b ? "\(a)-\(b)" : "\(b)-\(a)"
    }

    // MARK: - Canvas: Airport Dots

    private func drawDots(ctx: GraphicsContext, size: CGSize) {
        let r = max(1.0, size.width * 0.0038)
        var seen = Set<String>()
        for flight in past {
            for iata in [flight.originIATA, flight.destinationIATA] {
                guard !seen.contains(iata), let ap = airportService.airport(for: iata) else { continue }
                seen.insert(iata)
                let pt = project(ap.coordinate, in: size)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                    with: .color(Color(hex: "C9A96E"))
                )
            }
        }
    }

    // MARK: - Great Circle

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

// MARK: - Countries Share Card

struct CountriesShareCard: View {
    let flights: [Flight]
    let airportService: AirportService

    private var past: [Flight] { flights.filter { $0.date <= .now } }

    private var visitedCountries: [String] {
        var s = Set<String>()
        for f in past {
            if let o = airportService.airport(for: f.originIATA)      { s.insert(o.country) }
            if let d = airportService.airport(for: f.destinationIATA) { s.insert(d.country) }
        }
        return s.sorted()
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Color(hex: "0A0A0F")
                RadialGradient(
                    colors: [Color(hex: "1A0A3A").opacity(0.6), .clear],
                    center: .init(x: 0.5, y: 0.3),
                    startRadius: 0,
                    endRadius: w
                )

                VStack(spacing: 0) {
                    // Branding
                    HStack(spacing: w * 0.015) {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: w * 0.04, weight: .semibold))
                            .foregroundStyle(Color(hex: "C9A96E"))
                        Text("FLYGRAM")
                            .font(.system(size: w * 0.032, weight: .semibold))
                            .tracking(w * 0.009)
                            .foregroundStyle(Color(hex: "F0EEE8").opacity(0.7))
                    }
                    .padding(.top, h * 0.052)

                    Spacer()

                    // Big number
                    VStack(spacing: h * 0.008) {
                        Text("\(visitedCountries.count)")
                            .font(.system(size: w * 0.26, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "C9A96E"))
                        Text("COUNTRIES VISITED")
                            .font(.system(size: w * 0.028, weight: .semibold))
                            .tracking(w * 0.007)
                            .foregroundStyle(Color(hex: "F0EEE8").opacity(0.4))
                    }

                    Spacer().frame(height: h * 0.045)

                    // Flag grid
                    flagGrid(countries: visitedCountries, w: w)

                    Spacer()

                    Text("flygram.app")
                        .font(.system(size: w * 0.024, weight: .light))
                        .tracking(w * 0.005)
                        .foregroundStyle(Color(hex: "F0EEE8").opacity(0.18))
                        .padding(.bottom, h * 0.065)
                }
            }
        }
    }

    @ViewBuilder
    private func flagGrid(countries: [String], w: CGFloat) -> some View {
        let shown  = Array(countries.prefix(42))
        let cols   = 7
        let spacing = w * 0.012
        let padH   = w * 0.06
        let cellW  = (w - CGFloat(cols - 1) * spacing - padH * 2) / CGFloat(cols)
        let rows: [[String]] = stride(from: 0, to: shown.count, by: cols).map { start in
            Array(shown[start..<min(start + cols, shown.count)])
        }

        VStack(spacing: spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: spacing) {
                    ForEach(row, id: \.self) { iso in
                        Text(flagFor(iso))
                            .font(.system(size: cellW * 0.7))
                            .frame(width: cellW, height: cellW * 0.75)
                    }
                    if row.count < cols { Spacer() }
                }
            }
        }
        .padding(.horizontal, padH)
    }

    private func flagFor(_ iso: String) -> String {
        guard iso.count == 2 else { return "🌐" }
        return iso.uppercased().unicodeScalars.compactMap {
            Unicode.Scalar($0.value + 127397)
        }.map(String.init).joined()
    }
}

// MARK: - Top Routes Share Card

struct TopRoutesShareCard: View {
    let flights: [Flight]
    let airportService: AirportService

    private var past: [Flight] { flights.filter { $0.date <= .now } }

    private var topRoutes: [(origin: String, dest: String, count: Int)] {
        var counts: [String: Int] = [:]
        for f in past {
            let key = f.originIATA < f.destinationIATA
                ? "\(f.originIATA)|\(f.destinationIATA)"
                : "\(f.destinationIATA)|\(f.originIATA)"
            counts[key, default: 0] += 1
        }
        return counts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .compactMap { kv -> (String, String, Int)? in
                let parts = kv.key.split(separator: "|").map(String.init)
                guard parts.count == 2 else { return nil }
                return (parts[0], parts[1], kv.value)
            }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Color(hex: "0A0A0F")
                RadialGradient(
                    colors: [Color(hex: "0A2A1A").opacity(0.55), .clear],
                    center: .init(x: 0.5, y: 0.4),
                    startRadius: 0,
                    endRadius: w * 0.9
                )

                VStack(spacing: 0) {
                    // Branding
                    HStack(spacing: w * 0.015) {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: w * 0.04, weight: .semibold))
                            .foregroundStyle(Color(hex: "C9A96E"))
                        Text("FLYGRAM")
                            .font(.system(size: w * 0.032, weight: .semibold))
                            .tracking(w * 0.009)
                            .foregroundStyle(Color(hex: "F0EEE8").opacity(0.7))
                    }
                    .padding(.top, h * 0.052)

                    Spacer().frame(height: h * 0.06)

                    // Section header
                    VStack(spacing: h * 0.008) {
                        Text("TOP ROUTES")
                            .font(.system(size: w * 0.028, weight: .semibold))
                            .tracking(w * 0.008)
                            .foregroundStyle(Color(hex: "F0EEE8").opacity(0.4))
                        Rectangle()
                            .fill(Color(hex: "C9A96E").opacity(0.35))
                            .frame(width: w * 0.1, height: 1)
                    }

                    Spacer().frame(height: h * 0.055)

                    // Route list
                    VStack(spacing: h * 0.03) {
                        if topRoutes.isEmpty {
                            Text("No flights logged yet")
                                .font(.system(size: w * 0.03, weight: .light))
                                .foregroundStyle(Color(hex: "F0EEE8").opacity(0.3))
                        } else {
                            ForEach(Array(topRoutes.enumerated()), id: \.offset) { idx, route in
                                routeRow(rank: idx + 1, origin: route.origin, dest: route.dest, count: route.count, w: w)
                            }
                        }
                    }
                    .padding(.horizontal, w * 0.08)

                    Spacer()

                    Text("flygram.app")
                        .font(.system(size: w * 0.024, weight: .light))
                        .tracking(w * 0.005)
                        .foregroundStyle(Color(hex: "F0EEE8").opacity(0.18))
                        .padding(.bottom, h * 0.065)
                }
            }
        }
    }

    private func routeRow(rank: Int, origin: String, dest: String, count: Int, w: CGFloat) -> some View {
        HStack(spacing: w * 0.025) {
            Text("#\(rank)")
                .font(.system(size: w * 0.028, weight: .semibold))
                .foregroundStyle(Color(hex: "C9A96E").opacity(0.5))
                .frame(width: w * 0.065, alignment: .trailing)

            HStack(spacing: w * 0.022) {
                Text(origin)
                    .font(.system(size: w * 0.068, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "F0EEE8"))
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: w * 0.028, weight: .semibold))
                    .foregroundStyle(Color(hex: "C9A96E").opacity(0.7))
                Text(dest)
                    .font(.system(size: w * 0.068, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "F0EEE8"))
            }

            Spacer()

            if count > 1 {
                Text("×\(count)")
                    .font(.system(size: w * 0.026, weight: .medium))
                    .foregroundStyle(Color(hex: "C9A96E"))
                    .padding(.horizontal, w * 0.022)
                    .padding(.vertical, w * 0.01)
                    .background(Color(hex: "C9A96E").opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Year Stats Share Card

struct YearStatsShareCard: View {
    let flights: [Flight]
    let airportService: AirportService

    private let year = Calendar.current.component(.year, from: .now)

    private var past: [Flight] { flights.filter { $0.date <= .now } }

    private var thisYear: [Flight] {
        past.filter { Calendar.current.component(.year, from: $0.date) == year }
    }

    private var yearCountries: Int {
        var s = Set<String>()
        for f in thisYear {
            if let o = airportService.airport(for: f.originIATA)      { s.insert(o.country) }
            if let d = airportService.airport(for: f.destinationIATA) { s.insert(d.country) }
        }
        return s.count
    }

    private var yearKm: Int { Int(thisYear.reduce(0) { $0 + $1.distanceKm }) }
    private var yearKmLabel: String { yearKm >= 1_000 ? "\(yearKm / 1_000)K" : "\(yearKm)" }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Color(hex: "0A0A0F")
                RadialGradient(
                    colors: [Color(hex: "2A1A0A").opacity(0.55), .clear],
                    center: .init(x: 0.5, y: 0.45),
                    startRadius: 0,
                    endRadius: w
                )

                VStack(spacing: 0) {
                    // Branding
                    HStack(spacing: w * 0.015) {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: w * 0.04, weight: .semibold))
                            .foregroundStyle(Color(hex: "C9A96E"))
                        Text("FLYGRAM")
                            .font(.system(size: w * 0.032, weight: .semibold))
                            .tracking(w * 0.009)
                            .foregroundStyle(Color(hex: "F0EEE8").opacity(0.7))
                    }
                    .padding(.top, h * 0.052)

                    Spacer()

                    // Year headline
                    VStack(spacing: h * 0.008) {
                        Text(verbatim: "\(year)")
                            .font(.system(size: w * 0.2, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "C9A96E"))
                        Text("YOUR YEAR IN REVIEW")
                            .font(.system(size: w * 0.026, weight: .semibold))
                            .tracking(w * 0.006)
                            .foregroundStyle(Color(hex: "F0EEE8").opacity(0.4))
                    }

                    Spacer().frame(height: h * 0.055)

                    // 2×2 grid
                    let gutter = w * 0.04
                    let cellW  = (w - gutter * 3) / 2

                    VStack(spacing: gutter) {
                        HStack(spacing: gutter) {
                            statCell(value: "\(thisYear.count)", label: "FLIGHTS\nTHIS YEAR", cellW: cellW)
                            statCell(value: yearKmLabel,         label: "KM\nFLOWN",        cellW: cellW)
                        }
                        HStack(spacing: gutter) {
                            statCell(value: "\(yearCountries)", label: "COUNTRIES\nTHIS YEAR", cellW: cellW)
                            statCell(value: "\(past.count)",    label: "TOTAL\nFLIGHTS",       cellW: cellW)
                        }
                    }
                    .padding(.horizontal, gutter)

                    Spacer()

                    Text("flygram.app")
                        .font(.system(size: w * 0.024, weight: .light))
                        .tracking(w * 0.005)
                        .foregroundStyle(Color(hex: "F0EEE8").opacity(0.18))
                        .padding(.bottom, h * 0.065)
                }
            }
        }
    }

    private func statCell(value: String, label: String, cellW: CGFloat) -> some View {
        VStack(spacing: cellW * 0.06) {
            Text(value)
                .font(.system(size: cellW * 0.22, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "C9A96E"))
            Text(label)
                .font(.system(size: cellW * 0.065, weight: .medium))
                .tracking(cellW * 0.004)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hex: "F0EEE8").opacity(0.38))
        }
        .frame(maxWidth: .infinity)
        .frame(height: cellW * 1.1)
        .background(Color(hex: "F0EEE8").opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: cellW * 0.1))
        .overlay(
            RoundedRectangle(cornerRadius: cellW * 0.1)
                .stroke(Color(hex: "C9A96E").opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Share Card Sheet

struct ShareCardSheet: View {
    let flights: [Flight]
    let airportService: AirportService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCard = 0

    private let cardW: CGFloat = 1080
    private let cardH: CGFloat = 1350
    private let previewW: CGFloat = 280

    private var previewH: CGFloat { previewW * (cardH / cardW) }

    private let cardLabels = ["Flight Map", "Countries Visited", "Top Routes", "Year in Review"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0A0A0F").ignoresSafeArea()

                VStack(spacing: 20) {
                    // Paging card previews
                    TabView(selection: $selectedCard) {
                        ForEach(0..<4, id: \.self) { i in
                            cardPreview(index: i)
                                .frame(width: previewW, height: previewH)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .shadow(color: Color(hex: "C9A96E").opacity(0.2), radius: 30)
                                .tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: previewH + 40)

                    // Page indicator dots
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { i in
                            Circle()
                                .fill(selectedCard == i
                                      ? Color(hex: "C9A96E")
                                      : Color.white.opacity(0.2))
                                .frame(width: 6, height: 6)
                                .animation(.easeInOut, value: selectedCard)
                        }
                    }

                    // Card name
                    Text(cardLabels[selectedCard])
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color(hex: "F0EEE8").opacity(0.4))
                        .animation(.easeInOut, value: selectedCard)

                    Spacer().frame(height: 4)

                    // Share button
                    Button(action: shareCurrentCard) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Share")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(Color(hex: "0A0A0F"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(hex: "C9A96E"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 24)
            }
            .navigationTitle("Share Your Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(hex: "C9A96E"))
                }
            }
        }
    }

    @ViewBuilder
    private func cardPreview(index: Int) -> some View {
        switch index {
        case 0: FlightMapShareCard(flights: flights, airportService: airportService)
        case 1: CountriesShareCard(flights: flights, airportService: airportService)
        case 2: TopRoutesShareCard(flights: flights, airportService: airportService)
        default: YearStatsShareCard(flights: flights, airportService: airportService)
        }
    }

    private func shareCurrentCard() {
        let renderer = ImageRenderer(content: fullResCard(index: selectedCard))
        renderer.scale = 2.0
        guard let image = renderer.uiImage else { return }

        let ac = UIActivityViewController(activityItems: [image], applicationActivities: nil)

        guard
            let scene  = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let window = scene.windows.first(where: { $0.isKeyWindow })
        else { return }

        var topVC = window.rootViewController
        while let next = topVC?.presentedViewController { topVC = next }
        topVC?.present(ac, animated: true)
    }

    @ViewBuilder
    private func fullResCard(index: Int) -> some View {
        switch index {
        case 0: FlightMapShareCard(flights: flights, airportService: airportService).frame(width: cardW, height: cardH)
        case 1: CountriesShareCard(flights: flights, airportService: airportService).frame(width: cardW, height: cardH)
        case 2: TopRoutesShareCard(flights: flights, airportService: airportService).frame(width: cardW, height: cardH)
        default: YearStatsShareCard(flights: flights, airportService: airportService).frame(width: cardW, height: cardH)
        }
    }
}
