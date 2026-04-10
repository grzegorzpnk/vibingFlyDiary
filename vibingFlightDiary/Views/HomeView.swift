import SwiftUI
import SwiftData

// MARK: - Home Screen

struct HomeView: View {
    var onViewAll: () -> Void = {}

    @Query(sort: \Flight.date, order: .reverse) private var flights: [Flight]
    @Environment(AirportService.self) private var airportService

    @State private var selectedFlight: Flight?
    private let previewCount = 3

    var body: some View {
        ZStack {
            FDColor.black.ignoresSafeArea()

            VStack(spacing: 0) {
                heroSection

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        if !flights.isEmpty {
                            statsRow
                                .padding(.top, 20)
                        }

                        HStack {
                            Text("RECENT FLIGHTS")
                                .font(FDFont.ui(11, weight: .medium))
                                .foregroundStyle(FDColor.textMuted)
                                .tracking(1.5)
                            Spacer()
                            if flights.count > previewCount {
                                Button(action: onViewAll) {
                                    Text("History →")
                                        .font(FDFont.ui(12, weight: .medium))
                                        .foregroundStyle(FDColor.gold)
                                }
                            }
                        }
                        .padding(.top, flights.isEmpty ? 24 : 16)

                        if flights.isEmpty {
                            emptyState
                        } else {
                            ForEach(flights.prefix(previewCount)) { flight in
                                FlightCard(flight: flight, airportService: airportService) {
                                    selectedFlight = flight
                                }
                            }

                            if flights.count > previewCount {
                                Button(action: onViewAll) {
                                    HStack {
                                        Text("All \(flights.count) flights")
                                            .font(FDFont.ui(14, weight: .medium))
                                            .foregroundStyle(FDColor.textMuted)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(FDColor.gold)
                                    }
                                    .padding(16)
                                    .background(FDColor.surface2)
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(FDColor.border, lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 110)
                }
                .background(FDColor.black)
            }
        }
        .sheet(item: $selectedFlight) { flight in
            FlightDetailView(flight: flight, airportService: airportService)
        }
    }

    // MARK: Hero

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.10, blue: 0.17),
                    Color(red: 0.10, green: 0.06, blue: 0.18),
                    FDColor.black
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea(edges: .top)

            StarsView()

            Ellipse()
                .fill(RadialGradient(
                    colors: [FDColor.blue.opacity(0.22), .clear],
                    center: .center, startRadius: 0, endRadius: 140
                ))
                .frame(width: 280, height: 140)
                .offset(y: 50)
                .frame(maxWidth: .infinity, alignment: .center)

            HeroArcsView()

            VStack(alignment: .leading, spacing: 6) {
                Text("✦ FLIGHT DIARY")
                    .font(FDFont.ui(11, weight: .medium))
                    .foregroundStyle(FDColor.gold)
                    .tracking(2.5)

                Text("Your\nFlight Diary")
                    .font(FDFont.display(36, weight: .bold))
                    .foregroundStyle(FDColor.text)
                    .lineSpacing(4)

                if !flights.isEmpty {
                    Text("\(flights.count) flight\(flights.count == 1 ? "" : "s") across \(allCountries) \(allCountries == 1 ? "country" : "countries")")
                        .font(FDFont.ui(13))
                        .foregroundStyle(FDColor.textMuted)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(height: 310)
        .clipped()
    }

    // MARK: - Stats

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }

    private var thisYearFlights: [Flight] {
        flights.filter { Calendar.current.component(.year, from: $0.date) == currentYear }
    }

    private var thisYearKm: Int { Int(thisYearFlights.reduce(0) { $0 + $1.distanceKm }) }

    private var thisYearCountries: Int {
        var codes = Set<String>()
        for flight in thisYearFlights {
            if let o = airportService.airport(for: flight.originIATA) { codes.insert(o.country) }
            if let d = airportService.airport(for: flight.destinationIATA) { codes.insert(d.country) }
        }
        return codes.count
    }

    private var allCountries: Int {
        var codes = Set<String>()
        for flight in flights {
            if let o = airportService.airport(for: flight.originIATA) { codes.insert(o.country) }
            if let d = airportService.airport(for: flight.destinationIATA) { codes.insert(d.country) }
        }
        return codes.count
    }

    private var statsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THIS YEAR")
                .font(FDFont.ui(11, weight: .medium))
                .foregroundStyle(FDColor.textMuted)
                .tracking(1.5)
            HStack(spacing: 10) {
                statCard(value: "\(thisYearFlights.count)", label: "Flights", highlight: false)
                statCard(value: thisYearKm >= 1000 ? "\(thisYearKm / 1000)k" : "\(thisYearKm)", label: "Km Flown", highlight: true)
                statCard(value: "\(thisYearCountries)", label: "Countries", highlight: false)
            }
        }
    }

    private func statCard(value: String, label: String, highlight: Bool) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(FDFont.display(22, weight: .bold))
                .foregroundStyle(highlight ? FDColor.gold : FDColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(FDFont.ui(10, weight: .medium))
                .foregroundStyle(FDColor.textMuted)
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(FDColor.surface2)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "airplane")
                .font(.system(size: 40))
                .foregroundStyle(FDColor.textDim)
                .padding(.bottom, 4)
            Text("No flights yet")
                .font(FDFont.display(20))
                .foregroundStyle(FDColor.text)
            Text("Tap Add below to log your first flight.")
                .font(FDFont.ui(13))
                .foregroundStyle(FDColor.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Flight Card (shared)

struct FlightCard: View {
    let flight: Flight
    let airportService: AirportService
    var onTap: (() -> Void)? = nil

    private var origin: Airport? { airportService.airport(for: flight.originIATA) }
    private var dest: Airport?   { airportService.airport(for: flight.destinationIATA) }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(flight.flightClass == .business || flight.flightClass == .first ? FDColor.blue : FDColor.gold)
                    .frame(width: 6, height: 6)
                    .padding(.top, 2)
                    .alignmentGuide(.top) { d in d[.top] }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(flight.originIATA)
                            .font(FDFont.display(18, weight: .bold))
                            .foregroundStyle(FDColor.text)

                        ZStack {
                            Rectangle()
                                .fill(FDColor.borderBright)
                                .frame(height: 1)
                            Text("✈")
                                .font(.system(size: 10))
                                .foregroundStyle(FDColor.gold)
                        }
                        .frame(maxWidth: .infinity)

                        Text(flight.destinationIATA)
                            .font(FDFont.display(18, weight: .bold))
                            .foregroundStyle(FDColor.text)
                    }

                    if let o = origin, let d = dest {
                        Text("\(o.city) → \(d.city)")
                            .font(FDFont.ui(11))
                            .foregroundStyle(FDColor.textMuted)
                    }

                    HStack(spacing: 6) {
                        if let airline = flight.airline {
                            Text(airline)
                            Text("·")
                        }
                        if let cls = flight.flightClass {
                            Text(cls.label)
                            Text("·")
                        }
                        Text(flight.estimatedDurationFormatted)
                    }
                    .font(FDFont.ui(10))
                    .foregroundStyle(FDColor.textDim)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(flight.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(FDFont.ui(11, weight: .medium))
                        .foregroundStyle(FDColor.textDim)
                    Text(flight.date.formatted(.dateTime.year()))
                        .font(FDFont.ui(11))
                        .foregroundStyle(FDColor.textDim)
                }
            }
            .padding(16)
            .background(FDColor.surface2)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(FDColor.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stars Canvas

struct StarsView: View {
    private let stars: [(Double, Double, Double)] = [
        (0.20, 0.28, 1.0), (0.80, 0.14, 1.0), (0.45, 0.58, 1.4),
        (0.65, 0.22, 1.0), (0.30, 0.68, 0.9), (0.90, 0.48, 1.0),
        (0.10, 0.48, 0.9), (0.55, 0.78, 0.9), (0.72, 0.42, 0.8),
        (0.15, 0.18, 0.8), (0.85, 0.72, 0.8), (0.40, 0.12, 1.2),
        (0.60, 0.52, 0.8), (0.25, 0.42, 0.9), (0.78, 0.28, 0.8)
    ]

    var body: some View {
        Canvas { ctx, size in
            for (x, y, r) in stars {
                let cx = x * size.width
                let cy = y * size.height
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.5)))
            }
        }
    }
}

