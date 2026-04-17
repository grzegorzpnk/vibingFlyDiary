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

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { airport in
                            Button {
                                selection = airport
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack(alignment: .leading) {
                                        // Invisible anchor — sets column width to widest possible IATA
                                        Text("WWW")
                                            .font(FDFont.display(18, weight: .bold))
                                            .hidden()
                                        Text(airport.iata)
                                            .font(FDFont.display(18, weight: .bold))
                                            .foregroundStyle(FDColor.gold)
                                            .lineLimit(1)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(airport.city)
                                            .font(FDFont.ui(15, weight: .medium))
                                            .foregroundStyle(FDColor.text)
                                            .lineLimit(1)
                                        Text(airport.name)
                                            .font(FDFont.ui(12))
                                            .foregroundStyle(FDColor.textMuted)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            Divider()
                                .background(FDColor.border)
                                .padding(.leading, 86)
                        }
                    }
                }

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
