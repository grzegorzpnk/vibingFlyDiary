import SwiftUI
import SwiftData

struct FlightListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AirportService.self) private var airportService
    @Query(sort: \Flight.date, order: .reverse) private var flights: [Flight]

    @State private var selectedFlight: Flight?
    @State private var flightToEdit: Flight?
    @Environment(LocalizationService.self) private var ls

    var body: some View {
        ZStack {
            FDColor.black.ignoresSafeArea()

            if flights.isEmpty {
                emptyState
            } else {
                List {
                    Section {
                        ForEach(flights) { flight in
                            FlightCard(flight: flight, airportService: airportService) {
                                selectedFlight = flight
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    modelContext.delete(flight)
                                } label: {
                                    Label(ls.deleteAction, systemImage: "trash")
                                }
                                Button {
                                    flightToEdit = flight
                                } label: {
                                    Label(ls.editAction, systemImage: "pencil")
                                }
                                .tint(FDColor.gold)
                            }
                        }
                    } header: {
                        listHeader
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 0)
            }
        }
        .sheet(item: $selectedFlight) { flight in
            FlightDetailView(flight: flight, airportService: airportService)
        }
        .sheet(item: $flightToEdit) { flight in
            AddFlightView(editingFlight: flight)
        }
    }

    private var listHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ls.logbookOverline)
                .font(FDFont.ui(11, weight: .medium))
                .foregroundStyle(FDColor.gold)
                .tracking(2.5)
            Text(ls.allFlightsTitle)
                .font(FDFont.display(34, weight: .bold))
                .foregroundStyle(FDColor.text)
            Text(ls.entriesCount(flights.count))
                .font(FDFont.ui(13))
                .foregroundStyle(FDColor.textMuted)
                .padding(.top, 2)
        }
        .padding(.top, 56)
        .padding(.bottom, 16)
        .padding(.horizontal, 4)
        .textCase(nil)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "airplane")
                .font(.system(size: 48))
                .foregroundStyle(FDColor.textDim)
            Text(ls.noFlightsLogged)
                .font(FDFont.display(22))
                .foregroundStyle(FDColor.text)
            Text(ls.tapAddHint)
                .font(FDFont.ui(13))
                .foregroundStyle(FDColor.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 80)
    }

}