// MARK: - Hero Arcs Canvas

struct HeroArcsView: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            var p1 = Path()
            p1.move(to: CGPoint(x: w * 0.16, y: h * 0.82))
            p1.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.52),
                            control: CGPoint(x: w * 0.35, y: h * 0.18))
            ctx.stroke(p1, with: .color(Color(hex: "C9A96E").opacity(0.35)),
                       style: StrokeStyle(lineWidth: 1, dash: [4, 6]))

            let dotRadius: Double = 3
            func dot(_ px: Double, _ py: Double) {
                let r = CGRect(x: px - dotRadius, y: py - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                ctx.fill(Path(ellipseIn: r), with: .color(Color(hex: "C9A96E").opacity(0.9)))
            }
            dot(w * 0.16, h * 0.82)
            dot(w * 0.78, h * 0.52)

            var p2 = Path()
            p2.move(to: CGPoint(x: w * 0.08, y: h * 0.65))
            p2.addQuadCurve(to: CGPoint(x: w * 0.92, y: h * 0.38),
                            control: CGPoint(x: w * 0.52, y: h * 0.08))
            ctx.stroke(p2, with: .color(Color(hex: "4A7FA5").opacity(0.20)),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 8]))

            var p3 = Path()
            p3.move(to: CGPoint(x: w * 0.22, y: h * 0.88))
            p3.addQuadCurve(to: CGPoint(x: w * 0.84, y: h * 0.68),
                            control: CGPoint(x: w * 0.44, y: h * 0.48))
            ctx.stroke(p3, with: .color(Color.white.opacity(0.07)),
                       style: StrokeStyle(lineWidth: 0.5, dash: [2, 10]))
        }
    }
}
