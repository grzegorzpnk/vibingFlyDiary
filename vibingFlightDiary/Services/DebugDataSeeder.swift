#if DEBUG
import SwiftData
import Foundation

struct DebugDataSeeder {

    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Flight>())) ?? 0
        guard existing == 0 else { return }
        reseed(context: context)
    }

    static func wipeAll(context: ModelContext, sync: SyncService? = nil) {
        if let existing = try? context.fetch(FetchDescriptor<Flight>()) {
            for flight in existing {
                sync?.delete(flightId: flight.id)
                context.delete(flight)
            }
        }
    }

    static func reseed(context: ModelContext) {
        if let existing = try? context.fetch(FetchDescriptor<Flight>()) {
            existing.forEach { context.delete($0) }
        }
        for flight in sampleFlights {
            context.insert(flight)
        }
    }

    // swiftlint:disable function_body_length
    private static var sampleFlights: [Flight] {
        [
            Flight(originIATA: "WAW", destinationIATA: "LHR", date: date(2024, 1, 15), distanceKm: 1453,
                   seatType: .window, flightClass: .economy, airline: "LOT Polish Airlines",
                   aircraftType: "Boeing 737-800", flightNumber: "LO271", price: 189.00),

            Flight(originIATA: "LHR", destinationIATA: "JFK", date: date(2024, 2, 3), distanceKm: 5541,
                   seatType: .aisle, flightClass: .business, airline: "British Airways",
                   aircraftType: "Boeing 777-200", flightNumber: "BA115", price: 2450.00),

            Flight(originIATA: "CDG", destinationIATA: "DXB", date: date(2024, 2, 20), distanceKm: 5251,
                   seatType: .middle, flightClass: .economy, airline: "Air France",
                   aircraftType: "Airbus A380", flightNumber: "AF142", price: 520.00),

            Flight(originIATA: "JFK", destinationIATA: "LAX", date: date(2024, 3, 8), distanceKm: 3975,
                   seatType: .window, flightClass: .first, airline: "American Airlines",
                   aircraftType: "Boeing 737 MAX 8", flightNumber: "AA2", price: 1899.99),

            Flight(originIATA: "SIN", destinationIATA: "SYD", date: date(2024, 3, 22), distanceKm: 6309,
                   seatType: .aisle, flightClass: .business, airline: "Singapore Airlines",
                   aircraftType: "Airbus A350-900", flightNumber: "SQ221", price: 3200.00),

            Flight(originIATA: "AMS", destinationIATA: "BCN", date: date(2024, 4, 5), distanceKm: 1489,
                   seatType: .window, flightClass: .economy, airline: "KLM",
                   aircraftType: "Boeing 737-800", flightNumber: "KL1671", price: 145.50),

            Flight(originIATA: "FCO", destinationIATA: "IST", date: date(2024, 4, 18), distanceKm: 1376,
                   seatType: .aisle, flightClass: .economy, airline: "Turkish Airlines",
                   aircraftType: "Airbus A321", flightNumber: "TK1862"),

            Flight(originIATA: "ORD", destinationIATA: "MIA", date: date(2024, 5, 2), distanceKm: 2198,
                   seatType: .window, flightClass: .premiumEconomy, airline: "American Airlines",
                   aircraftType: "Boeing 737-800", flightNumber: "AA1009", price: 385.00),

            Flight(originIATA: "HKG", destinationIATA: "NRT", date: date(2024, 5, 15), distanceKm: 2894,
                   seatType: .aisle, flightClass: .business, airline: "Cathay Pacific",
                   aircraftType: "Airbus A350-900", flightNumber: "CX500", price: 1750.00),

            Flight(originIATA: "SYD", destinationIATA: "MEL", date: date(2024, 5, 28), distanceKm: 713,
                   seatType: .window, flightClass: .economy, airline: "Qantas",
                   aircraftType: "Airbus A320", flightNumber: "QF401"),

            Flight(originIATA: "GRU", destinationIATA: "EZE", date: date(2024, 6, 10), distanceKm: 1961,
                   seatType: .middle, flightClass: .economy, airline: "LATAM Brasil",
                   aircraftType: "Airbus A320neo", flightNumber: "LA8070"),

            Flight(originIATA: "MUC", destinationIATA: "ZRH", date: date(2024, 6, 23), distanceKm: 245,
                   seatType: .window, flightClass: .economy, airline: "Lufthansa",
                   aircraftType: "Airbus A319", flightNumber: "LH2206"),

            Flight(originIATA: "DXB", destinationIATA: "BOM", date: date(2024, 7, 7), distanceKm: 1929,
                   seatType: .aisle, flightClass: .business, airline: "Emirates",
                   aircraftType: "Boeing 777-300", flightNumber: "EK502"),

            Flight(originIATA: "ICN", destinationIATA: "PEK", date: date(2024, 7, 20), distanceKm: 954,
                   seatType: .window, flightClass: .economy, airline: "Korean Air",
                   aircraftType: "Airbus A330-200", flightNumber: "KE851"),

            Flight(originIATA: "LIS", destinationIATA: "MAD", date: date(2024, 8, 3), distanceKm: 625,
                   seatType: .aisle, flightClass: .economy, airline: "TAP Air Portugal",
                   aircraftType: "Airbus A319", flightNumber: "TP1022"),

            Flight(originIATA: "CPH", destinationIATA: "OSL", date: date(2024, 8, 16), distanceKm: 482,
                   seatType: .window, flightClass: .economy, airline: "Scandinavian Airlines",
                   aircraftType: "Boeing 737-800", flightNumber: "SK462"),

            Flight(originIATA: "ATH", destinationIATA: "MXP", date: date(2024, 8, 29), distanceKm: 1556,
                   seatType: .aisle, flightClass: .economy, airline: "Aegean Airlines",
                   aircraftType: "Airbus A321", flightNumber: "A3301"),

            Flight(originIATA: "BKK", destinationIATA: "SIN", date: date(2024, 9, 11), distanceKm: 1436,
                   seatType: .window, flightClass: .business, airline: "Thai Airways",
                   aircraftType: "Boeing 777-200", flightNumber: "TG402"),

            Flight(originIATA: "MEX", destinationIATA: "LAX", date: date(2024, 9, 24), distanceKm: 2479,
                   seatType: .middle, flightClass: .economy, airline: "Aeromexico",
                   aircraftType: "Boeing 737 MAX 8", flightNumber: "AM2"),

            Flight(originIATA: "DUB", destinationIATA: "LHR", date: date(2024, 10, 7), distanceKm: 449,
                   seatType: .window, flightClass: .economy, airline: "Aer Lingus",
                   aircraftType: "Airbus A320", flightNumber: "EI156"),

            Flight(originIATA: "VIE", destinationIATA: "FCO", date: date(2024, 10, 20), distanceKm: 1030,
                   seatType: .window, flightClass: .business, airline: "Austrian Airlines",
                   aircraftType: "Airbus A320neo", flightNumber: "OS501"),

            Flight(originIATA: "ZRH", destinationIATA: "BRU", date: date(2024, 11, 2), distanceKm: 519,
                   seatType: .middle, flightClass: .economy, airline: "Swiss International Air Lines",
                   aircraftType: "Airbus A320", flightNumber: "LX758"),

            Flight(originIATA: "HEL", destinationIATA: "ARN", date: date(2024, 11, 15), distanceKm: 394,
                   seatType: .window, flightClass: .economy, airline: "Finnair",
                   aircraftType: "Airbus A319", flightNumber: "AY471"),

            Flight(originIATA: "CDG", destinationIATA: "JFK", date: date(2024, 12, 10), distanceKm: 5837,
                   seatType: .aisle, flightClass: .first, airline: "Air France",
                   aircraftType: "Airbus A350-900", flightNumber: "AF006", price: 4500.00),

            Flight(originIATA: "LAX", destinationIATA: "SFO", date: date(2024, 12, 23), distanceKm: 543,
                   seatType: .window, flightClass: .economy, airline: "United Airlines",
                   aircraftType: "Airbus A319", flightNumber: "UA1225", price: 89.00),

            Flight(originIATA: "MAD", destinationIATA: "LIM", date: date(2025, 1, 5), distanceKm: 9800,
                   seatType: .aisle, flightClass: .business, airline: "Iberia",
                   aircraftType: "Airbus A330-200", flightNumber: "IB6829", price: 2800.00),

            Flight(originIATA: "NRT", destinationIATA: "LAX", date: date(2025, 1, 18), distanceKm: 8752,
                   seatType: .window, flightClass: .business, airline: "All Nippon Airways",
                   aircraftType: "Boeing 787-9", flightNumber: "NH106", price: 3100.00),

            Flight(originIATA: "LHR", destinationIATA: "SYD", date: date(2025, 2, 1), distanceKm: 17014,
                   seatType: .middle, flightClass: .economy, airline: "Qantas",
                   aircraftType: "Airbus A380", flightNumber: "QF1"),

            Flight(originIATA: "FRA", destinationIATA: "DXB", date: date(2025, 2, 14), distanceKm: 4805,
                   seatType: .aisle, flightClass: .business, airline: "Lufthansa",
                   aircraftType: "Airbus A350-900", flightNumber: "LH630"),

            // Upcoming flight (future date)
            Flight(originIATA: "WAW", destinationIATA: "NRT", date: date(2026, 6, 10), distanceKm: 8953,
                   seatType: .window, flightClass: .business, airline: "LOT Polish Airlines",
                   aircraftType: "Boeing 787-9", flightNumber: "LO079"),
        ]
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }
}
#endif
