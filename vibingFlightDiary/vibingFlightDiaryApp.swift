import SwiftUI
import SwiftData

@main
struct vibingFlightDiaryApp: App {
    private let modelContainer: ModelContainer
    private let airportService = AirportService()
    private let localization = LocalizationService()

    init() {
        do {
            modelContainer = try ModelContainer(for: Flight.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(airportService)
                .environment(localization)
                .onAppear {
                    #if DEBUG
                    DebugDataSeeder.reseed(context: modelContainer.mainContext)
                    #endif
                }
        }
        .modelContainer(modelContainer)
    }
}

