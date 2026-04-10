import SwiftUI

struct FlightDetailView: View {
    let flight: Flight
    let airportService: AirportService

    @Environment(\.dismiss) private var dismiss

    private var origin: Airport? { airportService.airport(for: flight.originIATA) }
    private var dest: Airport?   { airportService.airport(for: flight.destinationIATA) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            FDColor.surface.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    routeHeader
                    Divider().background(FDColor.border).padding(.horizontal, 24)
                    metaSection
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    // MARK: - Route Header

    private var routeHeader: some View {
        VStack(spacing: 0) {
            // Decorative arc
            RouteArcView()
                .frame(height: 80)
                .padding(.top, 32)

            // IATA codes
            HStack(alignment: .top) {
                // Origin
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

                // Plane icon center
                Image(systemName: "airplane")
                    .font(.system(size: 18))
                    .foregroundStyle(FDColor.gold)
                    .padding(.top, 12)

                // Destination
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
            .padding(.bottom, 28)
        }
    }

    // MARK: - Meta Section

    private var metaSection: some View {
        HStack(spacing: 0) {
            metaCell(
                label: "DATE",
                value: flight.date.formatted(date: .long, time: .omitted)
            )

            Rectangle()
                .fill(FDColor.border)
                .frame(width: 1)
                .padding(.vertical, 16)

            metaCell(
                label: "DISTANCE",
                value: "\(Int(flight.distanceKm).formatted()) km"
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
            Text(value)
                .font(FDFont.ui(15, weight: .medium))
                .foregroundStyle(FDColor.text)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Airport Detail Section

    private var airportSection: some View {
        VStack(spacing: 0) {
            if let o = origin {
                airportRow(label: "ORIGIN", airport: o)
                Divider().background(FDColor.border).padding(.horizontal, 24)
            }
            if let d = dest {
                airportRow(label: "DESTINATION", airport: d)
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
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            // Dashed arc
            var arc = Path()
            arc.move(to: CGPoint(x: w * 0.12, y: h * 0.85))
            arc.addQuadCurve(
                to: CGPoint(x: w * 0.88, y: h * 0.85),
                control: CGPoint(x: w * 0.50, y: -h * 0.20)
            )
            ctx.stroke(arc,
                       with: .color(Color(hex: "C9A96E").opacity(0.4)),
                       style: StrokeStyle(lineWidth: 1.5, dash: [5, 6]))

            // Endpoint dots
            let r: Double = 4
            func dot(_ x: Double, _ y: Double) {
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r*2, height: r*2)),
                         with: .color(Color(hex: "C9A96E").opacity(0.85)))
            }
            dot(w * 0.12, h * 0.85)
            dot(w * 0.88, h * 0.85)
        }
    }
}
