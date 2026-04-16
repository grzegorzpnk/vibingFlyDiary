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
- Add external API calls
- Use Combine
- Force-unwrap
- Modify SwiftData schema without asking

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.
