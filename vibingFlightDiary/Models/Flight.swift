import Foundation
import SwiftData

// MARK: - Seat Type

enum SeatType: String, CaseIterable, Codable {
    case window = "window"
    case middle = "middle"
    case aisle  = "aisle"

    var label: String {
        switch self {
        case .window: return "Window"
        case .middle: return "Middle"
        case .aisle:  return "Aisle"
        }
    }

    var icon: String {
        switch self {
        case .window: return "align.horizontal.left.fill"
        case .middle: return "align.horizontal.center.fill"
        case .aisle:  return "align.horizontal.right.fill"
        }
    }
}

// MARK: - Flight Class

enum FlightClass: String, CaseIterable, Codable {
    case economy      = "economy"
    case premiumEconomy = "premium_economy"
    case business     = "business"
    case first        = "first"

    var label: String {
        switch self {
        case .economy:        return "Economy"
        case .premiumEconomy: return "Premium Eco"
        case .business:       return "Business"
        case .first:          return "First"
        }
    }

    var icon: String {
        switch self {
        case .economy:        return "person.seat"
        case .premiumEconomy: return "person.seat.fill"
        case .business:       return "star"
        case .first:          return "crown"
        }
    }
}

// MARK: - Flight Model

@Model
class Flight {
    var id: UUID
    var originIATA: String
    var destinationIATA: String
    var date: Date
    var distanceKm: Double
    var seatType: SeatType?
    var flightClass: FlightClass?

    init(
        originIATA: String,
        destinationIATA: String,
        date: Date,
        distanceKm: Double,
        seatType: SeatType? = nil,
        flightClass: FlightClass? = nil
    ) {
        self.id = UUID()
        self.originIATA = originIATA
        self.destinationIATA = destinationIATA
        self.date = date
        self.distanceKm = distanceKm
        self.seatType = seatType
        self.flightClass = flightClass
    }
}
