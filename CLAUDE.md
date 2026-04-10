# Flight Diary — Claude Instructions

## Project Overview
iOS app for logging personal flights. Shows a world map with great-circle arcs between airports.
Offline-only, no external server.

## Technical Stack
- **Platform**: iOS 17+ only
- **UI**: SwiftUI with `@Observable` macro (no Combine)
- **Storage**: SwiftData (`@Model`, `ModelContainer`, `@Query`)
- **Map**: MapKit SwiftUI (`Map`, `MapPolyline`, `MapStyle`)
- **Airport data**: Bundled `airports.json` in app bundle (~200 major airports)

## Architecture
```
vibingFlightDiary/
  Models/
    Airport.swift         # Codable struct, not SwiftData
    Flight.swift          # @Model (SwiftData)
  Services/
    AirportService.swift  # @Observable, loads airports.json
  Views/
    MapFlightView.swift     # Main map screen
    AddFlightView.swift     # Add flight bottom sheet
    AirportSearchView.swift # Airport picker sheet
    FlightListView.swift    # Flight history list
  Resources/
    airports.json
  ContentView.swift
  vibingFlightDiaryApp.swift
```

## Key Conventions
- Use `@Observable` (not `ObservableObject`) for services
- Use `@Environment(AirportService.self)` for DI
- Use `@Query` for SwiftData fetches in views
- 4-space indentation, no force unwrapping, no Combine

## Data Model
- Airport: Codable struct (in-memory, loaded from JSON), id = iata code
- Flight: SwiftData @Model with originIATA, destinationIATA, date, distanceKm

## SwiftData
- ModelContainer created in vibingFlightDiaryApp, schema: [Flight.self]
- Do NOT change SwiftData schema without asking — requires migration

## Map Style
- .imagery(elevation: .realistic) — satellite, no labels, dramatic look
- Flight arcs: great-circle paths (100 interpolated points)
- Arc style: amber/orange double-layer (wide dim glow + narrow solid)

## Do NOT
- Add stats/analytics (not in scope yet)
- Add external API calls
- Use Combine
- Force-unwrap
- Modify SwiftData schema without asking
