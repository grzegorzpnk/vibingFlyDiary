import SwiftUI
import SwiftData

@main
struct vibingFlightDiaryApp: App {
    private let modelContainer: ModelContainer
    private let airportService = AirportService()
    private let localization = LocalizationService()
    private let auth = AuthService()

    init() {
        do {
            modelContainer = try ModelContainer(for: Flight.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(airportService)
                .environment(localization)
                .environment(auth)
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
