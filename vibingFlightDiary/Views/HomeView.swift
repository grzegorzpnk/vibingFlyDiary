import SwiftUI
import SwiftData

// MARK: - Home Screen

struct HomeView: View {
    var onViewAll: () -> Void = {}
    var onViewStats: () -> Void = {}

    @Query(sort: \Flight.date, order: .reverse) private var flights: [Flight]
    @Environment(AirportService.self) private var airportService

    @State private var selectedFlight: Flight?
    @State private var showSettings = false
    @Environment(LocalizationService.self) private var ls
    private let previewCount = 3

    private var upcomingFlights: [Flight] {
        flights.filter { $0.date > .now }.reversed()
    }

    private var pastFlights: [Flight] {
        flights.filter { $0.date <= .now }
    }

    var body: some View {
        ZStack {
            FDColor.black.ignoresSafeArea()

            VStack(spacing: 0) {
                heroSection

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        if !pastFlights.isEmpty {
                            HStack {
                                Text(ls.thisYear)
                                    .font(FDFont.ui(11, weight: .medium))
                                    .foregroundStyle(FDColor.textMuted)
                                    .tracking(1.5)
                                Spacer()
                                Button(action: onViewStats) {
                                    Text(ls.statsArrow)
                                        .font(FDFont.ui(12, weight: .medium))
                                        .foregroundStyle(FDColor.gold)
                                }
                            }
                            .padding(.top, 20)
                            statsRow
                        }

                        // Upcoming flights section
                        if !upcomingFlights.isEmpty {
                            Text(ls.upcomingFlights)
                                .font(FDFont.ui(11, weight: .medium))
                                .foregroundStyle(FDColor.gold)
                                .tracking(1.5)
                                .padding(.top, 16)

                            ForEach(upcomingFlights) { flight in
                                FlightCard(flight: flight, airportService: airportService, onTap: {
                                    selectedFlight = flight
                                }, isUpcoming: true)
                            }
                        }

                        HStack {
                            Text(ls.recentFlights)
                                .font(FDFont.ui(11, weight: .medium))
                                .foregroundStyle(FDColor.textMuted)
                                .tracking(1.5)
                            Spacer()
                            if pastFlights.count > previewCount {
                                Button(action: onViewAll) {
                                    Text(ls.historyArrow)
                                        .font(FDFont.ui(12, weight: .medium))
                                        .foregroundStyle(FDColor.gold)
                                }
                            }
                        }
                        .padding(.top, flights.isEmpty ? 24 : 16)

                        if pastFlights.isEmpty && upcomingFlights.isEmpty {
                            emptyState
                        } else if pastFlights.isEmpty {
                            // Only upcoming flights exist — show a hint
                            Text(ls.pastFlightsHint)
                                .font(FDFont.ui(13))
                                .foregroundStyle(FDColor.textDim)
                                .padding(.vertical, 16)
                        } else {
                            ForEach(pastFlights.prefix(previewCount)) { flight in
                                FlightCard(flight: flight, airportService: airportService) {
                                    selectedFlight = flight
                                }
                            }

                            if pastFlights.count > previewCount {
                                Button(action: onViewAll) {
                                    HStack {
                                        Text(ls.allFlightsCount(pastFlights.count))
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: Hero

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Settings button top-right
            Button { showSettings = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(FDColor.text.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 12)
            .padding(.trailing, 20)
            .zIndex(1)
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
                Text("✦ FLYGRAM") // app name — not translated
                    .font(FDFont.ui(11, weight: .medium))
                    .foregroundStyle(FDColor.gold)
                    .tracking(2.5)

                Text(ls.heroTitle)
                    .font(FDFont.display(36, weight: .bold))
                    .foregroundStyle(FDColor.text)
                    .lineSpacing(4)

                if !pastFlights.isEmpty {
                    Text("\(pastFlights.count) flight\(pastFlights.count == 1 ? "" : "s") across \(allCountries) \(allCountries == 1 ? "country" : "countries")")
                        .font(FDFont.ui(13))
                        .foregroundStyle(FDColor.textMuted)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(height: 250)
        .clipped()
    }

    // MARK: - Stats

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }

    private var thisYearFlights: [Flight] {
        flights.filter { $0.date <= .now && Calendar.current.component(.year, from: $0.date) == currentYear }
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
        for flight in pastFlights {
            if let o = airportService.airport(for: flight.originIATA) { codes.insert(o.country) }
            if let d = airportService.airport(for: flight.destinationIATA) { codes.insert(d.country) }
        }
        return codes.count
    }

    private var statsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                statCard(value: "\(thisYearFlights.count)", label: ls.flightsStatLabel, highlight: false)
                statCard(value: thisYearKm >= 1000 ? "\(thisYearKm / 1000)k" : "\(thisYearKm)", label: ls.kmFlownLabel, highlight: true)
                statCard(value: "\(thisYearCountries)", label: ls.countriesLabel, highlight: false)
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
            Text(ls.noFlightsTitle)
                .font(FDFont.display(20))
                .foregroundStyle(FDColor.text)
            Text(ls.noFlightsSub)
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
    var isUpcoming: Bool = false

    private var origin: Airport? { airportService.airport(for: flight.originIATA) }
    private var dest: Airport?   { airportService.airport(for: flight.destinationIATA) }

    private var daysUntil: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: flight.date)
        ).day ?? 0
    }

    private var countdownText: String {
        switch daysUntil {
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(daysUntil)d"
        }
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        // Flag at card left edge, inline with route
                        HStack(spacing: 4) {
                            if let o = origin {
                                Text(o.flagEmoji)
                                    .font(.system(size: 14))
                            }
                            Text(flight.originIATA)
                                .font(FDFont.display(18, weight: .bold))
                                .foregroundStyle(FDColor.text)
                        }

                        ZStack {
                            Rectangle()
                                .fill(FDColor.borderBright)
                                .frame(height: 1)
                            Text("✈")
                                .font(.system(size: 10))
                                .foregroundStyle(isUpcoming ? FDColor.blue : FDColor.gold)
                        }
                        .frame(maxWidth: .infinity)

                        HStack(spacing: 3) {
                            Text(flight.destinationIATA)
                                .font(FDFont.display(18, weight: .bold))
                                .foregroundStyle(FDColor.text)
                            if let d = dest {
                                Text(d.flagEmoji)
                                    .font(.system(size: 14))
                            }
                        }
                    }

                    if let o = origin, let d = dest {
                        HStack(spacing: 5) {
                            if isUpcoming {
                                Image(systemName: "airplane.departure")
                                    .font(.system(size: 8))
                                    .foregroundStyle(FDColor.blue)
                            } else {
                                Circle()
                                    .fill(flight.flightClass == .business || flight.flightClass == .first ? FDColor.blue : FDColor.gold)
                                    .frame(width: 5, height: 5)
                            }
                            Text("\(o.city) → \(d.city)")
                                .font(FDFont.ui(11))
                                .foregroundStyle(FDColor.textMuted)
                        }
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
                    if isUpcoming {
                        Text(countdownText)
                            .font(FDFont.ui(11, weight: .medium))
                            .foregroundStyle(FDColor.gold)
                        Text(flight.date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(FDFont.ui(11))
                            .foregroundStyle(FDColor.textDim)
                    } else {
                        Text(flight.date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(FDFont.ui(11, weight: .medium))
                            .foregroundStyle(FDColor.textDim)
                        Text(flight.date.formatted(.dateTime.year()))
                            .font(FDFont.ui(11))
                            .foregroundStyle(FDColor.textDim)
                    }
                }
            }
            .padding(16)
            .background(
                ZStack {
                    FDColor.surface2
                    if isUpcoming { FDColor.blue.opacity(0.05) }
                }
            )
            .overlay {
                if isUpcoming {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(FDColor.gold.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                } else {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(FDColor.border, lineWidth: 1)
                }
            }
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
