import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAddFlight = false

    init() {
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(onViewAll: { selectedTab = 2 }, onViewStats: { selectedTab = 3 }).tag(0)
                MapFlightView().tag(1)
                FlightListView().tag(2)
                StatsView().tag(3)
            }
            .ignoresSafeArea()

            FDTabBar(selectedTab: $selectedTab, showAddFlight: $showAddFlight)
        }
        .sheet(isPresented: $showAddFlight) {
            AddFlightView()
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Custom Tab Bar

struct FDTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showAddFlight: Bool
    @Environment(LocalizationService.self) private var ls

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(FDColor.border)
                .frame(height: 0.5)

            HStack(spacing: 0) {
                tabButton(icon: "book.fill", label: ls.tabDiary, tab: 0)
                tabButton(icon: "map.fill", label: ls.tabMap, tab: 1)

                Button { showAddFlight = true } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            Circle()
                                .fill(FDColor.gold)
                                .frame(width: 52, height: 52)
                                .shadow(color: FDColor.gold.opacity(0.45), radius: 14, y: 2)
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(FDColor.black)
                        }
                        .offset(y: -10)

                        Text(ls.tabAdd)
                            .font(FDFont.ui(10, weight: .semibold))
                            .foregroundStyle(FDColor.gold)
                            .offset(y: -8)
                    }
                }
                .frame(maxWidth: .infinity)

                tabButton(icon: "list.bullet", label: ls.tabFlights, tab: 2)
                tabButton(icon: "chart.bar.fill", label: ls.tabStats, tab: 3)
            }
            .frame(height: 60)
            .padding(.bottom, 2)
        }
        .background(FDColor.black.ignoresSafeArea(edges: .bottom))
    }

    @ViewBuilder
    private func tabButton(icon: String, label: String, tab: Int) -> some View {
        let active = selectedTab == tab
        Button { selectedTab = tab } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(active ? FDColor.gold : FDColor.text.opacity(0.35))
                Text(label)
                    .font(FDFont.ui(10, weight: .medium))
                    .foregroundStyle(active ? FDColor.gold : FDColor.textMuted)
                    .tracking(0.5)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
        .environment(AirportService())
        .modelContainer(for: Flight.self, inMemory: true)
}
