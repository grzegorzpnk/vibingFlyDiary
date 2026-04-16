import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \Flight.date, order: .reverse) private var flights: [Flight]
    @Environment(AirportService.self) private var airportService
    @Environment(LocalizationService.self) private var ls

    // MARK: - Computed Stats

    private var past: [Flight] { flights.filter { $0.date <= .now } }

    private var totalKm: Double { past.reduce(0) { $0 + $1.distanceKm } }

    private var earthLaps: Double { totalKm / 40_075.0 }

    private var totalHours: Int {
        Int(past.reduce(0.0) { $0 + ($1.distanceKm / 850.0 + 0.5) })
    }

    private var visitedCountries: Set<String> {
        var s = Set<String>()
        for f in past {
            if let o = airportService.airport(for: f.originIATA)      { s.insert(o.country) }
            if let d = airportService.airport(for: f.destinationIATA) { s.insert(d.country) }
        }
        return s
    }

    private var visitedAirports: Set<String> {
        past.reduce(into: Set<String>()) {
            $0.insert($1.originIATA)
            $0.insert($1.destinationIATA)
        }
    }

    private var visitedContinents: Set<String> {
        Set(visitedCountries.compactMap { Self.continentMap[$0] })
    }

    private var longestFlight: Flight? { past.max { $0.distanceKm < $1.distanceKm } }
    private var shortestFlight: Flight? { past.min { $0.distanceKm < $1.distanceKm } }

    private var topAirline: (name: String, count: Int)? { topItem(past.compactMap { $0.airline }) }
    private var topAircraft: (name: String, count: Int)? { topItem(past.compactMap { $0.aircraftType }) }

    private var classBreakdown: [(label: String, icon: String, count: Int)] {
        let counts = Dictionary(grouping: past.compactMap { $0.flightClass }, by: { $0 }).mapValues { $0.count }
        return FlightClass.allCases.compactMap { cls in
            counts[cls].map { (ls.flightClassLabel(cls), cls.icon, $0) }
        }.sorted { $0.count > $1.count }
    }

    private var seatBreakdown: [(label: String, icon: String, count: Int)] {
        let counts = Dictionary(grouping: past.compactMap { $0.seatType }, by: { $0 }).mapValues { $0.count }
        return SeatType.allCases.compactMap { s in
            counts[s].map { (ls.seatTypeLabel(s), s.icon, $0) }
        }.sorted { $0.count > $1.count }
    }

    private var countryFlags: [String] {
        visitedCountries.sorted().compactMap { iso -> String? in
            let flag = iso.uppercased().unicodeScalars
                .compactMap { UnicodeScalar(127397 + $0.value) }
                .reduce("") { $0 + String($1) }
            return flag.isEmpty ? nil : flag
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            FDColor.black.ignoresSafeArea()
            if past.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        heroCard
                        vitalsGrid
                        recordsSection
                        if topAirline != nil || topAircraft != nil {
                            favoritesSection
                        }
                        if !classBreakdown.isEmpty || !seatBreakdown.isEmpty {
                            flyingStyleSection
                        }
                        worldSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 110)
                }
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            // Deep navy→purple gradient (from inspiration)
            LinearGradient(
                colors: [
                    Color(hex: "0d1a2a"),
                    Color(hex: "1a0f2e"),
                    Color(hex: "0a0a0f")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Blue glow ellipse (earth glow from inspiration)
            Ellipse()
                .fill(RadialGradient(
                    colors: [Color(hex: "4A7FA5").opacity(0.3), .clear],
                    center: .center, startRadius: 0, endRadius: 120
                ))
                .frame(width: 240, height: 100)
                .offset(x: 60, y: 30)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            // Content
            VStack(alignment: .leading, spacing: 0) {
                Text(ls.statsYourJourney)
                    .font(FDFont.ui(11, weight: .medium))
                    .foregroundStyle(FDColor.gold)
                    .tracking(2)
                    .padding(.bottom, 14)

                // Big distance in gold
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(ls.distanceUnit == .miles
                         ? Int(totalKm * 0.621371).formatted()
                         : Int(totalKm).formatted())
                        .font(FDFont.display(42, weight: .semibold))
                        .foregroundStyle(FDColor.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(ls.distanceUnit == .miles ? "MI" : "KM")
                        .font(FDFont.ui(13, weight: .medium))
                        .foregroundStyle(FDColor.gold.opacity(0.55))
                        .tracking(1)
                }

                Text("across \(past.count) \(ls.statsFlightsCount)")
                    .font(FDFont.ui(12))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .padding(.top, 5)

                if earthLaps >= 0.1 {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 11))
                        Text(String(format: "≈ %.1f× \(ls.statsAroundEarth)", earthLaps))
                            .font(FDFont.ui(12, weight: .medium))
                    }
                    .foregroundStyle(FDColor.gold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(FDColor.gold.opacity(0.12))
                    .overlay(Capsule().stroke(FDColor.gold.opacity(0.3), lineWidth: 1))
                    .clipShape(Capsule())
                    .padding(.top, 14)
                }
            }
            .padding(24)
        }
        .frame(height: 196)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(FDColor.gold.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Vitals Grid

    private var vitalsGrid: some View {
        let items: [(value: String, label: String, highlight: Bool)] = [
            ("\(past.count)",              ls.statsFlightsLabel,   false),
            ("\(visitedCountries.count)",  ls.statsCountriesLabel, true),
            ("\(visitedAirports.count)",   ls.statsAirportsLabel,  false),
            ("\(totalHours)\(ls.statsHoursShort)", ls.statsInTheAir, true),
        ]

        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                vitalCell(value: item.value, label: item.label, highlight: item.highlight)
            }
        }
    }

    private func vitalCell(value: String, label: String, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(FDFont.display(28, weight: .semibold))
                .foregroundStyle(highlight ? FDColor.gold : FDColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(FDFont.ui(10, weight: .medium))
                .foregroundStyle(FDColor.textMuted)
                .tracking(1.5)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack(alignment: .topLeading) {
                FDColor.surface2
                if highlight {
                    // Subtle gold top-left glow
                    RadialGradient(
                        colors: [FDColor.gold.opacity(0.08), .clear],
                        center: .topLeading, startRadius: 0, endRadius: 80
                    )
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(highlight ? FDColor.gold.opacity(0.25) : FDColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Records Section

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(ls.statsRecords)
            if let f = longestFlight {
                routeRecordCard(flight: f, label: ls.statsLongestFlight, accentColor: FDColor.gold)
            }
            if let f = shortestFlight, shortestFlight?.id != longestFlight?.id {
                routeRecordCard(flight: f, label: ls.statsShortestFlight, accentColor: FDColor.blue)
            }
        }
    }

    private func routeRecordCard(flight: Flight, label: String, accentColor: Color) -> some View {
        let origin = airportService.airport(for: flight.originIATA)
        let dest   = airportService.airport(for: flight.destinationIATA)

        return HStack(spacing: 0) {
            // Left accent strip (boarding-pass style)
            accentColor
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .padding(.vertical, 20)
                .padding(.leading, 16)

            VStack(alignment: .leading, spacing: 14) {
                Text(label)
                    .font(FDFont.ui(10, weight: .medium))
                    .foregroundStyle(FDColor.textDim)
                    .tracking(1.5)

                // Route
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(flight.originIATA)
                            .font(FDFont.display(24, weight: .semibold))
                            .foregroundStyle(FDColor.text)
                        Text(origin?.city ?? "")
                            .font(FDFont.ui(11))
                            .foregroundStyle(FDColor.textMuted)
                            .lineLimit(1)
                    }
                    Spacer()
                    // Route line with plane
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(LinearGradient(colors: [FDColor.border, accentColor.opacity(0.5)], startPoint: .leading, endPoint: .center))
                            .frame(height: 1)
                        Image(systemName: "airplane")
                            .font(.system(size: 12))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 6)
                        Rectangle()
                            .fill(LinearGradient(colors: [accentColor.opacity(0.5), FDColor.border], startPoint: .leading, endPoint: .trailing))
                            .frame(height: 1)
                    }
                    .frame(maxWidth: 80)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(flight.destinationIATA)
                            .font(FDFont.display(24, weight: .semibold))
                            .foregroundStyle(accentColor)
                        Text(dest?.city ?? "")
                            .font(FDFont.ui(11))
                            .foregroundStyle(FDColor.textMuted)
                            .lineLimit(1)
                    }
                }

                // Meta row
                HStack(spacing: 0) {
                    Text(ls.formatDistance(flight.distanceKm))
                        .font(FDFont.ui(13, weight: .semibold))
                        .foregroundStyle(FDColor.text)
                    if let airline = flight.airline {
                        Text(" · \(airline)")
                            .font(FDFont.ui(12))
                            .foregroundStyle(FDColor.textMuted)
                            .lineLimit(1)
                    }
                    Spacer()
                    if let fn = flight.flightNumber {
                        Text(fn)
                            .font(FDFont.ui(11, weight: .medium))
                            .foregroundStyle(accentColor.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(accentColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
        }
        .background(FDColor.surface2)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(FDColor.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Favorites Section

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(ls.statsFavorites)
            HStack(spacing: 10) {
                if let airline = topAirline {
                    favoriteCard(label: ls.statsTopAirline, icon: "airplane.circle.fill",
                                 value: airline.name, count: airline.count, color: FDColor.gold)
                }
                if let aircraft = topAircraft {
                    favoriteCard(label: ls.statsTopAircraft, icon: "airplane",
                                 value: aircraft.name, count: aircraft.count, color: FDColor.blue)
                }
            }
        }
    }

    private func favoriteCard(label: String, icon: String, value: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon badge
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.12))
                .clipShape(Circle())
                .overlay(Circle().stroke(color.opacity(0.25), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(FDFont.ui(10, weight: .medium))
                    .foregroundStyle(FDColor.textDim)
                    .tracking(1.2)
                Text(value)
                    .font(FDFont.ui(13, weight: .medium))
                    .foregroundStyle(FDColor.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("\(count) \(ls.statsFlightsCount)")
                .font(FDFont.ui(11, weight: .medium))
                .foregroundStyle(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack(alignment: .topTrailing) {
                FDColor.surface2
                RadialGradient(
                    colors: [color.opacity(0.07), .clear],
                    center: .topTrailing, startRadius: 0, endRadius: 100
                )
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Flying Style Section

    private var flyingStyleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(ls.statsFlyingStyle)

            if !classBreakdown.isEmpty {
                styleBreakdownCard(
                    title: ls.statsClassBreakdown,
                    items: classBreakdown,
                    total: classBreakdown.reduce(0) { $0 + $1.count },
                    barColor: FDColor.gold
                )
            }
            if !seatBreakdown.isEmpty {
                styleBreakdownCard(
                    title: ls.statsSeatPreference,
                    items: seatBreakdown,
                    total: seatBreakdown.reduce(0) { $0 + $1.count },
                    barColor: FDColor.blue
                )
            }
        }
    }

    private func styleBreakdownCard(
        title: String,
        items: [(label: String, icon: String, count: Int)],
        total: Int,
        barColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(FDFont.ui(10, weight: .medium))
                .foregroundStyle(FDColor.textDim)
                .tracking(1.5)

            VStack(spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 11))
                            .foregroundStyle(barColor)
                            .frame(width: 18)
                        Text(item.label)
                            .font(FDFont.ui(12))
                            .foregroundStyle(FDColor.text)
                            .frame(width: 88, alignment: .leading)

                        // Gradient bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(FDColor.surface3)
                                    .frame(height: 7)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(
                                        colors: [barColor, barColor.opacity(0.5)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .frame(
                                        width: max(7, geo.size.width * CGFloat(item.count) / CGFloat(total)),
                                        height: 7
                                    )
                            }
                        }
                        .frame(height: 7)

                        Text("\(item.count)")
                            .font(FDFont.ui(11, weight: .medium))
                            .foregroundStyle(barColor.opacity(0.8))
                            .frame(width: 22, alignment: .trailing)
                    }
                }
            }
        }
        .padding(20)
        .background(FDColor.surface2)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - World Section

    private var worldSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(ls.statsWorldCoverage)

            ZStack(alignment: .bottomTrailing) {
                // Background with blue glow
                FDColor.surface2

                RadialGradient(
                    colors: [Color(hex: "4A7FA5").opacity(0.12), .clear],
                    center: .bottomTrailing, startRadius: 0, endRadius: 160
                )

                VStack(alignment: .leading, spacing: 16) {
                    // Big counts
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(visitedContinents.count)")
                                .font(FDFont.display(28, weight: .semibold))
                                .foregroundStyle(FDColor.blue)
                            Text(ls.statsContinents.uppercased())
                                .font(FDFont.ui(10, weight: .medium))
                                .foregroundStyle(FDColor.textDim)
                                .tracking(1.5)
                        }
                        Rectangle()
                            .fill(FDColor.border)
                            .frame(width: 1, height: 36)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(visitedCountries.count)")
                                .font(FDFont.display(28, weight: .semibold))
                                .foregroundStyle(FDColor.text)
                            Text(ls.statsCountriesLabel)
                                .font(FDFont.ui(10, weight: .medium))
                                .foregroundStyle(FDColor.textDim)
                                .tracking(1.5)
                        }
                    }

                    // Flag strip
                    if !countryFlags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(countryFlags, id: \.self) { flag in
                                    Text(flag)
                                        .font(.system(size: 22))
                                }
                            }
                        }
                    }

                    // Continent tags — blue accent
                    FlowLayout(spacing: 8) {
                        ForEach(visitedContinents.sorted(), id: \.self) { continent in
                            Text(continent)
                                .font(FDFont.ui(12, weight: .medium))
                                .foregroundStyle(FDColor.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(FDColor.blue.opacity(0.1))
                                .overlay(Capsule().stroke(FDColor.blue.opacity(0.35), lineWidth: 1))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(20)
            }
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "4A7FA5").opacity(0.25), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(FDColor.gold.opacity(0.5))
            Text(ls.tabStats)
                .font(FDFont.display(22, weight: .bold))
                .foregroundStyle(FDColor.text)
            Text(ls.statsComingSoon)
                .font(FDFont.ui(13))
                .foregroundStyle(FDColor.textMuted)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(FDColor.gold)
                .frame(width: 2, height: 10)
                .clipShape(Capsule())
            Text(title)
                .font(FDFont.ui(11, weight: .medium))
                .foregroundStyle(FDColor.textMuted)
                .tracking(1.5)
        }
        .padding(.top, 6)
    }

    private func topItem(_ items: [String]) -> (name: String, count: Int)? {
        guard !items.isEmpty else { return nil }
        let counts = Dictionary(grouping: items, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value }).map { ($0.key, $0.value) }
    }

    // MARK: - Continent Map

    private static let continentMap: [String: String] = {
        var m: [String: String] = [:]
        for c in ["GB","FR","DE","IT","ES","NL","BE","CH","AT","PL","PT","SE","NO","DK",
                  "FI","GR","CZ","HU","RO","BG","HR","SK","SI","RS","IE","LU","LT","LV",
                  "EE","IS","AL","MK","BA","ME","MT","CY","MD","UA","BY","RU","TR"] { m[c] = "Europe" }
        for c in ["JP","CN","IN","SG","TH","MY","ID","PH","VN","KR","HK","TW","AE","SA",
                  "QA","KW","BH","OM","IL","JO","LB","IQ","IR","PK","BD","LK","NP","MM",
                  "KH","LA","MN","KZ","UZ","GE","AM","AZ","MV","BT","TM","TJ","KG"] { m[c] = "Asia" }
        for c in ["US","CA","MX","BR","AR","CL","CO","PE","VE","EC","BO","PY","UY","GY",
                  "SR","CU","DO","PR","JM","TT","HT","GT","HN","SV","NI","CR","PA","BS",
                  "BB","BZ","LC","VC","GD","AG","DM","KN"] { m[c] = "Americas" }
        for c in ["ZA","EG","MA","TN","DZ","NG","KE","ET","TZ","GH","SN","CI","CM","AO",
                  "MZ","ZM","ZW","MU","RW","UG","LY","SD","SO","MG","BW"] { m[c] = "Africa" }
        for c in ["AU","NZ","FJ","PG","SB","VU","WS","TO","NR","KI"]       { m[c] = "Oceania" }
        return m
    }()
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let h = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }
            .reduce(0) { $0 + $1 + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: max(h, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in computeRows(proposal: proposal, subviews: subviews) {
            var x = bounds.minX
            let rowH = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for view in row {
                let size = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowH + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        let maxW = proposal.width ?? .infinity
        for view in subviews {
            let w = view.sizeThatFits(.unspecified).width
            if x + w > maxW && !rows.last!.isEmpty { rows.append([]); x = 0 }
            rows[rows.count - 1].append(view)
            x += w + spacing
        }
        return rows
    }
}
