import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \Flight.date, order: .reverse) private var flights: [Flight]
    @Environment(AirportService.self) private var airportService
    @Environment(LocalizationService.self) private var ls
    @Environment(\.colorScheme) private var colorScheme

    @State private var animateCharts = false
    @State private var showShareCard = false

    private var isLight: Bool {
        switch ls.theme {
        case .light:  return true
        case .dark:   return false
        case .system: return colorScheme == .light
        }
    }

    // MARK: - Computed Stats

    private var past: [Flight] { flights.filter { $0.date <= .now } }
    private var upcoming: [Flight] { flights.filter { $0.date > .now } }
    private var totalKm: Double { past.reduce(0) { $0 + $1.distanceKm } }
    private var earthLaps: Double { totalKm / 40_075.0 }
    private var moonTrips: Double { totalKm / 384_400.0 }

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

    private var flightsWithAirline: Int  { past.filter { $0.airline != nil }.count }
    private var flightsWithAircraft: Int { past.filter { $0.aircraftType != nil }.count }
    private var flightsWithClass: Int    { past.filter { $0.flightClass != nil }.count }
    private var flightsWithSeat: Int     { past.filter { $0.seatType != nil }.count }

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

    private var domesticCount: Int {
        past.filter { f in
            guard let o = airportService.airport(for: f.originIATA),
                  let d = airportService.airport(for: f.destinationIATA) else { return false }
            return o.country == d.country
        }.count
    }

    private var internationalCount: Int { past.count - domesticCount }

    private var countryFlags: [String] {
        visitedCountries.sorted().compactMap { iso -> String? in
            let flag = iso.uppercased().unicodeScalars
                .compactMap { UnicodeScalar(127397 + $0.value) }
                .reduce("") { $0 + String($1) }
            return flag.isEmpty ? nil : flag
        }
    }

    // MARK: - Flights Deep-Dive

    private var flightsByYear: [(year: Int, count: Int)] {
        let grouped = Dictionary(grouping: past) { Calendar.current.component(.year, from: $0.date) }
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.0 < $1.0 }
    }

    private var busiestMonth: (name: String, count: Int)? {
        let grouped = Dictionary(grouping: past) { Calendar.current.component(.month, from: $0.date) }
        guard let best = grouped.max(by: { $0.value.count < $1.value.count }) else { return nil }
        return (Calendar.current.monthSymbols[best.key - 1], best.value.count)
    }

    private var avgPerMonth: Double {
        guard past.count > 1,
              let first = past.min(by: { $0.date < $1.date }),
              let last  = past.max(by: { $0.date < $1.date }) else { return Double(past.count) }
        let months = max(1, Calendar.current.dateComponents([.month], from: first.date, to: last.date).month ?? 1)
        return Double(past.count) / Double(months)
    }

    private var avgPerYear: Double {
        guard past.count > 1,
              let first = past.min(by: { $0.date < $1.date }),
              let last  = past.max(by: { $0.date < $1.date }) else { return Double(past.count) }
        let years = Calendar.current.dateComponents([.year], from: first.date, to: last.date).year ?? 0
        return years > 0 ? Double(past.count) / Double(years) : Double(past.count)
    }

    private var longestStreak: Int {
        let cal = Calendar.current
        let monthKeys = Set(past.map { f -> String in
            let c = cal.dateComponents([.year, .month], from: f.date)
            return "\(c.year!)-\(String(format: "%02d", c.month!))"
        }).sorted()
        let dates: [Date] = monthKeys.compactMap { s in
            let parts = s.split(separator: "-")
            guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]) else { return nil }
            return cal.date(from: DateComponents(year: y, month: m, day: 1))
        }
        guard !dates.isEmpty else { return 0 }
        var maxS = 1, cur = 1
        for i in 1..<dates.count {
            let diff = cal.dateComponents([.month], from: dates[i - 1], to: dates[i]).month ?? 0
            cur = diff == 1 ? cur + 1 : 1
            maxS = max(maxS, cur)
        }
        return maxS
    }

    // MARK: - Countries Deep-Dive

    private var countryFlagPairs: [(iso: String, flag: String)] {
        visitedCountries.sorted().compactMap { iso -> (String, String)? in
            let flag = iso.uppercased().unicodeScalars
                .compactMap { UnicodeScalar(127397 + $0.value) }
                .reduce("") { $0 + String($1) }
            return flag.isEmpty ? nil : (iso, flag)
        }
    }

    private var continentBreakdown: [(continent: String, count: Int)] {
        var counts: [String: Int] = [:]
        for iso in visitedCountries {
            if let continent = Self.continentMap[iso] { counts[continent, default: 0] += 1 }
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.count > $1.count }
    }

    private var topCountries: [(iso: String, flag: String, name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for f in past {
            if let o = airportService.airport(for: f.originIATA)      { counts[o.country, default: 0] += 1 }
            if let d = airportService.airport(for: f.destinationIATA) { counts[d.country, default: 0] += 1 }
        }
        let locale = Locale(identifier: ls.language.rawValue)
        return counts.sorted { $0.value > $1.value }
            .prefix(5)
            .compactMap { iso, count -> (String, String, String, Int)? in
                let flag = iso.uppercased().unicodeScalars
                    .compactMap { UnicodeScalar(127397 + $0.value) }
                    .reduce("") { $0 + String($1) }
                let name = locale.localizedString(forRegionCode: iso) ?? iso
                return (iso, flag, name, count)
            }
    }

    private var totalCountries: Int { CountryShapeService.shared.shapes.count }
    private var countryProgress: Double {
        totalCountries > 0 ? Double(visitedCountries.count) / Double(totalCountries) : 0
    }

    // MARK: - Airports Deep-Dive

    private var topAirportsList: [(airport: Airport, count: Int)] {
        var counts: [String: Int] = [:]
        for f in past {
            counts[f.originIATA, default: 0] += 1
            counts[f.destinationIATA, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }
            .prefix(8)
            .compactMap { iata, count in airportService.airport(for: iata).map { ($0, count) } }
    }

    // MARK: - Hours Deep-Dive

    private var avgHoursPerFlight: Double {
        guard !past.isEmpty else { return 0 }
        return Double(totalHours) / Double(past.count)
    }

    private var hoursByYear: [(year: Int, hours: Int)] {
        let grouped = Dictionary(grouping: past) { Calendar.current.component(.year, from: $0.date) }
        return grouped.map { year, flights in
            let h = Int(flights.reduce(0.0) { $0 + ($1.distanceKm / 850.0 + 0.5) })
            return (year, h)
        }.sorted { $0.year < $1.year }
    }

    // MARK: - Monthly Heatmap

    private var heatmapData: [(year: Int, months: [Int])] {
        let cal = Calendar.current
        var grid: [Int: [Int: Int]] = [:]
        for f in past {
            let y = cal.component(.year, from: f.date)
            let m = cal.component(.month, from: f.date)
            grid[y, default: [:]][m, default: 0] += 1
        }
        return grid.keys.sorted().map { year in
            let months = (1...12).map { grid[year]?[$0] ?? 0 }
            return (year, months)
        }
    }

    private var heatmapMax: Int {
        heatmapData.flatMap(\.months).max() ?? 1
    }

    // MARK: - Year Comparison

    private struct YearStats {
        let year: Int
        let flights: Int
        let km: Double
        let hours: Int
        let countries: Int
    }

    private func statsFor(year: Int) -> YearStats {
        let cal = Calendar.current
        let yearFlights = past.filter { cal.component(.year, from: $0.date) == year }
        let km = yearFlights.reduce(0.0) { $0 + $1.distanceKm }
        let hours = Int(yearFlights.reduce(0.0) { $0 + ($1.distanceKm / 850.0 + 0.5) })
        var countries = Set<String>()
        for f in yearFlights {
            if let o = airportService.airport(for: f.originIATA) { countries.insert(o.country) }
            if let d = airportService.airport(for: f.destinationIATA) { countries.insert(d.country) }
        }
        return YearStats(year: year, flights: yearFlights.count, km: km, hours: hours, countries: countries.count)
    }

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }
    private var hasLastYearData: Bool { past.contains { Calendar.current.component(.year, from: $0.date) == currentYear - 1 } }

    // MARK: - Top Routes

    private var topRoutes: [(origin: String, dest: String, count: Int)] {
        var counts: [String: (a: String, b: String, count: Int)] = [:]
        for f in past {
            let key = f.originIATA < f.destinationIATA
                ? "\(f.originIATA)-\(f.destinationIATA)"
                : "\(f.destinationIATA)-\(f.originIATA)"
            if let existing = counts[key] {
                counts[key] = (existing.a, existing.b, existing.count + 1)
            } else {
                let a = f.originIATA < f.destinationIATA ? f.originIATA : f.destinationIATA
                let b = f.originIATA < f.destinationIATA ? f.destinationIATA : f.originIATA
                counts[key] = (a, b, 1)
            }
        }
        return counts.values
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { ($0.a, $0.b, $0.count) }
    }

    // MARK: - Money Deep-Dive

    private var pricedFlights: [Flight] { past.filter { $0.price != nil } }

    private var totalSpent: Double { pricedFlights.reduce(0) { $0 + ($1.price ?? 0) } }

    private var avgCostPerFlight: Double {
        pricedFlights.isEmpty ? 0 : totalSpent / Double(pricedFlights.count)
    }

    private var costPerKm: Double {
        let totalKmPriced = pricedFlights.reduce(0.0) { $0 + $1.distanceKm }
        return totalKmPriced > 0 ? totalSpent / totalKmPriced : 0
    }

    private var mostExpensiveFlight: Flight? {
        pricedFlights.max { ($0.price ?? 0) < ($1.price ?? 0) }
    }

    private var cheapestFlight: Flight? {
        pricedFlights.min { ($0.price ?? 0) < ($1.price ?? 0) }
    }

    private var bestDealFlight: Flight? {
        // Best value = lowest price per km
        pricedFlights.min { ($0.price ?? 0) / max(1, $0.distanceKm) < ($1.price ?? 0) / max(1, $1.distanceKm) }
    }

    private var priciestPerKmFlight: Flight? {
        pricedFlights.max { ($0.price ?? 0) / max(1, $0.distanceKm) < ($1.price ?? 0) / max(1, $1.distanceKm) }
    }

    private var spendByYear: [(year: Int, total: Double)] {
        let grouped = Dictionary(grouping: pricedFlights) { Calendar.current.component(.year, from: $0.date) }
        return grouped.map { year, flights in
            (year, flights.reduce(0.0) { $0 + ($1.price ?? 0) })
        }.sorted { $0.year < $1.year }
    }

    private var avgPriceByClass: [(label: String, icon: String, avg: Double, count: Int)] {
        let grouped = Dictionary(grouping: pricedFlights.filter { $0.flightClass != nil }) { $0.flightClass! }
        return FlightClass.allCases.compactMap { cls in
            guard let flights = grouped[cls], !flights.isEmpty else { return nil }
            let avg = flights.reduce(0.0) { $0 + ($1.price ?? 0) } / Double(flights.count)
            return (ls.flightClassLabel(cls), cls.icon, avg, flights.count)
        }
    }

    private var topAirlinesBySpend: [(name: String, total: Double, count: Int)] {
        var totals: [String: (total: Double, count: Int)] = [:]
        for f in pricedFlights {
            guard let airline = f.airline else { continue }
            let existing = totals[airline] ?? (0, 0)
            totals[airline] = (existing.total + (f.price ?? 0), existing.count + 1)
        }
        return totals.map { (name: $0.key, total: $0.value.total, count: $0.value.count) }
            .sorted { $0.total > $1.total }
            .prefix(5).map { $0 }
    }

    // MARK: - Achievements

    private struct Achievement: Identifiable {
        let id: String
        let icon: String
        let title: String
        let subtitle: String
        let current: Double
        let target: Double
        var progress: Double { min(1.0, current / target) }
        var isUnlocked: Bool { current >= target }
    }

    private var achievements: [Achievement] {
        [
            Achievement(id: "first",     icon: "airplane.departure", title: ls.achieveFirstFlight,  subtitle: ls.achieveFirstFlightSub, current: Double(past.count), target: 1),
            Achievement(id: "freq",      icon: "repeat",             title: ls.achieveFreqFlyer,    subtitle: ls.achieveFreqFlyerSub,   current: Double(past.count), target: 10),
            Achievement(id: "jet",       icon: "bolt.fill",          title: ls.achieveJetSetter,    subtitle: ls.achieveJetSetterSub,   current: Double(past.count), target: 50),
            Achievement(id: "explorer",  icon: "flag.fill",          title: ls.achieveExplorer,     subtitle: ls.achieveExplorerSub,    current: Double(visitedCountries.count), target: 5),
            Achievement(id: "globe",     icon: "globe",              title: ls.achieveGlobeTrotter, subtitle: ls.achieveGlobeTrotterSub,current: Double(visitedCountries.count), target: 15),
            Achievement(id: "citizen",   icon: "globe.americas.fill",title: ls.achieveWorldCitizen, subtitle: ls.achieveWorldCitizenSub,current: Double(visitedCountries.count), target: 30),
            Achievement(id: "earth",     icon: "globe.europe.africa",title: ls.achieveAroundWorld,  subtitle: ls.achieveAroundWorldSub, current: totalKm, target: 40_075),
            Achievement(id: "moon",      icon: "moon.stars.fill",    title: ls.achieveToTheMoon,    subtitle: ls.achieveToTheMoonSub,   current: totalKm, target: 384_400),
            Achievement(id: "sky",       icon: "clock.fill",         title: ls.achieveSkyTimer,     subtitle: ls.achieveSkyTimerSub,    current: Double(totalHours), target: 100),
            Achievement(id: "collector", icon: "building.2.fill",    title: ls.achieveCollector,    subtitle: ls.achieveCollectorSub,   current: Double(visitedAirports.count), target: 10),
        ]
    }

    private var unlockedCount: Int { achievements.filter(\.isUnlocked).count }

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
                        shareJourneyBanner
                        vitalsGrid
                        achievementsSection

                        // 2+ flights to compare longest vs shortest
                        lockedSection(isLocked: past.count < 2) {
                            recordsSection
                        }
                        // 3+ flights with airline/aircraft data
                        lockedSection(isLocked: flightsWithAirline < 3 && flightsWithAircraft < 3) {
                            if topAirline != nil || topAircraft != nil {
                                favoritesSection
                            }
                        }
                        // Each subsection locked by its own attribute count
                        lockedSection(isLocked: flightsWithClass < 3 && flightsWithSeat < 3) {
                            if !classBreakdown.isEmpty || !seatBreakdown.isEmpty {
                                flyingStyleSection
                            }
                        }

                        worldSection

                        deepDiveDivider(ls.statsFlightsLabel)
                        lockedSection(isLocked: past.count < 3) {
                            flightsDeepSection
                        }

                        if hasLastYearData {
                            yearComparisonSection
                        }

                        if topRoutes.count >= 2 {
                            topRoutesSection
                        }

                        if past.count >= 3 {
                            heatmapSection
                        }

                        if funFacts.count >= 2 {
                            funFactsSection
                        }

                        deepDiveDivider(ls.statsCountriesLabel)
                        countriesDeepSection

                        deepDiveDivider(ls.statsAirportsLabel)
                        airportsDeepSection

                        deepDiveDivider(ls.statsInTheAir)
                        hoursDeepSection

                        if !pricedFlights.isEmpty || past.count >= 2 {
                            deepDiveDivider(ls.statsMoneySection)
                            lockedSection(isLocked: pricedFlights.count < 2) {
                                moneyDeepSection
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 110)
                }
                .onAppear {
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.82).delay(0.15)) {
                        animateCharts = true
                    }
                }
                .onDisappear { animateCharts = false }
            }
        }
        .sheet(isPresented: $showShareCard) {
            ShareCardSheet(flights: flights, airportService: airportService)
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: isLight ? [
                    Color(hex: "D8C9B8"),
                    Color(hex: "E4D8C8"),
                    Color(hex: "F0EAE0")
                ] : [
                    Color(hex: "0d1a2a"),
                    Color(hex: "1a0f2e"),
                    Color(hex: "0a0a0f")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Ellipse()
                .fill(RadialGradient(
                    colors: [Color(hex: "4A7FA5").opacity(isLight ? 0.18 : 0.3), .clear],
                    center: .center, startRadius: 0, endRadius: 120
                ))
                .frame(width: 240, height: 100)
                .offset(x: 60, y: 30)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            VStack(alignment: .leading, spacing: 0) {
                Text(ls.statsYourJourney)
                    .font(FDFont.ui(11, weight: .medium))
                    .foregroundStyle(FDColor.gold)
                    .tracking(2)
                    .padding(.bottom, 14)

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
                    .foregroundStyle(FDColor.text.opacity(0.45))
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

    // MARK: - Share Banner

    private var shareJourneyBanner: some View {
        Button { showShareCard = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FDColor.gold)

                Text(ls.shareYourJourney)
                    .font(FDFont.ui(13, weight: .medium))
                    .foregroundStyle(FDColor.text.opacity(0.7))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FDColor.gold.opacity(0.6))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [FDColor.gold.opacity(0.08), FDColor.gold.opacity(0.03)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [FDColor.gold.opacity(0.3), FDColor.gold.opacity(0.08)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Achievements Section

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(ls.statsAchievements)
                Spacer()
                Text("\(unlockedCount)/\(achievements.count)")
                    .font(FDFont.ui(12, weight: .medium))
                    .foregroundStyle(FDColor.gold)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(achievements) { a in
                        achievementCard(a)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func achievementCard(_ a: Achievement) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(FDColor.surface3, lineWidth: 4)
                    .frame(width: 52, height: 52)

                Circle()
                    .trim(from: 0, to: animateCharts ? a.progress : 0)
                    .stroke(
                        a.isUnlocked ? FDColor.gold : FDColor.textDim,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 52, height: 52)
                    .animation(
                        .spring(response: 0.8, dampingFraction: 0.8)
                            .delay(Double(achievements.firstIndex(where: { $0.id == a.id }) ?? 0) * 0.05),
                        value: animateCharts
                    )

                Image(systemName: a.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(a.isUnlocked ? FDColor.gold : FDColor.textDim)
            }

            VStack(spacing: 3) {
                Text(a.title)
                    .font(FDFont.ui(11, weight: .semibold))
                    .foregroundStyle(a.isUnlocked ? FDColor.text : FDColor.textDim)
                    .lineLimit(1)
                Text(a.subtitle)
                    .font(FDFont.ui(9))
                    .foregroundStyle(FDColor.textDim)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            if !a.isUnlocked {
                Text("\(Int(a.current))/\(Int(a.target))")
                    .font(FDFont.ui(9, weight: .medium))
                    .foregroundStyle(FDColor.textMuted)
            }
        }
        .frame(width: 100)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            ZStack {
                FDColor.surface2
                if a.isUnlocked {
                    RadialGradient(
                        colors: [FDColor.gold.opacity(0.1), .clear],
                        center: .top, startRadius: 0, endRadius: 60
                    )
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(a.isUnlocked ? FDColor.gold.opacity(0.3) : FDColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack(alignment: .topLeading) {
                FDColor.surface2
                if highlight {
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
            if !past.isEmpty {
                domesticIntlCard
            }
        }
    }

    // MARK: - Domestic vs International

    private var domesticIntlCard: some View {
        let total = past.count
        let domPct = total > 0 ? Double(domesticCount) / Double(total) : 0
        let intlPct = total > 0 ? Double(internationalCount) / Double(total) : 0

        return VStack(alignment: .leading, spacing: 14) {
            Text(ls.statsDomesticVsIntl)
                .font(FDFont.ui(10, weight: .medium))
                .foregroundStyle(FDColor.textDim)
                .tracking(1.5)

            HStack(spacing: 20) {
                // Donut ring
                ZStack {
                    Circle()
                        .stroke(FDColor.surface3, lineWidth: 10)

                    Circle()
                        .trim(from: 0, to: animateCharts ? intlPct : 0)
                        .stroke(FDColor.gold, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: animateCharts)

                    Circle()
                        .trim(from: intlPct, to: animateCharts ? 1.0 : intlPct)
                        .stroke(FDColor.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: animateCharts)

                    VStack(spacing: 2) {
                        Text("\(total)")
                            .font(FDFont.display(20, weight: .bold))
                            .foregroundStyle(FDColor.text)
                        Text(ls.statsFlightsCount)
                            .font(FDFont.ui(8, weight: .medium))
                            .foregroundStyle(FDColor.textDim)
                            .tracking(0.5)
                    }
                }
                .frame(width: 90, height: 90)

                // Legend
                VStack(alignment: .leading, spacing: 14) {
                    legendRow(
                        color: FDColor.gold,
                        icon: "globe",
                        label: ls.statsInternational,
                        count: internationalCount,
                        pct: intlPct
                    )
                    legendRow(
                        color: FDColor.blue,
                        icon: "house.fill",
                        label: ls.statsDomestic,
                        count: domesticCount,
                        pct: domPct
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(FDColor.surface2)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func legendRow(color: Color, icon: String, label: String, count: Int, pct: Double) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(FDFont.ui(12, weight: .medium))
                    .foregroundStyle(FDColor.text)
                Text("\(count) · \(Int(pct * 100))%")
                    .font(FDFont.ui(10))
                    .foregroundStyle(FDColor.textMuted)
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
                FDColor.surface2
                RadialGradient(
                    colors: [Color(hex: "4A7FA5").opacity(0.12), .clear],
                    center: .bottomTrailing, startRadius: 0, endRadius: 160
                )
                VStack(alignment: .leading, spacing: 16) {
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
                        Rectangle().fill(FDColor.border).frame(width: 1, height: 36)
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
                    if !countryFlags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(countryFlags, id: \.self) { flag in
                                    Text(flag).font(.system(size: 22))
                                }
                            }
                        }
                    }
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

    // MARK: - Deep-Dive: Flights

    private var flightsDeepSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .lastTextBaseline, spacing: 14) {
                Text("\(past.count)")
                    .font(FDFont.display(56, weight: .bold))
                    .foregroundStyle(FDColor.text)
                VStack(alignment: .leading, spacing: 4) {
                    Text(ls.flightsLogged)
                        .font(FDFont.ui(14))
                        .foregroundStyle(FDColor.textMuted)
                    if !upcoming.isEmpty {
                        Text(ls.upcomingBadge(upcoming.count))
                            .font(FDFont.ui(11, weight: .medium))
                            .foregroundStyle(FDColor.gold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(FDColor.gold.opacity(0.12))
                            .overlay(Capsule().stroke(FDColor.gold.opacity(0.3), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                }
            }

            if !flightsByYear.isEmpty {
                let maxCount = flightsByYear.map(\.count).max() ?? 1
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader(ls.statsFlightsPerYear)
                    VStack(spacing: 10) {
                        ForEach(Array(flightsByYear.enumerated()), id: \.offset) { idx, item in
                            HStack(spacing: 12) {
                                Text(verbatim: "\(item.year)")
                                    .font(FDFont.ui(12, weight: .medium))
                                    .foregroundStyle(FDColor.textMuted)
                                    .frame(width: 42, alignment: .leading)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 6).fill(FDColor.surface3).frame(height: 34)
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(LinearGradient(
                                                colors: [FDColor.gold, FDColor.gold.opacity(0.5)],
                                                startPoint: .leading, endPoint: .trailing
                                            ))
                                            .frame(
                                                width: animateCharts
                                                    ? max(34, geo.size.width * CGFloat(item.count) / CGFloat(maxCount))
                                                    : 0,
                                                height: 34
                                            )
                                            .animation(.spring(response: 0.65, dampingFraction: 0.82).delay(Double(idx) * 0.08), value: animateCharts)
                                        Text("\(item.count)")
                                            .font(FDFont.ui(12, weight: .semibold))
                                            .foregroundStyle(FDColor.black)
                                            .padding(.leading, 12)
                                            .opacity(animateCharts ? 1 : 0)
                                            .animation(.easeIn(duration: 0.2).delay(Double(idx) * 0.08 + 0.35), value: animateCharts)
                                    }
                                }
                                .frame(height: 34)
                            }
                        }
                    }
                    .padding(20)
                    .background(FDColor.surface2)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(ls.statsYourPace)
                HStack(spacing: 12) {
                    paceCell(value: String(format: "%.1f", avgPerMonth), label: ls.statsAvgMonth)
                    paceCell(value: String(format: "%.0f", avgPerYear),  label: ls.statsAvgYear)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(ls.statsBusiestMonth)
                    if let m = busiestMonth {
                        Text(m.name)
                            .font(FDFont.display(20, weight: .bold))
                            .foregroundStyle(FDColor.gold)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text("\(m.count) \(ls.statsFlightsCount)")
                            .font(FDFont.ui(12)).foregroundStyle(FDColor.textMuted)
                    } else {
                        Text("—").font(FDFont.display(20, weight: .bold)).foregroundStyle(FDColor.textDim)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FDColor.surface2)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(ls.statsMonthStreak)
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(longestStreak)")
                            .font(FDFont.display(20, weight: .bold)).foregroundStyle(FDColor.blue)
                        Text(ls.statsMonthShort)
                            .font(FDFont.ui(12)).foregroundStyle(FDColor.textMuted)
                    }
                    Text(ls.statsConsecutive)
                        .font(FDFont.ui(12)).foregroundStyle(FDColor.textMuted)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FDColor.surface2)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func paceCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(FDFont.display(28, weight: .semibold))
                .foregroundStyle(FDColor.text)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(FDFont.ui(10, weight: .medium))
                .foregroundStyle(FDColor.textMuted)
                .tracking(1.2)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FDColor.surface2)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Deep-Dive: Countries

    private var countriesDeepSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .lastTextBaseline, spacing: 14) {
                    Text("\(visitedCountries.count)")
                        .font(FDFont.display(56, weight: .bold))
                        .foregroundStyle(FDColor.text)
                    Text(ls.countriesVisited)
                        .font(FDFont.ui(14)).foregroundStyle(FDColor.textMuted)
                }
                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(FDColor.surface2).frame(height: 6)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [FDColor.gold, FDColor.gold.opacity(0.5)],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: animateCharts ? geo.size.width * countryProgress : 0, height: 6)
                                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: animateCharts)
                        }
                    }
                    .frame(height: 6)
                    Text(ls.ofCountries(totalCountries))
                        .font(FDFont.ui(11)).foregroundStyle(FDColor.textDim)
                }
                .padding(.top, 4)
            }

            if !countryFlagPairs.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader(ls.statsAllFlags)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 38, maximum: 48))], spacing: 10) {
                        ForEach(countryFlagPairs, id: \.iso) { item in
                            Text(item.flag).font(.system(size: 28))
                        }
                    }
                    .padding(16)
                    .background(FDColor.surface2)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            if !continentBreakdown.isEmpty {
                let maxCount = continentBreakdown.map(\.count).max() ?? 1
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader(ls.statsByContinent)
                    VStack(spacing: 10) {
                        ForEach(Array(continentBreakdown.enumerated()), id: \.offset) { idx, item in
                            HStack(spacing: 12) {
                                Text(item.continent)
                                    .font(FDFont.ui(12, weight: .medium))
                                    .foregroundStyle(FDColor.textMuted)
                                    .frame(width: 80, alignment: .leading)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 6).fill(FDColor.surface3).frame(height: 30)
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(LinearGradient(
                                                colors: [FDColor.gold, FDColor.gold.opacity(0.5)],
                                                startPoint: .leading, endPoint: .trailing
                                            ))
                                            .frame(
                                                width: animateCharts
                                                    ? max(30, geo.size.width * CGFloat(item.count) / CGFloat(maxCount))
                                                    : 0,
                                                height: 30
                                            )
                                            .animation(.spring(response: 0.65, dampingFraction: 0.82).delay(Double(idx) * 0.08), value: animateCharts)
                                        Text("\(item.count)")
                                            .font(FDFont.ui(12, weight: .semibold))
                                            .foregroundStyle(FDColor.black)
                                            .padding(.leading, 10)
                                            .opacity(animateCharts ? 1 : 0)
                                            .animation(.easeIn(duration: 0.2).delay(Double(idx) * 0.08 + 0.35), value: animateCharts)
                                    }
                                }
                                .frame(height: 30)
                            }
                        }
                    }
                    .padding(20)
                    .background(FDColor.surface2)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            if !topCountries.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader(ls.statsMostVisited)
                    VStack(spacing: 0) {
                        ForEach(Array(topCountries.enumerated()), id: \.offset) { idx, item in
                            if idx > 0 {
                                Rectangle().fill(FDColor.border).frame(height: 1).padding(.leading, 56)
                            }
                            HStack(spacing: 14) {
                                Text(item.flag).font(.system(size: 26)).frame(width: 38)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(FDFont.ui(14, weight: .medium))
                                        .foregroundStyle(FDColor.text).lineLimit(1)
                                    Text("\(item.count) \(ls.statsFlightsCount)")
                                        .font(FDFont.ui(11)).foregroundStyle(FDColor.textMuted)
                                }
                                Spacer()
                                Text("#\(idx + 1)")
                                    .font(FDFont.ui(11, weight: .medium))
                                    .foregroundStyle(idx == 0 ? FDColor.gold : FDColor.textDim)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(idx == 0 ? FDColor.gold.opacity(0.12) : FDColor.surface3)
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                        }
                    }
                    .background(FDColor.surface2)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Deep-Dive: Airports

    private var airportsDeepSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .lastTextBaseline, spacing: 14) {
                Text("\(visitedAirports.count)")
                    .font(FDFont.display(56, weight: .bold))
                    .foregroundStyle(FDColor.text)
                Text(ls.airportsVisited)
                    .font(FDFont.ui(14)).foregroundStyle(FDColor.textMuted)
            }

            if !topAirportsList.isEmpty {
                let maxCount = topAirportsList.map(\.count).max() ?? 1
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader(ls.statsTopAirports)
                    VStack(spacing: 12) {
                        ForEach(Array(topAirportsList.enumerated()), id: \.offset) { idx, item in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 5) {
                                        Text(item.airport.flagEmoji).font(.system(size: 13))
                                        Text(item.airport.iata)
                                            .font(FDFont.display(14, weight: .bold))
                                            .foregroundStyle(FDColor.gold)
                                    }
                                    Text(item.airport.city)
                                        .font(FDFont.ui(9)).foregroundStyle(FDColor.textDim).lineLimit(1)
                                }
                                .frame(width: 72, alignment: .leading)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 6).fill(FDColor.surface3).frame(height: 30)
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(LinearGradient(
                                                colors: [FDColor.gold, FDColor.gold.opacity(0.5)],
                                                startPoint: .leading, endPoint: .trailing
                                            ))
                                            .frame(
                                                width: animateCharts
                                                    ? max(30, geo.size.width * CGFloat(item.count) / CGFloat(maxCount))
                                                    : 0,
                                                height: 30
                                            )
                                            .animation(.spring(response: 0.65, dampingFraction: 0.82).delay(Double(idx) * 0.07), value: animateCharts)
                                        Text("\(item.count)")
                                            .font(FDFont.ui(11, weight: .semibold))
                                            .foregroundStyle(FDColor.black)
                                            .padding(.leading, 10)
                                            .opacity(animateCharts ? 1 : 0)
                                            .animation(.easeIn(duration: 0.2).delay(Double(idx) * 0.07 + 0.3), value: animateCharts)
                                    }
                                }
                                .frame(height: 30)
                            }
                        }
                    }
                    .padding(20)
                    .background(FDColor.surface2)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Deep-Dive: Hours

    private var hoursDeepSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(totalHours)")
                    .font(FDFont.display(56, weight: .bold)).foregroundStyle(FDColor.text)
                Text(ls.statsHoursShort)
                    .font(FDFont.display(28, weight: .bold)).foregroundStyle(FDColor.textMuted)
            }
            Text(ls.hoursInTheAir)
                .font(FDFont.ui(14)).foregroundStyle(FDColor.textMuted)

            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(ls.statsDistanceFacts)
                HStack(spacing: 12) {
                    funCard(emoji: "🌍", value: String(format: "%.1f×", earthLaps), label: ls.statsAroundEarth)
                    funCard(emoji: "🌙", value: String(format: "%.2f×", moonTrips), label: ls.statsMoonTrip)
                }
            }

            if !hoursByYear.isEmpty {
                let maxHours = hoursByYear.map(\.hours).max() ?? 1
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader(ls.statsHoursPerYear)
                    VStack(spacing: 10) {
                        ForEach(Array(hoursByYear.enumerated()), id: \.offset) { idx, item in
                            HStack(spacing: 12) {
                                Text(verbatim: "\(item.year)")
                                    .font(FDFont.ui(12, weight: .medium))
                                    .foregroundStyle(FDColor.textMuted)
                                    .frame(width: 42, alignment: .leading)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 6).fill(FDColor.surface3).frame(height: 34)
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(LinearGradient(
                                                colors: [FDColor.blue, FDColor.blue.opacity(0.5)],
                                                startPoint: .leading, endPoint: .trailing
                                            ))
                                            .frame(
                                                width: animateCharts
                                                    ? max(34, geo.size.width * CGFloat(item.hours) / CGFloat(maxHours))
                                                    : 0,
                                                height: 34
                                            )
                                            .animation(.spring(response: 0.65, dampingFraction: 0.82).delay(Double(idx) * 0.08), value: animateCharts)
                                        Text("\(item.hours)\(ls.statsHoursShort)")
                                            .font(FDFont.ui(11, weight: .semibold))
                                            .foregroundStyle(Color.white.opacity(0.9))
                                            .padding(.leading, 10)
                                            .opacity(animateCharts ? 1 : 0)
                                            .animation(.easeIn(duration: 0.2).delay(Double(idx) * 0.08 + 0.35), value: animateCharts)
                                    }
                                }
                                .frame(height: 34)
                            }
                        }
                    }
                    .padding(20)
                    .background(FDColor.surface2)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(ls.statsAvgPerFlight)
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(String(format: "%.1f", avgHoursPerFlight))
                        .font(FDFont.display(28, weight: .semibold)).foregroundStyle(FDColor.text)
                    Text(ls.statsHoursShort)
                        .font(FDFont.ui(16)).foregroundStyle(FDColor.textMuted)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FDColor.surface2)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func funCard(emoji: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emoji).font(.system(size: 28))
            Text(value)
                .font(FDFont.display(22, weight: .bold))
                .foregroundStyle(FDColor.gold)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label)
                .font(FDFont.ui(10, weight: .medium))
                .foregroundStyle(FDColor.textMuted)
                .tracking(0.5).lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FDColor.surface2)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Monthly Heatmap Section

    private var heatmapSection: some View {
        let monthLabels = Calendar.current.shortMonthSymbols

        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader(ls.statsActivityMap)

            VStack(spacing: 6) {
                // Month labels row
                HStack(spacing: 0) {
                    Text("")
                        .frame(width: 40)
                    ForEach(0..<12, id: \.self) { i in
                        Text(String(monthLabels[i].prefix(1)))
                            .font(FDFont.ui(8, weight: .medium))
                            .foregroundStyle(FDColor.textDim)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Year rows
                ForEach(heatmapData, id: \.year) { row in
                    HStack(spacing: 0) {
                        Text(verbatim: "\(row.year)")
                            .font(FDFont.ui(10, weight: .medium))
                            .foregroundStyle(FDColor.textMuted)
                            .frame(width: 40, alignment: .leading)

                        ForEach(0..<12, id: \.self) { i in
                            let count = row.months[i]
                            let intensity = heatmapMax > 0 ? Double(count) / Double(heatmapMax) : 0
                            RoundedRectangle(cornerRadius: 3)
                                .fill(count == 0
                                      ? FDColor.surface3
                                      : FDColor.gold.opacity(0.2 + intensity * 0.8))
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    count > 0
                                        ? Text("\(count)")
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundStyle(intensity > 0.5 ? FDColor.black : FDColor.text)
                                        : nil
                                )
                        }
                    }
                }
            }
            .padding(16)
            .background(FDColor.surface2)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Fun Facts Section

    private var funFacts: [String] {
        var facts: [String] = []
        let km = totalKm
        // Distance comparisons
        if km > 0 {
            let londonNY = 5_570.0
            let timesLondonNY = km / londonNY
            if timesLondonNY >= 1 {
                facts.append(String(format: "You've flown the London–New York distance %.1f times", timesLondonNY))
            }
        }
        if earthLaps >= 0.01 {
            facts.append(String(format: "You've circled the Earth %.2f times", earthLaps))
        }
        if moonTrips >= 0.001 {
            facts.append(String(format: "You're %.1f%% of the way to the Moon", moonTrips * 100))
        }

        // Time in the air
        let hours = totalHours
        if hours >= 1 {
            let days = Double(hours) / 24.0
            if days >= 1 {
                facts.append(String(format: "You've spent %.1f days in the air", days))
            }
            let movies = hours * 60 / 120 // ~120 min avg movie
            if movies >= 2 {
                facts.append("You could have watched \(movies) movies during your flights")
            }
        }

        // Speed
        if km > 0 && hours > 0 {
            let avgSpeed = km / Double(hours)
            facts.append(String(format: "Your average flying speed: %.0f km/h", avgSpeed))
        }

        // Airports & countries
        let airports = visitedAirports.count
        if airports >= 3 {
            facts.append("You've been to \(airports) different airports")
        }
        let countries = visitedCountries.count
        if countries >= 2 {
            facts.append("You've visited \(countries) countries — that's \(Int(Double(countries) / 195.0 * 100))% of the world")
        }

        // Busiest month
        let cal = Calendar.current
        var monthCounts: [Int: Int] = [:]
        for f in past {
            let m = cal.component(.month, from: f.date)
            monthCounts[m, default: 0] += 1
        }
        if let (busyMonth, busyCount) = monthCounts.max(by: { $0.value < $1.value }), busyCount >= 2 {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            let monthName = formatter.monthSymbols[busyMonth - 1]
            facts.append("\(monthName) is your busiest month with \(busyCount) flights")
        }

        // Longest flight
        if let longest = past.max(by: { $0.distanceKm < $1.distanceKm }) {
            facts.append(String(format: "Your longest flight: %@ → %@ (%.0f km)", longest.originIATA, longest.destinationIATA, longest.distanceKm))
        }

        return facts
    }

    private var funFactsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ls.statsFunFacts)
                .font(FDFont.ui(11, weight: .medium))
                .foregroundStyle(FDColor.textMuted)
                .tracking(1.2)

            VStack(spacing: 8) {
                ForEach(Array(funFacts.prefix(4).enumerated()), id: \.offset) { index, fact in
                    HStack(alignment: .top, spacing: 10) {
                        Text("💡")
                            .font(.system(size: 14))
                        Text(fact)
                            .font(FDFont.ui(13, weight: .regular))
                            .foregroundStyle(FDColor.text)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FDColor.surface2)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(FDColor.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Year vs Year Section

    private var yearComparisonSection: some View {
        let thisY = statsFor(year: currentYear)
        let lastY = statsFor(year: currentYear - 1)

        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader(ls.statsYearVsYear)

            HStack(spacing: 0) {
                // This year column
                VStack(spacing: 4) {
                    Text(verbatim: "\(currentYear)")
                        .font(FDFont.display(16, weight: .bold))
                        .foregroundStyle(FDColor.gold)
                }
                .frame(maxWidth: .infinity)

                Text(ls.statsVs)
                    .font(FDFont.ui(11, weight: .medium))
                    .foregroundStyle(FDColor.textDim)

                // Last year column
                VStack(spacing: 4) {
                    Text(verbatim: "\(currentYear - 1)")
                        .font(FDFont.display(16, weight: .bold))
                        .foregroundStyle(FDColor.textMuted)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)

            let rows: [(label: String, thisVal: Int, lastVal: Int)] = [
                (ls.statsFlightsLabel, thisY.flights, lastY.flights),
                (ls.statsCountriesLabel, thisY.countries, lastY.countries),
                (ls.statsInTheAir, thisY.hours, lastY.hours),
            ]

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    if idx > 0 {
                        Rectangle().fill(FDColor.border).frame(height: 1).padding(.horizontal, 16)
                    }
                    yearComparisonRow(label: row.label, thisYear: row.thisVal, lastYear: row.lastVal)
                }
            }
            .background(FDColor.surface2)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func yearComparisonRow(label: String, thisYear: Int, lastYear: Int) -> some View {
        let delta = thisYear - lastYear
        let isUp = delta > 0

        return HStack(spacing: 12) {
            Text(label)
                .font(FDFont.ui(10, weight: .medium))
                .foregroundStyle(FDColor.textDim)
                .tracking(1.2)
                .frame(width: 70, alignment: .leading)

            Text("\(thisYear)")
                .font(FDFont.display(18, weight: .bold))
                .foregroundStyle(FDColor.gold)
                .frame(maxWidth: .infinity)

            if delta != 0 {
                HStack(spacing: 3) {
                    Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(isUp ? "+\(delta)" : "\(delta)")
                        .font(FDFont.ui(11, weight: .semibold))
                }
                .foregroundStyle(isUp ? Color(hex: "2E7D32") : Color(hex: "E05252"))
                .frame(width: 52)
            } else {
                Text("=")
                    .font(FDFont.ui(11, weight: .medium))
                    .foregroundStyle(FDColor.textDim)
                    .frame(width: 52)
            }

            Text("\(lastYear)")
                .font(FDFont.display(18, weight: .bold))
                .foregroundStyle(FDColor.textMuted)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    // MARK: - Top Routes Section

    private var topRoutesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(ls.statsTopRoutes)
            VStack(spacing: 0) {
                ForEach(Array(topRoutes.enumerated()), id: \.offset) { idx, route in
                    if idx > 0 {
                        Rectangle().fill(FDColor.border).frame(height: 1).padding(.leading, 56)
                    }
                    HStack(spacing: 14) {
                        Text("#\(idx + 1)")
                            .font(FDFont.ui(11, weight: .bold))
                            .foregroundStyle(idx == 0 ? FDColor.gold : FDColor.textDim)
                            .frame(width: 24)

                        HStack(spacing: 6) {
                            Text(route.origin)
                                .font(FDFont.display(16, weight: .bold))
                                .foregroundStyle(FDColor.text)
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 10))
                                .foregroundStyle(idx == 0 ? FDColor.gold : FDColor.textMuted)
                            Text(route.dest)
                                .font(FDFont.display(16, weight: .bold))
                                .foregroundStyle(idx == 0 ? FDColor.gold : FDColor.text)
                        }

                        Spacer()

                        Text("×\(route.count)")
                            .font(FDFont.ui(13, weight: .semibold))
                            .foregroundStyle(idx == 0 ? FDColor.gold : FDColor.textMuted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(idx == 0 ? FDColor.gold.opacity(0.12) : FDColor.surface3)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
            }
            .background(FDColor.surface2)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Deep-Dive: Money

    private var moneyDeepSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Hero: total spent
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(ls.formatPrice(totalSpent))
                    .font(FDFont.display(44, weight: .bold))
                    .foregroundStyle(FDColor.gold)
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
            HStack(spacing: 6) {
                Text(ls.statsTotalSpent)
                    .font(FDFont.ui(14)).foregroundStyle(FDColor.textMuted)
                Text("·")
                    .foregroundStyle(FDColor.textDim)
                Text("\(pricedFlights.count) \(ls.statsFlightsTracked)")
                    .font(FDFont.ui(12)).foregroundStyle(FDColor.textDim)
            }

            // Avg cost + cost per km side by side
            HStack(spacing: 12) {
                moneyStatCell(
                    value: ls.formatPrice(avgCostPerFlight),
                    label: ls.statsAvgPerFlightCost,
                    color: FDColor.gold
                )
                moneyStatCell(
                    value: ls.formatPrice(costPerKm),
                    label: ls.distanceUnit == .miles ? ls.statsCostPerMi : ls.statsCostPerKm,
                    color: FDColor.blue
                )
            }

            // Spending per year bar chart
            if !spendByYear.isEmpty {
                let maxSpend = spendByYear.map(\.total).max() ?? 1
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader(ls.statsSpendPerYear)
                    VStack(spacing: 10) {
                        ForEach(Array(spendByYear.enumerated()), id: \.offset) { idx, item in
                            HStack(spacing: 12) {
                                Text(verbatim: "\(item.year)")
                                    .font(FDFont.ui(12, weight: .medium))
                                    .foregroundStyle(FDColor.textMuted)
                                    .frame(width: 42, alignment: .leading)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 6).fill(FDColor.surface3).frame(height: 34)
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(LinearGradient(
                                                colors: [Color(hex: "2E7D32"), Color(hex: "66BB6A").opacity(0.6)],
                                                startPoint: .leading, endPoint: .trailing
                                            ))
                                            .frame(
                                                width: animateCharts
                                                    ? max(34, geo.size.width * CGFloat(item.total / maxSpend))
                                                    : 0,
                                                height: 34
                                            )
                                            .animation(.spring(response: 0.65, dampingFraction: 0.82).delay(Double(idx) * 0.08), value: animateCharts)
                                        Text(ls.formatPrice(item.total))
                                            .font(FDFont.ui(10, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.9))
                                            .padding(.leading, 10)
                                            .lineLimit(1)
                                            .opacity(animateCharts ? 1 : 0)
                                            .animation(.easeIn(duration: 0.2).delay(Double(idx) * 0.08 + 0.35), value: animateCharts)
                                    }
                                }
                                .frame(height: 34)
                            }
                        }
                    }
                    .padding(20)
                    .background(FDColor.surface2)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            // Most expensive + cheapest record cards
            if let expensive = mostExpensiveFlight {
                moneyRouteCard(flight: expensive, label: ls.statsMostExpensive, accentColor: FDColor.gold)
            }
            if let cheap = cheapestFlight, cheap.id != mostExpensiveFlight?.id {
                moneyRouteCard(flight: cheap, label: ls.statsCheapest, accentColor: FDColor.blue)
            }

            // Best deal + priciest per km
            if let best = bestDealFlight, let priciest = priciestPerKmFlight, best.id != priciest.id {
                HStack(spacing: 12) {
                    valuePerKmCard(flight: best, label: ls.statsBestDeal, color: Color(hex: "2E7D32"))
                    valuePerKmCard(flight: priciest, label: ls.statsPriciest, color: Color(hex: "E05252"))
                }
            }

            // Avg price by class
            if !avgPriceByClass.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader(ls.statsSpendByClass)
                    VStack(spacing: 0) {
                        ForEach(Array(avgPriceByClass.enumerated()), id: \.offset) { idx, item in
                            if idx > 0 {
                                Rectangle().fill(FDColor.border).frame(height: 1).padding(.leading, 56)
                            }
                            HStack(spacing: 14) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(FDColor.gold)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.label)
                                        .font(FDFont.ui(13, weight: .medium))
                                        .foregroundStyle(FDColor.text)
                                    Text("\(item.count) \(ls.statsFlightsCount)")
                                        .font(FDFont.ui(10))
                                        .foregroundStyle(FDColor.textDim)
                                }
                                Spacer()
                                Text(ls.formatPrice(item.avg))
                                    .font(FDFont.display(16, weight: .semibold))
                                    .foregroundStyle(FDColor.gold)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                        }
                    }
                    .background(FDColor.surface2)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            // Top airlines by total spend
            if !topAirlinesBySpend.isEmpty {
                let maxSpend = topAirlinesBySpend.first?.total ?? 1
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader(ls.statsTopAirlineSpend)
                    VStack(spacing: 10) {
                        ForEach(Array(topAirlinesBySpend.enumerated()), id: \.offset) { idx, item in
                            HStack(spacing: 12) {
                                Text("#\(idx + 1)")
                                    .font(FDFont.ui(10, weight: .bold))
                                    .foregroundStyle(idx == 0 ? FDColor.gold : FDColor.textDim)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(FDFont.ui(12, weight: .medium))
                                        .foregroundStyle(FDColor.text)
                                        .lineLimit(1)
                                    Text("\(item.count) \(ls.statsFlightsCount)")
                                        .font(FDFont.ui(9))
                                        .foregroundStyle(FDColor.textDim)
                                }
                                .frame(width: 90, alignment: .leading)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 6).fill(FDColor.surface3).frame(height: 28)
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(LinearGradient(
                                                colors: [FDColor.gold, FDColor.gold.opacity(0.4)],
                                                startPoint: .leading, endPoint: .trailing
                                            ))
                                            .frame(
                                                width: animateCharts
                                                    ? max(28, geo.size.width * CGFloat(item.total / maxSpend))
                                                    : 0,
                                                height: 28
                                            )
                                            .animation(.spring(response: 0.65, dampingFraction: 0.82).delay(Double(idx) * 0.07), value: animateCharts)
                                        Text(ls.formatPrice(item.total))
                                            .font(FDFont.ui(10, weight: .semibold))
                                            .foregroundStyle(FDColor.black)
                                            .padding(.leading, 8)
                                            .lineLimit(1)
                                            .opacity(animateCharts ? 1 : 0)
                                            .animation(.easeIn(duration: 0.2).delay(Double(idx) * 0.07 + 0.3), value: animateCharts)
                                    }
                                }
                                .frame(height: 28)
                            }
                        }
                    }
                    .padding(20)
                    .background(FDColor.surface2)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private func moneyStatCell(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(FDFont.display(22, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label)
                .font(FDFont.ui(10, weight: .medium))
                .foregroundStyle(FDColor.textMuted)
                .tracking(1.2)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack(alignment: .topLeading) {
                FDColor.surface2
                RadialGradient(colors: [color.opacity(0.08), .clear], center: .topLeading, startRadius: 0, endRadius: 80)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func moneyRouteCard(flight: Flight, label: String, accentColor: Color) -> some View {
        let origin = airportService.airport(for: flight.originIATA)
        let dest   = airportService.airport(for: flight.destinationIATA)

        return HStack(spacing: 0) {
            accentColor
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .padding(.vertical, 20)
                .padding(.leading, 16)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(label)
                        .font(FDFont.ui(10, weight: .medium))
                        .foregroundStyle(FDColor.textDim)
                        .tracking(1.5)
                    Spacer()
                    Text(ls.formatPrice(flight.price ?? 0))
                        .font(FDFont.display(22, weight: .bold))
                        .foregroundStyle(accentColor)
                }

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(flight.originIATA)
                            .font(FDFont.display(20, weight: .semibold))
                            .foregroundStyle(FDColor.text)
                        Text(origin?.city ?? "")
                            .font(FDFont.ui(10))
                            .foregroundStyle(FDColor.textMuted)
                            .lineLimit(1)
                    }
                    Spacer()
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(LinearGradient(colors: [FDColor.border, accentColor.opacity(0.5)], startPoint: .leading, endPoint: .center))
                            .frame(height: 1)
                        Image(systemName: "airplane")
                            .font(.system(size: 10))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 5)
                        Rectangle()
                            .fill(LinearGradient(colors: [accentColor.opacity(0.5), FDColor.border], startPoint: .leading, endPoint: .trailing))
                            .frame(height: 1)
                    }
                    .frame(maxWidth: 70)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(flight.destinationIATA)
                            .font(FDFont.display(20, weight: .semibold))
                            .foregroundStyle(accentColor)
                        Text(dest?.city ?? "")
                            .font(FDFont.ui(10))
                            .foregroundStyle(FDColor.textMuted)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 0) {
                    Text(ls.formatDistance(flight.distanceKm))
                        .font(FDFont.ui(11, weight: .medium))
                        .foregroundStyle(FDColor.textMuted)
                    if let airline = flight.airline {
                        Text(" · \(airline)")
                            .font(FDFont.ui(11))
                            .foregroundStyle(FDColor.textDim)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 16)
        }
        .background(FDColor.surface2)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(FDColor.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func valuePerKmCard(flight: Flight, label: String, color: Color) -> some View {
        let pricePerKm = (flight.price ?? 0) / max(1, flight.distanceKm)
        let unitLabel = ls.distanceUnit == .miles ? ls.statsPerMi : ls.statsPerKm
        let displayValue = ls.distanceUnit == .miles ? pricePerKm / 0.621371 : pricePerKm

        return VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(FDFont.ui(10, weight: .medium))
                .foregroundStyle(FDColor.textDim)
                .tracking(1.2)
            Text("\(flight.originIATA)→\(flight.destinationIATA)")
                .font(FDFont.display(16, weight: .bold))
                .foregroundStyle(FDColor.text)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(ls.formatPrice(displayValue))
                    .font(FDFont.display(18, weight: .bold))
                    .foregroundStyle(color)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(unitLabel)
                    .font(FDFont.ui(10))
                    .foregroundStyle(FDColor.textMuted)
            }
            Text(ls.formatPrice(flight.price ?? 0))
                .font(FDFont.ui(11))
                .foregroundStyle(FDColor.textMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack(alignment: .topTrailing) {
                FDColor.surface2
                RadialGradient(colors: [color.opacity(0.08), .clear], center: .topTrailing, startRadius: 0, endRadius: 80)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(FDColor.gold.opacity(0.5))
            Text(ls.tabStats)
                .font(FDFont.display(22, weight: .bold)).foregroundStyle(FDColor.text)
            Text(ls.statsComingSoon)
                .font(FDFont.ui(13)).foregroundStyle(FDColor.textMuted)
        }
    }

    // MARK: - Helpers

    private func deepDiveDivider(_ title: String) -> some View {
        HStack(spacing: 12) {
            Rectangle().fill(FDColor.border).frame(height: 1)
            Text(title.uppercased())
                .font(FDFont.ui(10, weight: .semibold))
                .foregroundStyle(FDColor.textDim)
                .tracking(2).lineLimit(1).fixedSize()
            Rectangle().fill(FDColor.border).frame(height: 1)
        }
        .padding(.top, 8)
    }

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

    /// Wraps a section: if `isLocked` is true, dims content and shows a hint overlay.
    @ViewBuilder
    private func lockedSection<Content: View>(isLocked: Bool, @ViewBuilder content: () -> Content) -> some View {
        if isLocked {
            ZStack {
                content()
                    .opacity(0.25)
                    .allowsHitTesting(false)

                VStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(FDColor.textDim)
                    Text(ls.statsAddMoreFlights)
                        .font(FDFont.ui(12, weight: .medium))
                        .foregroundStyle(FDColor.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        } else {
            content()
        }
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
                  "KH","LA","MN","KZ","UZ","GE","AM","AZ","MV","BT","TM","TJ","KG"]        { m[c] = "Asia" }
        for c in ["US","CA","MX","BR","AR","CL","CO","PE","VE","EC","BO","PY","UY","GY",
                  "SR","CU","DO","PR","JM","TT","HT","GT","HN","SV","NI","CR","PA","BS",
                  "BB","BZ","LC","VC","GD","AG","DM","KN"]                                  { m[c] = "Americas" }
        for c in ["ZA","EG","MA","TN","DZ","NG","KE","ET","TZ","GH","SN","CI","CM","AO",
                  "MZ","ZM","ZW","MU","RW","UG","LY","SD","SO","MG","BW"]                   { m[c] = "Africa" }
        for c in ["AU","NZ","FJ","PG","SB","VU","WS","TO","NR","KI"]                        { m[c] = "Oceania" }
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
