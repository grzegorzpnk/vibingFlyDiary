import SwiftUI

struct AirportSearchView: View {
    let title: String
    @Binding var selection: Airport?

    @Environment(\.dismiss) private var dismiss
    @Environment(AirportService.self) private var airportService

    @State private var query = ""

    private var results: [Airport] { airportService.search(query) }

    var body: some View {
        NavigationStack {
            ZStack {
                FDColor.surface.ignoresSafeArea()

                List(results) { airport in
                    Button {
                        selection = airport
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 10) {
                                Text(airport.iata)
                                    .font(FDFont.display(18, weight: .bold))
                                    .foregroundStyle(FDColor.gold)
                                Text(airport.city)
                                    .font(FDFont.ui(16, weight: .medium))
                                    .foregroundStyle(FDColor.text)
                            }
                            Text(airport.name)
                                .font(FDFont.ui(12))
                                .foregroundStyle(FDColor.textMuted)
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

                // Empty states
                if query.isEmpty {
                    placeholder(
                        icon: "magnifyingglass",
                        title: "Search Airports",
                        subtitle: "Type a city, airport name or IATA code."
                    )
                } else if results.isEmpty {
                    placeholder(
                        icon: "airplane.slash",
                        title: "No airports found",
                        subtitle: "Try a different search term."
                    )
                }
            }
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "City, airport or IATA code"
            )
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FDColor.gold)
                }
            }
            .toolbarBackground(FDColor.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private func placeholder(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 38))
                .foregroundStyle(FDColor.textDim)
            Text(title)
                .font(FDFont.display(20))
                .foregroundStyle(FDColor.text)
            Text(subtitle)
                .font(FDFont.ui(13))
                .foregroundStyle(FDColor.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
}
