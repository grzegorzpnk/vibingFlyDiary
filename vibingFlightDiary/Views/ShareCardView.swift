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
    //
    // Equirectangular, cropped to lat -60…+84 so Antarctica is trimmed
    // and inhabited continents fill more of the frame.
    // The map rect preserves the correct 360/(84+60) = 2.5:1 aspect ratio,
    // centred vertically with a slight upward shift to leave room for stats.

    private let minLat = -60.0
    private let maxLat =  84.0

    private func mapRect(in size: CGSize) -> CGRect {
        let lonRange = 360.0
        let latRange = maxLat - minLat          // 144°
        let aspect   = lonRange / latRange       // ≈ 2.5
        let mapW     = size.width
        let mapH     = mapW / aspect
        // shift map slightly toward top (40 % of remaining vertical space above)
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
                path.move(to: pt) // anti-meridian — lift pen
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

    // MARK: - Canvas: Arcs

    private func drawArcs(ctx: GraphicsContext, size: CGSize) {
        let glowW  = max(0.8, size.width * 0.003)
        let solidW = max(0.4, size.width * 0.001)

        for flight in past {
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

// MARK: - Share Sheet

struct ShareCardSheet: View {
    let flights: [Flight]
    let airportService: AirportService
    @Environment(\.dismiss) private var dismiss

    // 4:5 portrait ratio — ideal for Instagram
    private let cardW: CGFloat = 1080
    private let cardH: CGFloat = 1350

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0A0A0F").ignoresSafeArea()

                VStack(spacing: 28) {
                    // Live preview
                    let previewW: CGFloat = 280
                    let previewH: CGFloat = previewW * (cardH / cardW)

                    FlightMapShareCard(flights: flights, airportService: airportService)
                        .frame(width: previewW, height: previewH)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: Color(hex: "C9A96E").opacity(0.2), radius: 30)

                    Text("Your route map — ready to share")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color(hex: "F0EEE8").opacity(0.4))

                    Button(action: shareImage) {
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
                .padding(.top, 32)
            }
            .navigationTitle("Share Your Routes")
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

    private func shareImage() {
        // Render at full resolution off-screen
        let card = FlightMapShareCard(flights: flights, airportService: airportService)
            .frame(width: cardW, height: cardH)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0   // → 2160 × 2700 px
        guard let image = renderer.uiImage else { return }

        let ac = UIActivityViewController(activityItems: [image], applicationActivities: nil)

        // Walk up the presenter chain — ShareCardSheet itself is already presented,
        // so rootViewController.presentedViewController is this sheet's nav stack.
        guard
            let scene  = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let window = scene.windows.first(where: { $0.isKeyWindow })
        else { return }

        var topVC = window.rootViewController
        while let next = topVC?.presentedViewController { topVC = next }
        topVC?.present(ac, animated: true)
    }
}
