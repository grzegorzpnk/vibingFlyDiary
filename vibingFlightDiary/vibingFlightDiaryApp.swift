import SwiftUI
import SwiftData
import FirebaseCore

@main
struct vibingFlightDiaryApp: App {
    private let modelContainer: ModelContainer
    private let airportService = AirportService()
    private let localization = LocalizationService()
    private let auth = AuthService()
    private let sync = SyncService()

    init() {
        FirebaseApp.configure()
        do {
            modelContainer = try ModelContainer(for: Flight.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        sync.start(modelContext: modelContainer.mainContext)
        // Pre-warm country shapes off main thread so Map tab doesn't block on first open
        Task.detached(priority: .utility) {
            _ = CountryShapeService.shared.shapes.count
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(airportService)
                .environment(localization)
                .environment(auth)
                .environment(sync)
        }
        .modelContainer(modelContainer)
    }
}

private struct RootView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        if auth.isAuthenticated {
            ContentView()
        } else {
            SignInView()
        }
    }
}
