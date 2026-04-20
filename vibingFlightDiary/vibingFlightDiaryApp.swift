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
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(airportService)
                .environment(localization)
                .environment(auth)
                .environment(sync)
                .onAppear {
                    #if DEBUG
                    DebugDataSeeder.reseed(context: modelContainer.mainContext)
                    #endif
                }
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
