import Foundation
import SwiftData

@Model
class Flight {
    var id: UUID
    var originIATA: String
    var destinationIATA: String
    var date: Date
    var distanceKm: Double

    init(originIATA: String, destinationIATA: String, date: Date, distanceKm: Double) {
        self.id = UUID()
        self.originIATA = originIATA
        self.destinationIATA = destinationIATA
        self.date = date
        self.distanceKm = distanceKm
    }
}
