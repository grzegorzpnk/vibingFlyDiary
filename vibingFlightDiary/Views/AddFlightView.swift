import SwiftUI
import SwiftData
import CoreLocation

struct AddFlightView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AirportService.self) private var airportService

    let editingFlight: Flight?

    @State private var origin: Airport?
    @State private var destination: Airport?
    @State private var date: Date
    @State private var seatType: SeatType?
    @State private var flightClass: FlightClass?
    @State private var airline: String
    @State private var showAirlineSuggestions: Bool = false

    init(editingFlight: Flight? = nil) {
        self.editingFlight = editingFlight
        _date = State(initialValue: editingFlight?.date ?? .now)
        _seatType = State(initialValue: editingFlight?.seatType)
        _flightClass = State(initialValue: editingFlight?.flightClass)
        _airline = State(initialValue: editingFlight?.airline ?? "")
    }

    // Inline search state
    enum SearchField { case from, to }
    @State private var activeSearch: SearchField?
    @State private var searchQuery = ""

    @FocusState private var searchFocused: Bool
    @FocusState private var airlineFocused: Bool

    private static let allAirlines: [AirlineInfo] = {
        guard let url = Bundle.main.url(forResource: "airlines", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([AirlineInfo].self, from: data)
        else { return [] }
        return list
    }()

    private var airlineSuggestions: [AirlineInfo] {
        guard !airline.isEmpty else { return [] }
        return Self.allAirlines
            .filter { $0.name.localizedCaseInsensitiveContains(airline) || $0.iata.localizedCaseInsensitiveContains(airline) }
            .prefix(5)
            .map { $0 }
    }

    private var distanceKm: Double? {
        guard let o = origin, let d = destination else { return nil }
        return haversine(from: o.coordinate, to: d.coordinate)
    }

    private var canSave: Bool { origin != nil && destination != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                FDColor.surface.ignoresSafeArea()

                // Main form
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        routeCard
                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .opacity(activeSearch != nil ? 0.15 : 1)
                .animation(.easeInOut(duration: 0.2), value: activeSearch != nil)

                // Inline search overlay
                if activeSearch != nil {
                    inlineSearchPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: activeSearch != nil)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if activeSearch != nil {
                            closeSearch()
                        } else {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .medium))
                            Text(activeSearch != nil ? "Back" : "Cancel")
                                .font(FDFont.ui(14))
                        }
                        .foregroundStyle(FDColor.gold)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(activeSearch == .from ? "Departure Airport"
                         : activeSearch == .to ? "Arrival Airport"
                         : editingFlight != nil ? "Edit Flight" : "Add a New Flight")
                        .font(FDFont.display(17, weight: .bold))
                        .foregroundStyle(FDColor.text)
                        .animation(.none, value: activeSearch)
                }
            }
            .toolbarBackground(FDColor.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationBackground(FDColor.surface)
        .preferredColorScheme(.dark)
        .onAppear {
            if let ef = editingFlight {
                origin = airportService.airport(for: ef.originIATA)
                destination = airportService.airport(for: ef.destinationIATA)
            }
        }
    }

    // MARK: - Route Card

    private var routeCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                airportField(
                    label: "FROM",
                    airport: origin,
                    placeholder: "Origin",
                    alignment: .leading,
                    isActive: activeSearch == .from
                ) {
                    openSearch(.from)
                }

                // Swap button
                Button {
                    let tmp = origin
                    origin = destination
                    destination = tmp
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FDColor.gold)
                        .frame(width: 36, height: 36)
                        .background(FDColor.surface3)
                        .overlay(Circle().stroke(FDColor.borderBright, lineWidth: 1))
                        .clipShape(Circle())
                }

                airportField(
                    label: "TO",
                    airport: destination,
                    placeholder: "Destination",
                    alignment: .trailing,
                    isActive: activeSearch == .to
                ) {
                    openSearch(.to)
                }
            }
            .padding(20)

            Rectangle()
                .fill(FDColor.border)
                .frame(height: 1)
                .padding(.horizontal, 20)

            HStack(spacing: 0) {
                metaField("Date") {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(FDColor.gold)
                }
                Rectangle()
                    .fill(FDColor.border)
                    .frame(width: 1)
                    .padding(.vertical, 12)
                metaField("Distance") {
                    if let km = distanceKm {
                        Text("\(Int(km).formatted()) km")
                            .font(FDFont.ui(15, weight: .medium))
                            .foregroundStyle(FDColor.text)
                    } else {
                        Text("—")
                            .font(FDFont.ui(15))
                            .foregroundStyle(FDColor.textDim)
                    }
                }
            }
            .padding(.vertical, 4)

            Rectangle()
                .fill(FDColor.border)
                .frame(height: 1)
                .padding(.horizontal, 20)

            airlineField

            Rectangle()
                .fill(FDColor.border)
                .frame(height: 1)
                .padding(.horizontal, 20)

            seatPicker
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            Rectangle()
                .fill(FDColor.border)
                .frame(height: 1)
                .padding(.horizontal, 20)

            classPicker
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .background(FDColor.surface2)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(FDColor.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func airportField(
        label: String,
        airport: Airport?,
        placeholder: String,
        alignment: HorizontalAlignment,
        isActive: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(alignment: alignment, spacing: 6) {
                Text(label)
                    .font(FDFont.ui(10, weight: .medium))
                    .foregroundStyle(isActive ? FDColor.gold : FDColor.textDim)
                    .tracking(1.5)

                if let airport {
                    Text(airport.iata)
                        .font(FDFont.display(34, weight: .bold))
                        .foregroundStyle(label == "TO" ? FDColor.gold : FDColor.text)
                    Text(airport.city)
                        .font(FDFont.ui(11))
                        .foregroundStyle(FDColor.textMuted)
                        .lineLimit(1)
                } else {
                    // Empty — show prominent placeholder with search icon
                    HStack(spacing: 6) {
                        if alignment == .trailing {
                            Spacer(minLength: 0)
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12))
                                .foregroundStyle(FDColor.gold.opacity(0.7))
                        }
                        Text(placeholder)
                            .font(FDFont.display(24, weight: .bold))
                            .foregroundStyle(FDColor.textDim)
                        if alignment == .leading {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12))
                                .foregroundStyle(FDColor.gold.opacity(0.7))
                            Spacer(minLength: 0)
                        }
                    }
                    Text("Tap to search")
                        .font(FDFont.ui(11))
                        .foregroundStyle(FDColor.gold.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .top))
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(airport == nil ? FDColor.gold.opacity(0.05) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                airport == nil ? FDColor.gold.opacity(0.25) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func metaField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(FDFont.ui(10, weight: .medium))
                .foregroundStyle(FDColor.textDim)
                .tracking(1.2)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Airline Field

    private var airlineField: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("AIRLINE")
                    .font(FDFont.ui(10, weight: .medium))
                    .foregroundStyle(FDColor.textDim)
                    .tracking(1.2)
                TextField("e.g. Lufthansa, Ryanair…", text: $airline)
                    .font(FDFont.ui(15, weight: .medium))
                    .foregroundStyle(FDColor.text)
                    .tint(FDColor.gold)
                    .autocorrectionDisabled()
                    .focused($airlineFocused)
                    .onChange(of: airlineFocused) { _, focused in
                        showAirlineSuggestions = focused && !airline.isEmpty
                    }
                    .onChange(of: airline) { _, value in
                        showAirlineSuggestions = !value.isEmpty
                    }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            if showAirlineSuggestions && !airlineSuggestions.isEmpty {
                Divider().background(FDColor.border)
                VStack(spacing: 0) {
                    ForEach(airlineSuggestions) { suggestion in
                        Button {
                            airline = suggestion.name
                            showAirlineSuggestions = false
                            airlineFocused = false
                        } label: {
                            HStack(spacing: 10) {
                                Text(suggestion.iata)
                                    .font(FDFont.display(13, weight: .bold))
                                    .foregroundStyle(FDColor.gold)
                                    .frame(width: 32, alignment: .leading)
                                Text(suggestion.name)
                                    .font(FDFont.ui(14, weight: .medium))
                                    .foregroundStyle(FDColor.text)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                        if suggestion.id != airlineSuggestions.last?.id {
                            Divider().background(FDColor.border).padding(.leading, 20)
                        }
                    }
                }
                .background(FDColor.surface3)
            }
        }
    }

    // MARK: - Seat Picker

    private var seatPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SEAT")
                .font(FDFont.ui(10, weight: .medium))
                .foregroundStyle(FDColor.textDim)
                .tracking(1.2)
            HStack(spacing: 8) {
                ForEach(SeatType.allCases, id: \.self) { type in
                    Button {
                        seatType = seatType == type ? nil : type
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 12))
                            Text(type.label)
                                .font(FDFont.ui(13, weight: .medium))
                        }
                        .foregroundStyle(seatType == type ? FDColor.black : FDColor.textMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(seatType == type ? FDColor.gold : FDColor.surface3)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(seatType == type ? Color.clear : FDColor.border, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: seatType)
                }
            }
        }
    }

    // MARK: - Class Picker

    private var classPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CLASS")
                .font(FDFont.ui(10, weight: .medium))
                .foregroundStyle(FDColor.textDim)
                .tracking(1.2)
            let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(FlightClass.allCases, id: \.self) { cls in
                    Button {
                        flightClass = flightClass == cls ? nil : cls
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: cls.icon)
                                .font(.system(size: 12))
                            Text(cls.label)
                                .font(FDFont.ui(13, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(flightClass == cls ? FDColor.black : FDColor.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(flightClass == cls ? FDColor.gold : FDColor.surface3)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(flightClass == cls ? Color.clear : FDColor.border, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: flightClass)
                }
            }
        }
    }

    // MARK: - Inline Search Panel

    private var inlineSearchPanel: some View {
        VStack(spacing: 0) {
            // Search input
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(FDColor.textMuted)
                    .font(.system(size: 16))
                TextField("City, airport or IATA code…", text: $searchQuery)
                    .foregroundStyle(FDColor.text)
                    .tint(FDColor.gold)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .focused($searchFocused)
                if !searchQuery.isEmpty {
                    Button { searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(FDColor.textDim)
                    }
                }
            }
            .padding(14)
            .background(FDColor.surface2)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(FDColor.borderBright, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)

            Divider()
                .background(FDColor.border)

            // Results
            let results = airportService.search(searchQuery)

            if searchQuery.isEmpty {
                // Prompt state
                VStack(spacing: 10) {
                    Image(systemName: "airplane")
                        .font(.system(size: 36))
                        .foregroundStyle(FDColor.textDim)
                    Text("Search for an airport")
                        .font(FDFont.display(18))
                        .foregroundStyle(FDColor.text)
                    Text("Type a city, country or IATA code.")
                        .font(FDFont.ui(13))
                        .foregroundStyle(FDColor.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 32)
            } else if results.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "airplane.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(FDColor.textDim)
                    Text("No airports found")
                        .font(FDFont.display(18))
                        .foregroundStyle(FDColor.text)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(results) { airport in
                    Button {
                        selectAirport(airport)
                    } label: {
                        HStack(spacing: 12) {
                            Text(airport.iata)
                                .font(FDFont.display(18, weight: .bold))
                                .foregroundStyle(FDColor.gold)
                                .frame(width: 48, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(airport.city)
                                    .font(FDFont.ui(15, weight: .medium))
                                    .foregroundStyle(FDColor.text)
                                Text(airport.name)
                                    .font(FDFont.ui(12))
                                    .foregroundStyle(FDColor.textMuted)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(airport.country)
                                .font(FDFont.ui(11))
                                .foregroundStyle(FDColor.textDim)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(FDColor.surface)
                    .listRowSeparatorTint(FDColor.border)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(FDColor.surface.ignoresSafeArea())
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: save) {
            Text(editingFlight != nil ? "Save Changes" : "Save Flight")
                .font(FDFont.ui(15, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(FDColor.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(canSave ? FDColor.gold : FDColor.gold.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!canSave)
    }

    // MARK: - Logic

    private func openSearch(_ field: SearchField) {
        searchQuery = ""
        activeSearch = field
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            searchFocused = true
        }
    }

    private func closeSearch() {
        searchFocused = false
        searchQuery = ""
        activeSearch = nil
    }

    private func selectAirport(_ airport: Airport) {
        if activeSearch == .from { origin = airport }
        else { destination = airport }
        closeSearch()
    }

    private func save() {
        guard let o = origin, let d = destination, let km = distanceKm else { return }
        if let ef = editingFlight {
            ef.originIATA = o.iata
            ef.destinationIATA = d.iata
            ef.date = date
            ef.distanceKm = km
            ef.seatType = seatType
            ef.flightClass = flightClass
            ef.airline = airline.isEmpty ? nil : airline
        } else {
            modelContext.insert(Flight(originIATA: o.iata, destinationIATA: d.iata, date: date, distanceKm: km, seatType: seatType, flightClass: flightClass, airline: airline.isEmpty ? nil : airline))
        }
        dismiss()
    }

    private func haversine(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let R = 6371.0
        let lat1 = from.latitude  * .pi / 180
        let lat2 = to.latitude    * .pi / 180
        let dLat = (to.latitude  - from.latitude)  * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let a = sin(dLat/2)*sin(dLat/2) + cos(lat1)*cos(lat2)*sin(dLon/2)*sin(dLon/2)
        return R * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

// MARK: - Airline Info

struct AirlineInfo: Codable, Identifiable {
    let name: String
    let iata: String
    var id: String { iata + name }
}
